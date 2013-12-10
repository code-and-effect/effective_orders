module Effective
  module Providers
    module Moneris
      extend ActiveSupport::Concern

      included do
        prepend_before_filter :find_authenticity_token_from_moneris, :only => [:moneris_postback]
      end

      def moneris_postback
        @order ||= Effective::Order.find((params[:response_order_id].gsub('order', '').to_i rescue 0) - EffectiveOrders.order_nudge_id.to_i)

        EffectiveOrders.authorized?(self, :create, @order)

        if params[:result].to_s == '1' && params[:transactionKey].present?
          verify_params = parse_moneris_response(send_moneris_verify_request(params[:transactionKey]))

          if (verify_params[:response_code].to_i || 999) < 50  # Less than 50 means a successful validation
            order_purchased(params.merge(verify_params))
          else
            order_declined(params.merge(verify_params))
          end
        else
          order_declined(params)
        end
      end

      private

      def parse_moneris_response(text)
        text.split("<br>").inject(Hash.new()) { |h, i| h[i.split(' ').first.to_sym] = i.split(' ').last ; h } rescue {:response => text}
      end

      def send_moneris_verify_request(verify_key)
        `curl -F ps_store_id='#{EffectiveOrders.moneris[:ps_store_id]}' -F hpp_key='#{EffectiveOrders.moneris[:hpp_key]}' -F transactionKey='#{verify_key}' --referer #{effective_orders.orders_url} #{EffectiveOrders.moneris[:verify_url]}`
      end

      def find_authenticity_token_from_moneris
        params[:authenticity_token] = params.delete(:rvar_authenticity_token)
      end

    end
  end
end
