module Effective
  module Providers
    module Paypal
      extend ActiveSupport::Concern

      included do
        skip_before_action :verify_authenticity_token, only: [:paypal_postback]
      end

      # TODO: Make paypal postback work with admin checkout workflow

      def paypal_postback
        @order ||= Effective::Order.where(id: (params[:invoice].to_i rescue 0)).first

        (EffectiveOrders.authorized?(self, :update, @order) rescue false)

        if @order.present?
          if @order.purchased?
            order_purchased(details: params, provider: 'paypal', card: params[:payment_type])
          elsif (params[:payment_status] == 'Completed' && params[:custom] == EffectiveOrders.paypal[:secret])
            order_purchased(details: params, provider: 'paypal', card: params[:payment_type])
          else
            order_declined(details: params, provider: 'paypal', card: params[:payment_type])
          end
        end

        head(:ok)
      end


    end
  end
end
