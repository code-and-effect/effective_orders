module Effective
  module Concerns
    module Purchase
      extend ActiveSupport::Concern

      protected

      def admin_checkout?(payment_params)
        payment_params[:purchased_url].to_s.include?('/admin/')
      end

      def order_purchased(payment:, provider:, card: 'none', email: true, skip_buyer_validations: false, purchased_url: nil, current_user: nil)
        @order.purchase!(
          payment: payment, 
          provider: provider, 
          card: card, 
          email: email, 
          skip_buyer_validations: skip_buyer_validations, 
          current_user: current_user
        )

        Effective::Cart.where(user: current_user).destroy_all if current_user.present?

        if flash[:success].blank?
          if email && @order.send_order_receipt_to_buyer?
            flash[:success] = "Payment successful! A receipt has been sent to #{@order.email}"
          else
            flash[:success] = "Payment successful! An email receipt has not been sent."
          end
        end

        purchased_url = effective_orders.purchased_order_path(':id') if purchased_url.blank?
        redirect_to purchased_url.gsub(':id', @order.to_param.to_s)
      end

      def order_deferred(provider:, email: true, deferred_url: nil)
        @order.defer!(provider: provider, email: email)

        Effective::Cart.where(user: current_user).destroy_all if current_user.present?

        if flash[:success].blank?
          if email
            flash[:success] = "Deferred payment created! A request for payment has been sent to #{@order.emails_send_to}"
          else
            flash[:success] = "Deferred payment created!"
          end
        end

        deferred_url = effective_orders.deferred_order_path(':id') if deferred_url.blank?
        redirect_to deferred_url.gsub(':id', @order.to_param.to_s)
      end

      def order_delayed(payment_intent:, provider:, card: 'none', deferred_url: nil, email: false)
        @order.delay!(payment_intent: payment_intent, provider: provider, card: card, email: email)

        Effective::Cart.where(user: current_user).destroy_all if current_user.present?

        if flash[:success].blank?
          if email
            flash[:success] = "Delayed payment created! An email has been sent to #{@order.emails_send_to}"
          else
            flash[:success] = "Delayed payment created!"
          end
        end

        deferred_url = effective_orders.deferred_order_path(':id') if deferred_url.blank?
        redirect_to deferred_url.gsub(':id', @order.to_param.to_s)
      end

      def order_declined(payment:, provider:, card: 'none', declined_url: nil)
        @order.decline!(payment: payment, provider: provider, card: card)

        if flash[:danger].blank?
          flash[:danger] = 'Payment was unsuccessful. Your credit card was declined by the payment processor. Please try again.'
        end

        declined_url = effective_orders.declined_order_path(':id') if declined_url.blank?
        redirect_to declined_url.gsub(':id', @order.to_param.to_s)
      end

      def order_not_processed(declined_url: nil)
        # No change to the order

        if flash[:danger].blank?
          flash[:danger] = 'Payment was not processed. Please try again.'
        end

        declined_url = effective_orders.declined_order_path(':id') if declined_url.blank?
        redirect_to declined_url.gsub(':id', @order.to_param.to_s)
      end

    end
  end
end
