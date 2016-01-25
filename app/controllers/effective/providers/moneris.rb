module Effective
  module Providers
    module Moneris
      extend ActiveSupport::Concern

      included do
        prepend_before_filter :find_authenticity_token_from_moneris, :only => [:moneris_postback]
      end

      def moneris_postback
        @order ||= Effective::Order.find(params[:response_order_id])

        EffectiveOrders.authorized?(self, :update, @order)

        # Delete the Purchased and Declined Redirect URLs
        purchased_redirect_url = params.delete(:rvar_purchased_redirect_url)
        declined_redirect_url = params.delete(:rvar_declined_redirect_url)

        if @order.purchased?  # Fallback to a success condition of the Order is already purchased
          order_purchased(details: params, redirect_url: purchased_redirect_url)
          return
        end

        if params[:result].to_s == '1' && params[:transactionKey].present?
          verify_params = parse_moneris_response(send_moneris_verify_request(params[:transactionKey])) || {}

          response_code = verify_params[:response_code].to_i # Sometimes moneris sends us the string 'null'

          if response_code > 0 && response_code < 50  # Less than 50 means a successful validation
            order_purchased(details: params.merge(verify_params), redirect_url: purchased_redirect_url)
          else
            order_declined(details: params.merge(verify_params), redirect_url: declined_redirect_url)
          end
        else
          order_declined(details: params, redirect_url: declined_redirect_url)
        end
      end

      private

      def parse_moneris_response(text)
        text.split("<br>").inject(Hash.new()) { |h, i| h[i.split(' ').first.to_sym] = i.split(' ').last ; h } rescue {:response => text}
      end

      def send_moneris_verify_request(verify_key)
        `curl -F ps_store_id='#{EffectiveOrders.moneris[:ps_store_id]}' -F hpp_key='#{EffectiveOrders.moneris[:hpp_key]}' -F transactionKey='#{verify_key}' --referer #{effective_orders.moneris_postback_url} #{EffectiveOrders.moneris[:verify_url]}`
      end

      def find_authenticity_token_from_moneris
        params[:authenticity_token] = params.delete(:rvar_authenticity_token)
      end

    end
  end
end


# Instructions to set up a Test Moneris Store

# https://esqa.moneris.com/mpg/index.php

# demouser
# store2
# password

# Click on the ADMIN -> hosted config

# Generate a Version3 Configuration

# This should bring us to a "hosted Paypage Configuration"

# == Basic Configuration ==
# - Transaction Type: Purchase
# - Response Method Sent to your server as a POST
# - Approved URL:  http://ourwebsite.com/orders/moneris_postback
# - Declined URL:  http://ourwebsite.com/orders/moneris_postback

# == Appearance ==
# - Display item details
# - Display customer details
# - Display billing address details
# - Display merchant name
# - Cancel Button Text: Cancel Transaction
# - Cancel Button URL  http://ourwebsite.com

# == Response Fields ==
# - Ignore, leave blank, the asynchronous data post
# - Do not Perform an asynchronous data post.  Leave Async Response URL blank

# == Security ==
# Add a URL http://ourwebsite.com/orders/new
# Click YES Enable Transaction Verification
# Sent to your server as a POST
# Response URL:  http://ourwebsite.com/orders/moneris_postback

# Displayed as key/value pairs on our server
