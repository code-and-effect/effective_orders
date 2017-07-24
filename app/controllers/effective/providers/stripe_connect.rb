module Effective
  module Providers
    module StripeConnect
      extend ActiveSupport::Concern

      included do
        prepend_before_action :set_stripe_connect_state_params, only: [:stripe_connect_redirect_uri]
      end

      # So this is the postback after Stripe does its oAuth authentication
      def stripe_connect_redirect_uri
        if params[:code].present?
          token_params = request_access_token(params[:code]) # We got a code, so now we make a curl request for the access_token
          customer = Effective::Customer.for(current_user)

          if token_params['access_token'].present? && customer.present?
            if customer.update_attributes(:stripe_connect_access_token => token_params['access_token'])
              flash[:success] = 'Successfully Connected with Stripe Connect'
            else
              flash[:danger] = "Unable to update customer: #{customer.errors[:base].first}"
            end
          else
            flash[:danger] = "Error when connecting to Stripe /oauth/token: #{token_params[:error]}.  Please try again."
          end
        else
          flash[:danger] = "Error when connecting to Stripe /oauth/authorize: #{params[:error]}.  Please try again."
        end

        redirect_to URI.parse(@stripe_state_params['redirect_to']).path rescue effective_orders.orders_path
      end

      private

      def request_access_token(code)
        stripe_response = `curl -F client_secret='#{EffectiveOrders.stripe[:secret_key]}' -F code='#{code}' -F grant_type='authorization_code' #{EffectiveStripeHelper::STRIPE_CONNECT_TOKEN_URL}`
        JSON.parse(stripe_response) rescue {}
      end

      def set_stripe_connect_state_params
        @stripe_state_params = (JSON.parse(params[:state]) rescue {})
        @stripe_state_params = {} unless @stripe_state_params.kind_of?(Hash)

        params[:authenticity_token] = @stripe_state_params['form_authenticity_token']
      end
    end
  end
end
