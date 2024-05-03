# https://developer.deluxe.com/s/article-api-reference

module Effective
  class DeluxeApi

    def health_check
      puts authenticate

      binding.pry

      endpoint = 'https://sandbox.api.deluxe.com/dpp/v1/gateway/'
      response = get(endpoint, headers: { 'Authorization' => "Bearer #{@access_token}" })

      binding.pry

      #response = client.request(:get, '/', headers: { 'Authorization' => "Bearer #{@access_token}" })
      JSON.parse(response.body)
    end

    def authenticate
      @access_token ||= oauth2_client.client_credentials.get_token.token
    end

    # https://sandbox.api.deluxe.com/dpp/v1/gateway/

    # https://sandbox.api.deluxe.com/secservices/oauth2/v2/token

    def oauth2_client
      @client ||= OAuth2::Client.new(
        EffectiveOrders.deluxe.fetch(:client_id),
        EffectiveOrders.deluxe.fetch(:client_secret),
        site: 'https://sandbox.api.deluxe.com',
        token_url: '/secservices/oauth2/v2/token'
      )
    end

    def get(endpoint, params: nil, headers: nil)
      headers = { 'Content-Type': 'application/json' }.merge(headers || {})
      query = ('?' + params.compact.map { |k, v| "$#{k}=#{v}" }.join('&')) if params.present?

      uri = URI.parse(endpoint + query.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 10
      http.use_ssl = true if endpoint.start_with?('https')

      response = with_retries do
        puts "[GET] #{uri}" if Rails.env.development?
        http.get(uri, headers)
      end

      unless ['200', '204'].include?(response.code.to_s)
        puts("Response code: #{response.code} #{response.body}")
        return false
      end

      JSON.parse(response.body)
    end

    def with_retries(retries: 3, wait: 2, &block)
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

# d = Effective::DeluxeApi.new.health_check
