require 'net/http'

module Effective
  module Providers
    module Moneris
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, only: [:moneris_postback]
      end

      def moneris_postback
        raise('moneris provider is not available') unless EffectiveOrders.moneris?

        @order ||= Effective::Order.find(params[:response_order_id])

        # We do this even if we're not authorized
        EffectiveResources.authorized?(self, :update, @order)

        # Delete the Purchased and Declined Redirect URLs
        purchased_url = params.delete(:rvar_purchased_url)
        declined_url = params.delete(:rvar_declined_url)

        if @order.purchased?  # Fallback to a success condition of the Order is already purchased
          return order_purchased(payment: params, provider: 'moneris', card: params[:card], purchased_url: purchased_url)
        end

        # Invalid Result
        if params[:result].to_s != '1' || params[:transactionKey].blank?
          return order_declined(payment: params, provider: 'moneris', card: params[:card], declined_url: declined_url)
        end

        # Verify response from moneris
        payment = params.merge(verify_moneris_transaction(params[:transactionKey]))
        valid = (1..49).include?(payment[:response_code].to_i)  # Must be > 0 and < 50 to be valid. Sometimes we get the string 'null'

        if valid == false
          return order_declined(payment: payment, provider: 'moneris', card: params[:card], declined_url: declined_url)
        end

        order_purchased(payment: payment, provider: 'moneris', card: params[:card], purchased_url: purchased_url, current_user: current_user)
      end

      private

      def verify_moneris_transaction(transactionKey)
        # Send a verification POST request
        uri = URI.parse(EffectiveOrders.moneris[:verify_url])
        params = { ps_store_id: EffectiveOrders.moneris[:ps_store_id], hpp_key: EffectiveOrders.moneris[:hpp_key], transactionKey: transactionKey }
        headers = { 'Referer': effective_orders.moneris_postback_orders_url }

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        body = http.post(uri.path, params.to_query, headers).body

        # Parse response into a Hash
        body.split('<br>').inject({}) { |h, i| h[i.split(' ').first.to_sym] = i.split(' ').last; h }
      end

    end
  end
end
