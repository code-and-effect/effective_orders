module Effective
  module Providers
    module Moneris
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, only: [:moneris_postback]
      end

      def moneris_postback
        @order ||= Effective::Order.find(params[:response_order_id])

        (EffectiveOrders.authorized?(self, :update, @order) rescue false)

        # Delete the Purchased and Declined Redirect URLs
        purchased_url = params.delete(:rvar_purchased_url)
        declined_url = params.delete(:rvar_declined_url)

        if @order.purchased?  # Fallback to a success condition of the Order is already purchased
          order_purchased(details: params, provider: 'moneris', card: params[:card], purchased_url: purchased_url)
          return
        end

        if params[:result].to_s == '1' && params[:transactionKey].present?
          verify_params = parse_moneris_response(send_moneris_verify_request(params[:transactionKey])) || {}

          response_code = verify_params[:response_code].to_i # Sometimes moneris sends us the string 'null'

          if response_code > 0 && response_code < 50  # Less than 50 means a successful validation
            order_purchased(details: params.merge(verify_params), provider: 'moneris', card: params[:card], purchased_url: purchased_url)
          else
            order_declined(details: params.merge(verify_params), provider: 'moneris', card: params[:card], declined_url: declined_url)
          end
        else
          order_declined(details: params, provider: 'moneris', card: params[:card], declined_url: declined_url)
        end
      end

      private

      def parse_moneris_response(text)
        text.split("<br>").inject(Hash.new()) { |h, i| h[i.split(' ').first.to_sym] = i.split(' ').last ; h } rescue {response: text}
      end

      def send_moneris_verify_request(verify_key)
        `curl -F ps_store_id='#{EffectiveOrders.moneris[:ps_store_id]}' -F hpp_key='#{EffectiveOrders.moneris[:hpp_key]}' -F transactionKey='#{verify_key}' --referer #{effective_orders.moneris_postback_orders_url} #{EffectiveOrders.moneris[:verify_url]}`
      end

    end
  end
end
