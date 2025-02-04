# https://developer.deluxe.com/s/article-api-reference
# We use Oauth2 client to get an authorization token. Then pass that token into a REST api.
# We get a payment_intent from the front end HostedPaymentForm, then call authorize and complete on it.
# Effective::DeluxeApi.new.health_check
module Effective
  class DeluxeApi
    SCRUB = /[^\w\d#,\s]/

    # All required
    attr_accessor :environment
    attr_accessor :client_id
    attr_accessor :client_secret
    attr_accessor :access_token
    attr_accessor :currency

    attr_accessor :purchase_response
    attr_accessor :read_timeout

    def initialize(environment: nil, client_id: nil, client_secret: nil, access_token: nil, currency: nil)
      self.environment = environment || EffectiveOrders.deluxe.fetch(:environment)
      self.client_id = client_id || EffectiveOrders.deluxe.fetch(:client_id)
      self.client_secret = client_secret || EffectiveOrders.deluxe.fetch(:client_secret)
      self.access_token = access_token || EffectiveOrders.deluxe.fetch(:access_token)
      self.currency = currency || EffectiveOrders.deluxe.fetch(:currency)
    end

    def health_check
      get('/')
    end

    def healthy?
      response = health_check()

      return false unless response.kind_of?(Hash)
      return false unless response['appName'].present?
      return false unless response['environment'].present?

      true
    end

    # Decode the base64 encoded JSON object into a Hash
    def decode_payment_intent_payload(payload)
      raise('expected a string') unless payload.kind_of?(String)

      payment_intent = (JSON.parse(Base64.decode64(payload)) rescue nil)

      raise('expected payment_intent to be a Hash') unless payment_intent.kind_of?(Hash)
      raise('expected a token payment') unless payment_intent['type'] == 'Token'

      payment_intent
    end

    # Takes a payment_intent and returns the card info we can store
    def card_info(payment_intent)
      token = extract_token(payment_intent)

      # Return the authorization params merged with the card info
      last4 = token['maskedPan'].to_s.last(4)
      card = token['cardType'].to_s.downcase
      date = token['expDate']
      cvv = token['cvv']

      active_card = "**** **** **** #{last4} #{card} #{date}" if last4.present?

      { 'active_card' => active_card, 'card' => card, 'expDate' => date, 'cvv' => cvv }.compact
    end

    # After we store a payment intent we can call purchase! immediately or wait till later.
    # This calls the /payments Create Payment endpoint
    # Returns true when purchased. Returns false when declined.
    # The response is stored in api.payment() after this is run
    def purchase!(order, payment_intent)
      payment_intent = decode_payment_intent_payload(payment_intent) if payment_intent.kind_of?(String)
      raise('expected payment_intent to be a Hash') unless payment_intent.kind_of?(Hash)
      raise('expected a token payment') unless payment_intent['type'] == 'Token'

      # Start a purchase. Which is an Authorization and a Completion
      self.purchase_response = nil
      payment = create_payment(order, payment_intent)
      self.purchase_response = payment

      # Validate
      valid = [0].include?(payment['responseCode'])
      return false unless valid

      # Valid purchase. This is authorized and completed.
      true
    end

    def purchase_free!(order)
      raise('expected a free order') unless order.free?

      self.purchase_response = nil
      payment = { card: "none", details: "free order. no payment required."}
      self.purchase_response = payment

      # Free is always valid
      true
    end

    # Create Payment
    def create_payment(order, payment_intent)
      response = post('/payments', params: create_payment_params(order, payment_intent))

      # Sanity check response
      raise('expected responseCode') unless response.kind_of?(Hash) && response['responseCode'].present?

      # Sanity check response approved vs authorized
      valid = [0].include?(response['responseCode'])

      # We might be approved for an amount less than the order total. Not sure what to do here
      if valid && (amountApproved = response['amountApproved']) != (amountAuthorized = order.total_to_f)
        raise("expected complete payment amountApproved #{amountApproved} to be the same as the amountAuthorized #{amountAuthorized} but it was not")
      end

      # Generate the card info we can store
      card = card_info(payment_intent)

      # Return the response merged with the card info
      response.reverse_merge(card)
    end

    # The response from last create payment request
    def payment
      raise('expected purchase response to be present') unless purchase_response.kind_of?(Hash)
      purchase_response
    end

    def payment_approved?(order)
      payment = search_payment(order)
      return false if payment.blank?

      payment.dig('payment', 'responseCode').present? && payment.dig('payment', 'authResponse').to_s.downcase.include?('approved')
    end

    # Search for an existing Payment
    def search_payment(order)
      date = (order.delayed_payment_purchase_ran_at || order.purchased_at || order.created_at || Time.zone.now)
      response = post('/payments/search', params: { orderId: order.to_param, startDate: date.strftime('%m/%d/%Y'), endDate: (date + 1.day).strftime('%m/%d/%Y') })

      # Sanity check response
      raise('expected responseCode') unless response.kind_of?(Hash) && response['isSuccess'] == true

      # Find the payment for this order
      payment = Array(response.dig('data', 'payments')).find { |payment| payment.dig('payment', 'orderId') == order.to_param }
      return unless payment.present?

      # Return the payment hash
      payment
    end

    def purchase_delayed_order!(order)
      raise('expected a delayed order') unless order.delayed?
      raise('expected a deferred order') unless order.deferred?
      raise('expected delayed payment intent') unless order.delayed_payment_intent.present?
      raise('expected a delayed_ready_to_purchase? order') unless order.delayed_ready_to_purchase?

      order.update_columns(delayed_payment_purchase_ran_at: Time.zone.now, delayed_payment_purchase_result: nil)

      purchased = if order.total.to_i > 0
        purchase!(order, order.delayed_payment_intent)
      elsif order.free?
        purchase_free!(order)
      else
        raise("Unexpected order amount: #{order.total}")
      end

      provider = (order.free? ? 'free' : order.payment_provider)
      payment = self.payment()
      card = payment["card"] || payment[:card]

      if purchased
        order.assign_attributes(delayed_payment_purchase_result: "success")
        order.purchase!(payment: payment, provider: provider, card: card, email: true, skip_buyer_validations: true)

        puts "Successfully purchased order #{order.id}"
      else
        order.assign_attributes(delayed_payment_purchase_result: "failed: #{Array(payment['responseMessage']).to_sentence.presence || 'none'}")
        order.decline!(payment: payment, provider: provider, card: card, email: true)

        puts "Failed to purchase order #{order.id} #{order.delayed_payment_purchase_result}"
      end

      purchased
    end

    def retry_purchase_delayed_order!(order)
      raise('expected a delayed order') unless order.delayed?
      raise('expected a deferred order') unless order.deferred?
      raise('expected delayed payment intent') unless order.delayed_payment_intent.present?
      raise('expected an order with a positive total') unless order.total.to_i > 0

      order.update_columns(delayed_payment_purchase_ran_at: Time.zone.now, delayed_payment_purchase_result: nil)

      # Look up the existing payment on Deluxe API
      existing_payment = search_payment(order)
      existing_purchased = existing_payment.present? && existing_payment.dig('payment', 'responseCode').present? && existing_payment.dig('payment', 'authResponse').to_s.downcase.include?('approved')

      # If it doesn't exist, purchase it now
      purchased = (existing_purchased || purchase!(order, order.delayed_payment_intent))

      # Payment
      provider = order.payment_provider
      payment = (existing_payment if existing_purchased) || self.payment()
      card = payment.dig('payment', 'card', 'cardType') || payment.dig('payment', 'card') || payment['card'] || payment[:card]

      if purchased
        order.assign_attributes(delayed_payment_purchase_result: "success")
        order.purchase!(payment: payment, provider: provider, card: card, email: true, skip_buyer_validations: true)

        puts "Successfully purchased order #{order.id}"
      else
        order.assign_attributes(delayed_payment_purchase_result: "failed: #{Array(payment['responseMessage']).to_sentence.presence || 'none'}")
        order.decline!(payment: payment, provider: provider, card: card, email: true)

        puts "Failed to purchase order #{order.id} #{order.delayed_payment_purchase_result}"
      end

      purchased
    end

    # Called by rake task
    def purchase_delayed_orders!(orders)
      # Orders that failed to purchase and need to be retried
      retry_orders = []

      # First pass over all the orders
      Array(orders).each do |order|
        puts "Trying order #{order.id}"

        begin
          purchase_delayed_order!(order)
        rescue => e
          order.update_columns(delayed_payment_purchase_ran_at: Time.zone.now, delayed_payment_purchase_result: "error: #{e.message}")
          retry_orders << order

          puts "Error purchasing #{order.id}: #{e.message}"
        end
      end

      # Second pass over all the orders that raised an error on call to purchase
      orders = Effective::Order.where(id: retry_orders.map(&:id))

      Array(orders).each do |order|
        puts "Retrying order #{order.id}"

        begin
          retry_purchase_delayed_order!(order)
        rescue => e
          order.update_columns(delayed_payment_purchase_ran_at: Time.zone.now, delayed_payment_purchase_result: "error: #{e.message}")

          EffectiveLogger.error(e.message, associated: order) if defined?(EffectiveLogger)
          ExceptionNotifier.notify_exception(e, data: { order_id: order.id }) if defined?(ExceptionNotifier)

          puts "Error retry purchasing #{order.id}: #{e.message}"

          raise(e) if Rails.env.development? || Rails.env.test?
        end
      end

      true
    end

    # This is only used for testing
    def generate_payment_intent(card: nil, expiry: nil, cvv: nil, encode: false)
      card ||= '5555 5555 5555 4444'
      expiry ||= "12/#{Time.zone.now.year - 1998}"
      cvv ||= '123'

      card_info = { expiry: expiry, cvv: cvv }
      params = { paymentMethod: { card: { card: card.gsub(" ", '') }.merge(card_info) } }

      response = post('/paymentmethods/token', params: params)

      # Like the delayed_purchase form gives us
      retval = {
        type: "Token",
        status: "success",
        data: { expDate: card_info[:expiry], cardType: 'Visa', token: response.fetch('token') }
      }

      encode ? Base64.encode64(retval.to_json) : retval
    end

    def webhook_subscribe(params)
      post('/events/subscribe', params: params)
    end

    def webhook_unsubscribe(params)
      post('/events/unsubscribe', params: params)
    end

    def webhook_test(params)
      post('/events/test', params: params)
    end

    protected

    def create_payment_params(order, payment_intent)
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)

      token = extract_token(payment_intent)

      amount = {
        amount: order.total_to_f,
        currency: currency
      }

      billingAddress = if (address = order.billing_address).present?
        {
          email: order.email,
          address: scrub(address.address1, limit: 250),
          address2: scrub(address.address2),
          city: scrub(address.city, limit: 50),
          state: address.state_code,
          country: address.country_code,
          postalCode: address.postal_code
        }.compact
      end

      shippingAddress = if (address = order.shipping_address).present?
        {
          address: scrub(address.address1, limit: 250),
          address2: scrub(address.address2),
          city: scrub(address.city, limit: 50),
          state: address.state_code,
          country: address.country_code,
          postalCode: address.postal_code
        }.compact
      end

      paymentMethod = {
        token: { token: token['token'], expiry: (token['expDate'] || token['expiry']), cvv: token['cvv'] }.compact,
        billingAddress: billingAddress
      }.compact

      customData = [
        ({ name: 'order_id', value: order.to_param }),
        ({ name: 'user_id', value: order.user_id.to_s } if order.user_id.present?),
        ({ name: 'organization_id', value: order.organization_id.to_s } if order.organization_id.present?)
      ].compact

      orderData = {
        autoGenerateOrderId: true,
        orderId: order.to_param,
        orderIdIsUnique: true
      }

      # Params passed into Create Payment
      params = {
        paymentType: "Sale",
        amount: amount, 
        paymentMethod: paymentMethod,
        shippingAddress: shippingAddress,
        customData: customData,
        merchantCategory: "MOTO",
        orderData: orderData
      }.compact
    end

    def get(endpoint, params: nil)
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(api_url + endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = (read_timeout || 30)
      http.use_ssl = true

      result = with_retries do
        puts "[GET] #{uri}" if Rails.env.development?

        response = http.get(uri, headers)
        raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

        response
      end

      JSON.parse(result.body)
    end

    def post(endpoint, params:)
      uri = URI.parse(api_url + endpoint)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = (read_timeout || 30)
      http.use_ssl = true

      puts "[POST] #{uri} #{params}" if Rails.env.development?

      response = http.post(uri.path, params.to_json, headers)
      raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

      JSON.parse(response.body)
    end

    private

    def headers
      { "Content-Type": "application/json", "Authorization": "Bearer #{authorization_token}", "PartnerToken": access_token }
    end

    def client
      OAuth2::Client.new(
        client_id, 
        client_secret, 
        site: client_url, 
        token_url: '/secservices/oauth2/v2/token' # https://sandbox.api.deluxe.com/secservices/oauth2/v2/token
      )
    end

    def authorization_token
      @authorization_token ||= Rails.cache.fetch(authorization_cache_key, expires_in: 60.minutes) do 
        puts "[AUTH] Oauth2 Get Token" if Rails.env.development?
        client.client_credentials.get_token.token
      end
    end

    # https://sandbox.api.deluxe.com
    def client_url
      case environment
      when 'production' then 'https://api.deluxe.com'
      when 'sandbox' then 'https://sandbox.api.deluxe.com' # No trailing /
      else raise('unexpected deluxe environment')
      end
    end

    # https://sandbox.api.deluxe.com/dpp/v1/gateway/
    def api_url
      client_url + '/dpp/v1/gateway'
    end

    def extract_token(payment_intent)
      raise('expected a payment intent') unless payment_intent.kind_of?(Hash)

      token = payment_intent['data'] || payment_intent
      raise('expected a payment intent Hash') unless token['token'].present? && token['expDate'].present?

      token
    end

    def extract_payment_id(authorization)
      return authorization if authorization.kind_of?(String)
      raise('expected an authorization Hash') unless authorization.kind_of?(Hash)

      payment_id = authorization['paymentId']
      raise('expected a paymentId') unless payment_id.present?

      payment_id
    end

    def scrub(value, limit: 100)
      return value unless value.kind_of?(String)
      value.gsub(SCRUB, '').first(limit)
    end

    def authorization_cache_key
      "deluxe_api_#{client_id}"
    end

    def with_retries(retries: (Rails.env.development? ? 0 : 3), wait: 2, &block)
      raise('expected a block') unless block_given?

      begin
        return yield
      rescue Exception => e
        # Reset cache and query for a new authorization token on any error
        Rails.cache.delete(authorization_cache_key)
        @authorization_token = nil

        if (retries -= 1) > 0
          sleep(wait); retry
        else
          raise
        end
      end
    end

  end
end
