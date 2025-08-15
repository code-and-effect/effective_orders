# https://devdocs.helcim.com/docs/overview-of-helcimpayjs
# Effective::HelcimApi.new.health_check
module Effective
  class HelcimApi
    # All required
    attr_accessor :environment
    attr_accessor :api_token
    attr_accessor :partner_token
    attr_accessor :currency
    attr_accessor :brand_color
    attr_accessor :fee_saver

    attr_accessor :read_timeout
    attr_accessor :last_response

    def initialize(environment: nil)
      self.environment = EffectiveOrders.helcim.fetch(:environment)
      self.api_token = EffectiveOrders.helcim.fetch(:api_token)
      self.partner_token = EffectiveOrders.helcim.fetch(:partner_token)
      self.currency = EffectiveOrders.helcim.fetch(:currency)
      self.brand_color = EffectiveOrders.helcim.fetch(:brand_color)
      self.fee_saver = EffectiveOrders.helcim.fetch(:fee_saver)
    end

    def health_check
      get('/connection-test')
    end

    def get_transaction(id)
      get("/card-transactions/#{id}")
    end

    # Make the Preload Request
    # https://devdocs.helcim.com/reference/checkout-init
    def initialize_request(order)
      params = {
        amount: ('%.2f' % order.total_to_f),
        currency: currency,
        paymentType: 'purchase',   # purchase, preauth, verify
        paymentMethod: (fee_saver ? 'cc-ach' : 'cc'),
        hasConvenienceFee: (fee_saver ? 1 : 0),
        allowPartial: 0,
        taxAmount: ('%.2f' % order.tax_to_f if order.tax.to_i > 0),
        hideExistingPaymentDetails: 0,
        setAsDefaultPaymentMethod: 1,
        confirmationScreen: false,
        displayContactFields: 0,
        customStyling: {
          brandColor: (brand_color || '815AF0')
        },
        invoiceRequest: {
          invoiceNumber: '#' + order.to_param
        },
        customerRequest: {
          contactName: order.billing_name,
          businessName: order.organization.to_s.presence,
        }.compact,
      }.compact

      params[:invoiceRequest][:lineItems] = order.order_items.map do |item|
        {
          description: item.name,
          quantity: item.quantity,
          price: ('%.2f' % item.price_to_f),
          total: ('%.2f' % item.subtotal_to_f),
          taxAmount: ('%.2f' % item.tax_to_f),
        }
      end

      address = order.billing_address
      country = helcim_country(address&.country_code)

      if address.present? && country.to_s.length == 3
        params[:customerRequest][:billingAddress] = {
          name: order.billing_name,
          street1: address.address1,
          street2: address.address2,
          city: address.city,
          province: address.state_code,
          country: country,
          postalCode: address.postal_code,
          email: order.email,
        }
      end

      address = order.shipping_address
      country = helcim_country(address&.country_code)

      if address.present? && country.to_s.length == 3
        params[:customerRequest][:shippingAddress] = {
          name: order.billing_name,
          street1: address.address1,
          street2: address.address2,
          city: address.city,
          province: address.state_code,
          country: country,
          postalCode: address.postal_code,
          email: order.email,
        }
      end

      response = post('/helcim-pay/initialize', params: params)
      raise("expected response to be a Hash") unless response.kind_of?(Hash)

      token = response['checkoutToken']
      raise("expected response to include a checkoutToken") unless token.present?

      # Return the token to the front end form
      token
    end

    # Decode the base64 encoded JSON object that was given from the form into a Hash
    # {"transactionId"=>"38142732",
    # "dateCreated"=>"2025-08-15 10:10:32",
    # "cardBatchId"=>"4656307",
    # "status"=>"APPROVED",
    # "type"=>"purchase",
    # "amount"=>"10.97",
    # "currency"=>"CAD",
    # "avsResponse"=>"X",
    # "cvvResponse"=>"",
    # "approvalCode"=>"T5E3ST",
    # "cardToken"=>"gv5J-lJAQNqVjZ_HkXyisQ",
    # "cardNumber"=>"4242424242",
    # "cardHolderName"=>"Test User",
    # "customerCode"=>"CST1022",
    # "invoiceNumber"=>"#30",
    # "warning"=>""}
    def decode_payment_payload(payload)
      return if payload.blank?

      raise('expected a string') unless payload.kind_of?(String)

      payment = (JSON.parse(Base64.decode64(payload)) rescue nil)
      raise('expected payment to be a Hash') unless payment.kind_of?(Hash)

      payment = payment.dig('data', 'data')
      raise('expected payment data') unless payment.kind_of?(Hash)
      raise('expected payment data with a transactionId') unless payment['transactionId'].present?

      payment
    end

    def purchased?(payment)
      raise('expected a payment Hash') unless payment.kind_of?(Hash)
      (payment['status'] == 'APPROVED' && payment['type'] == 'purchase')
    end

    # Considers the insecure payment_payload, requests the real transaction from Helcim and verifies it vs the order
    def get_payment(order, payment_payload)
      raise('expected a payment_payload Hash') unless payment_payload.kind_of?(Hash)

      transaction_id = payment_payload['transactionId']
      raise('expected a payment_payload with a transactionId') unless transaction_id.present?

      payment = get_transaction(transaction_id)
      raise('expected an existing card-transaction payment') unless payment.kind_of?(Hash)

      # Compare the payment (trusted truth) and the payment_payload (untrusted)
      if payment['transactionId'].to_s != payment_payload['transactionId'].to_s
        raise('expected the payment and payment_payload to have the same transactionId')
      end

      # Normalize the card info and scrub out the card number
      payment = payment.merge(card_info(payment)).except('cardNumber')

      payment
    end

    # Adds the order.surcharge if this is a fee saver order
    def assign_order_charges!(order, payment)
      raise('expected an order') unless order.kind_of?(Effective::Order)
      raise('expected a payment Hash') unless payment.kind_of?(Hash)

      return unless EffectiveOrders.fee_saver?

      # Validate amounts if purchased
      amount = payment['amount'].to_f
      amountAuthorized = order.total_to_f

      surcharge = ((amount - amountAuthorized) * 100).to_i
      raise('expected surcharge to be a positive number') if surcharge < 0

      order.update!(surcharge: surcharge)
    end

    def verify_payment!(order, payment)
      # Validate order ids
      if payment['invoiceNumber'].to_s != '#' + order.to_param
        raise("expected card-transaction invoiceNumber to be the same as the order to_param")
      end

      # Validate amounts if purchased
      if purchased?(payment) && (amount = payment['amount'].to_f) != (amountAuthorized = order.total_to_f)
        raise("expected card-transaction amount #{amount} to be the same as the amountAuthorized #{amountAuthorized} but it was not")
      end

      payment
    end

    # Takes a payment_intent and returns the card info we can store
    def card_info(payment)
      # Return the authorization params merged with the card info
      last4 = payment['cardNumber'].to_s.last(4)
      card = payment['cardType'].to_s.downcase

      active_card = "**** **** **** #{last4} #{card}" if last4.present?

      { 'active_card' => active_card, 'card' => card }.compact
    end

    def get(endpoint, params: nil)
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(api_url + endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = (read_timeout || 30)
      http.use_ssl = true

      self.last_response = nil

      result = with_retries do
        puts "[GET] #{uri}" if Rails.env.development?

        response = http.get(uri, headers)
        raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

        response
      end

      self.last_response = result

      JSON.parse(result.body)
    end

    def post(endpoint, params:)
      uri = URI.parse(api_url + endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = (read_timeout || 30)
      http.use_ssl = true

      self.last_response = nil

      puts "[POST] #{uri} #{params}" if Rails.env.development?

      response = http.post(uri.path, params.to_json, headers)
      raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

      self.last_response = response

      JSON.parse(response.body)
    end

    # Effective::HelcimApi.new.set_logo!
    # Put your file in the apps/tenant/app/assets/images/tenant/helcim-logo.png
    # Run this once to set the logo
    def set_logo!(path: nil)
      path ||= Rails.root.join("apps/#{Tenant.current}/app/assets/images/#{Tenant.current}/helcim-logo.png")
      raise("Expected #{path} to exist") unless File.exist?(path)

      url = URI.parse(api_url + '/branding/logo')
      boundary = "AaB03x"

      # Build multipart form data
      body = [
        "--#{boundary}",
        "Content-Disposition: form-data; name=\"logo\"; filename=\"#{File.basename(path)}\"",
        "Content-Type: image/#{File.extname(path).downcase.delete('.')}",
        "",
        File.binread(path),
        "--#{boundary}--"
      ].join("\r\n")

      # Set up HTTP request
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      
      # Create POST request
      request = Net::HTTP::Post.new(url.path)
      request.body = body

      request.initialize_http_header(headers.merge({
        'Content-Type' => "multipart/form-data; boundary=#{boundary}",
        'Content-Length' => request.body.length.to_s,
      }))

      # Send request
      response = http.request(request)
      raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

      JSON.parse(response.body)
    end

    private

    def headers
      { 
        "Accept": "application/json", 
        "Content-Type": 
        "application/json", 
        'api-token': api_token,
        'partner-token': partner_token.presence,
      }.compact
    end

    def api_url
      'https://api.helcim.com/v2' # No trailing /
    end

    def helcim_country(country_code)
      return 'CAN' if country_code == 'CA' || country_code == 'CAD'
      return 'USA' if country_code == 'US'
      country_code
    end

    def with_retries(retries: (Rails.env.development? ? 0 : 3), wait: 2, &block)
      raise('expected a block') unless block_given?

      begin
        return yield
      rescue Exception => e
        if (retries -= 1) > 0
          sleep(wait); retry
        else
          raise
        end
      end
    end

  end
end
