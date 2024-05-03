# https://developer.deluxe.com/s/article-api-reference
#
module Effective
  class DeluxeApi

    # Effective::DeluxeApi.new.health_check
    # https://sandbox.api.deluxe.com/dpp/v1/gateway/
    # {"timestamp"=>"2024-05-03T16:35:57-0500", "assetId"=>"dpp-gateway-exp", "assetVersion"=>"1.0.29", "appName"=>"dlx-dpp-gateway-exp-secsbxusw-1", "runtime"=>"4.4.0-20240408", "environment"=>"secsbxusw"}
    def health_check
      get('/')
    end

    def authorize_payment(params)
      post('/payments/authorize', params: params)
    end

    def get(endpoint, params: nil, headers: nil)
      headers = default_headers.merge(headers || {})
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

    def post(endpoint, params:, headers: nil)
      headers = default_headers.merge(headers || {})

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

    private

    def default_headers
      { "Content-Type": "application/json", "Authorization": "Bearer #{authorization_token}", "PartnerToken": partner_token }
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
      @authorization_token ||= Rails.cache.fetch(client_id, expires_in: 60.minutes) do 
        client.client_credentials.get_token.token
      end
    end

    # https://sandbox.api.deluxe.com
    def client_url
      EffectiveOrders.deluxe_client_url
    end

    # https://sandbox.api.deluxe.com/dpp/v1/gateway/
    def api_url
      client_url + '/dpp/v1/gateway'
    end

    def client_id
      EffectiveOrders.deluxe.fetch(:client_id)
    end

    def client_secret
      EffectiveOrders.deluxe.fetch(:client_secret)
    end

    def partner_token
      EffectiveOrders.deluxe.fetch(:access_token)
    end

    def with_retries(retries: 3, wait: 2, &block)
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
