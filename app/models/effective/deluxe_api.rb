# https://developer.deluxe.com/s/article-api-reference
# We use Oauth2 client to get an authorization token. Then pass that token into a REST api.
# We get a payment_intent from the front end HostedPaymentForm, then call authorize and complete on it.
module Effective
  class DeluxeApi
    SCRUB = /[^\w\d#,\s]/

    # All required
    attr_accessor :environment
    attr_accessor :client_id
    attr_accessor :client_secret
    attr_accessor :access_token
    attr_accessor :currency

    def initialize(environment: nil, client_id: nil, client_secret: nil, access_token: nil, currency: nil)
      self.environment = environment || EffectiveOrders.deluxe.fetch(:environment)
      self.client_id = client_id || EffectiveOrders.deluxe.fetch(:client_id)
      self.client_secret = client_secret || EffectiveOrders.deluxe.fetch(:client_secret)
      self.access_token = access_token || EffectiveOrders.deluxe.fetch(:access_token)
      self.currency = currency || EffectiveOrders.deluxe.fetch(:currency)
    end

    # Health Check
    def health_check
      get('/')
    end

    # Authorize Payment
    def authorize_payment(order, payment_intent)
      response = post('/payments/authorize', params: authorize_payment_params(order, payment_intent))

      # Sanity check response
      raise('expected responseCode') unless response.kind_of?(Hash) && response['responseCode'].present?

      # Sanity check response approved vs authorized
      valid = [0].include?(response['responseCode'])

      # We might be approved for an amount less than the order total. Not sure what to do here
      if valid && (amountApproved = response['amountApproved']) != (amountAuthorized = order.total_to_f)
        raise("expected authorize payment amountApproved #{amountApproved} to be the same as the amountAuthorized #{amountAuthorized} but it was not")
      end

      # Generate the card info we can store
      card = card_info(payment_intent)

      # Return the authorization params merged with the card info
      response.reverse_merge(card)
    end

    # Complete Payment
    def complete_payment(order, authorization)
      response = post('/payments/complete', params: complete_payment_params(order, authorization))

      # Sanity check response
      raise('expected responseCode') unless response.kind_of?(Hash) && response['responseCode'].present?

      # Sanity check response approved vs authorized
      valid = [0].include?(response['responseCode'])

      # We might be approved for an amount less than the order total. Not sure what to do here
      if valid && (amountApproved = response['amountApproved']) != (amountAuthorized = order.total_to_f)
        raise("expected complete payment amountApproved #{amountApproved} to be the same as the amountAuthorized #{amountAuthorized} but it was not")
      end

      # The authorization information
      authorization = { 'paymentId' => authorization } if authorization.kind_of?(String)

      # Return the complete params merged with the authorization params
      response.reverse_merge(authorization)
    end

    def complete_payment_params(order, payment_intent)
      raise('expected an Effective::Order') unless order.kind_of?(Effective::Order)

      payment_id = extract_payment_id(payment_intent)
      amount = { amount: order.total_to_f, currency: currency }

      # Params passed into Complete Payment
      { 
        paymentId: payment_id, 
        amount: amount
      }
    end

    def authorize_payment_params(order, payment_intent)
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

      # Params passed into Authorize Payment
      {
        amount: amount, 
        paymentMethod: paymentMethod,
        shippingAddress: shippingAddress,
        customData: customData,
      }.compact
    end

    def get(endpoint, params: nil)
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(api_url + endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
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
      http.read_timeout = 10
      http.use_ssl = true

      result = with_retries do
        puts "[POST] #{uri} #{params}" if Rails.env.development?

        response = http.post(uri.path, params.to_json, headers)
        raise Exception.new("#{response.code} #{response.body}") unless response.code == '200'

        response
      end

      JSON.parse(result.body)
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
      @authorization_token ||= Rails.cache.fetch("deluxe_api_#{client_id}", expires_in: 60.minutes) do 
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

    def with_retries(retries: (Rails.env.development? ? 0 : 3), wait: 2, &block)
      raise('expected a block') unless block_given?

      begin
        return yield
      rescue Exception => e
        # Reset cache and query for a new authorization token on any error
        Rails.cache.delete(client_id)
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

# d = Effective::DeluxeApi.new.health_check
