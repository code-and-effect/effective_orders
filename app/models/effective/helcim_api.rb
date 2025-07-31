# https://devdocs.helcim.com/docs/overview-of-helcimpayjs
# Effective::HelcimApi.new.health_check
module Effective
  class HelcimApi
    # All required
    attr_accessor :environment
    attr_accessor :api_token
    attr_accessor :currency

    attr_accessor :read_timeout

    def initialize(environment: nil, api_token: nil, currency: nil)
      self.environment = environment || EffectiveOrders.helcim.fetch(:environment)
      self.api_token = api_token || EffectiveOrders.helcim.fetch(:api_token)
      self.currency = currency || EffectiveOrders.helcim.fetch(:currency)
    end

    def health_check
      get('/connection-test')
    end

    def get_transaction(id)
      get("/card-transactions/#{id}")
    end

    # Make the Preload Request
    def initialize_request(order)
      params = {
        paymentType: 'purchase',   # purchase, preauth, verify
        amount: ('%.2f' % (order.total_with_surcharge / 100.0)),
        currency: 'CAD',
        paymentMethod: 'cc',
        allowPartial: 0,
        hasConvenienceFee: 0,
        taxAmount: ('%.2f' % (order.tax / 100.0)),
        hideExistingPaymentDetails: 0,
        setAsDefaultPaymentMethod: 1,
        confirmationScreen: false,
        displayContactFields: 0,
        customStyling: {
          appearance: 'light',
          cornerRadius: 'rectangular'
        }
      }

      response = post('/helcim-pay/initialize', params: params)
      raise("expected response to be a Hash") unless response.kind_of?(Hash)

      token = response['checkoutToken']
      raise("expected resposne to include a checkoutToken") unless token.present?

      # Return the token to the front end form
      token
    end

    # Decode the base64 encoded JSON object that was given from the form into a Hash
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

    # [1] pry(#<Effective::HelcimApi>)> payment
    # => {"transactionId"=>"37587289",
    #  "dateCreated"=>"2025-07-30 15:24:33",
    #  "cardBatchId"=>"4593525",
    #  "status"=>"APPROVED",
    #  "type"=>"purchase",
    #  "amount"=>"140",
    #  "currency"=>"1",
    #  "avsResponse"=>"X",
    #  "cvvResponse"=>"",
    #  "approvalCode"=>"T3E3ST",
    #  "cardToken"=>"a38hU2p8RV66UJDzJgxIyQ",
    #  "cardNumber"=>"4242424242",
    #  "cardHolderName"=>"Matt Arr",
    #  "customerCode"=>"CST1012",
    #  "invoiceNumber"=>"INV001012",
    #  "warning"=>""}
    # [2] pry(#<Effective::HelcimApi>)> transaction
    # => {"transactionId"=>37587289,
    #  "dateCreated"=>"2025-07-30 15:24:33",
    #  "cardBatchId"=>5140370,
    #  "status"=>"APPROVED",
    #  "user"=>"Helcim System",
    #  "type"=>"purchase",
    #  "amount"=>140,
    #  "currency"=>"CAD",
    #  "avsResponse"=>"X",
    #  "cvvResponse"=>"",
    #  "cardType"=>"VI",
    #  "approvalCode"=>"T3E3ST",
    #  "cardToken"=>"",
    #  "cardNumber"=>"4242424242",
    #  "cardHolderName"=>"Matt Arr",
    #  "customerCode"=>"CST1012",
    #  "invoiceNumber"=>"INV001012",
    #  "warning"=>""}

    def purchased?(payment)
      raise('expected a payment Hash') unless payment.kind_of?(Hash)
      (payment['status'] == 'APPROVED' && payment['type'] == 'purchase')
    end

    def verify_payment(payment_payload)
      raise('expected a payment_payload Hash') unless payload.kind_of?(Hash)

      transaction_id = payment_payload['transactionId']
      raise('expected a payment_payload with a transactionId') unless transaction_id.present?

      payment = get_transaction(transaction_id)
      raise('expected an existing card-transaction payment') unless payment.kind_of?(Hash)

      # Compare the payment (trusted truth) and the payment_payload (untrusted)
      if payment['transactionId'].to_s != payment_payload['transactionId'].to_s
        raise('expected the payment and payment_payload to have the same transactionId')
      end

      # Validate amounts if purchased
      if purchased?(payment) && (amount = response['amount'].to_i) != (amountAuthorized = order.total)
        raise("expected card-transaction amount #{amount} to be the same as the amountAuthorized #{amountAuthorized} but it was not")
      end

      # Normalize the card info and scrub out the card number
      payment = payment.merge(card_info(payment)).except('cardNumber')

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
      { "Accept": "application/json", "Content-Type": "application/json", 'api-token': api_token }
    end

    def api_url
      'https://api.helcim.com/v2' # No trailing /
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
