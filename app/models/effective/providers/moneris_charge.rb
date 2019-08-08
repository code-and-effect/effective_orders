require 'nokogiri'

module Effective
  module Providers
    class MonerisCharge
      attr_accessor :order, :purchased_url, :declined_url
      attr_accessor :hpp_id, :ticket # return values

      def initialize(order:, purchased_url: nil, declined_url: nil)
        @order = order
        @purchased_url = purchased_url
        @declined_url = declined_url

        moneris_preload!
      end

      def present?
        ticket.present? && hpp_id.present?
      end

      def moneris_preload!
        # Make the moneris preload request
        uri = URI.parse(EffectiveOrders.moneris[:hpp_url])
        params = moneris_preload_payload.to_query
        headers = {}

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        body = http.post(uri.path, params, headers).body
        doc = ::Nokogiri::XML(body)

        # Parse preload request
        moneris = [:hpp_id, :ticket, :order_id, :response_code].inject({}) do |h, key|
          h[key] = doc.xpath("//#{key}").children.first.to_s; h
        end

        # Transaction Response Code: < 50: data successfully loaded, >= 50: data not loaded
        moneris[:response_code] = (moneris[:response_code].to_i rescue 50)

        raise 'data not loaded' unless moneris[:response_code] < 50

        # Our return value
        @hpp_id = moneris[:hpp_id]
        @ticket = moneris[:ticket]
      end

      def moneris_preload_payload
        payload = {
          ps_store_id: EffectiveOrders.moneris[:ps_store_id],
          hpp_key: EffectiveOrders.moneris[:hpp_key],
          hpp_preload: '',
          charge_total: ('%.2f' % (order.total / 100.0)),

          # Optional
          order_id: order_id,
          lang: 'en-ca',
          email: order.user.email,

          rvar_purchased_url: purchased_url,
          rvar_declined_url: declined_url
        }.compact

        if order.tax.present?
          payload[:gst] = ('%.2f' % (order.tax / 100.0))
        end

        if order.billing_name.present?
          payload[:bill_first_name] = order.billing_name.split(' ')[0]
          payload[:bill_last_name] = order.billing_name.split(' ')[1..-1].join(' ')
        end

        if order.billing_address.present?
          address = order.billing_address
          payload[:bill_address_one] = address.address1
          payload[:bill_city] = address.city
          payload[:bill_state_or_province] = address.state
          payload[:bill_postal_code] = address.postal_code
          payload[:bill_country] = address.country
        end

        if order.shipping_address.present?
          address = order.shipping_address
          payload[:ship_address_one] = address.address1
          payload[:ship_city] = address.city
          payload[:ship_state_or_province] = address.state
          payload[:ship_postal_code] = address.postal_code
          payload[:ship_country] = address.country
        end

        order.order_items.each_with_index do |item, index|
          payload["id#{index}"] = index
          payload["description#{index}"] = item.title
          payload["quantity#{index}"] = item.quantity
          payload["price#{index}"] = ('%.2f' % (item.price / 100.0))
          payload["subtotal#{index}"] = ('%.2f' % (item.subtotal / 100.0))
        end

        payload
      end

      private

      def order_id
        [
          order.to_param,
          (order.billing_name.to_s.parameterize.presence if EffectiveOrders.moneris[:include_billing_name_in_order_id])
        ].compact.join('-')
      end

    end

  end
end
