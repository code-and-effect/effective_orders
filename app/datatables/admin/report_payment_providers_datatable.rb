# Revenue: Payment Providers

module Admin
  class ReportPaymentProvidersDatatable < Effective::Datatable
    filters do
      filter_date_range :current_month
    end

    datatable do
      length 250

      col :payment_provider

      col :sales, as: :price
      col :returns, as: :price
      col :total, as: :price

      col :orders_count, visible: false

      col :users, visible: false

      col :filtered_start_date, as: :date, search: false, sort: false, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :filtered_end_date, as: :date, search: false, sort: false, visible: false do
        date_range.end&.strftime('%F')
      end

      col(:orders, col_class: 'col-actions', search: false, sort: false) do |orders, row|
        if orders.present?
          title = pluralize(orders.length, 'orders')
          order_ids = orders.map(&:id).join("|")

          path = effective_orders.nested_orders_admin_order_reports_path(ids: order_ids)
          nested_datatable_link_to(title, path, title: row.first)
        end
      end

      aggregate :total
    end

    collection do
      start_date = date_range.begin&.strftime('%F')
      end_date = date_range.end&.strftime('%F')

      orders = Effective::Order.purchased.where(purchased_at: date_range).where('total != 0').includes(:user)
      order_items = Effective::OrderItem.where(order_id: orders).includes(:purchasable, order: :user)

      payment_providers.map do |provider|
        provider_orders = orders.select { |order| order.payment_provider == provider }
        items = order_items.select { |item| item.order.payment_provider == provider }

        [
          provider,
          items.sum { |item| (item.total > 0 ? item.total : 0) }.to_i,
          items.sum { |item| (item.total < 0 ? item.total : 0) }.to_i,
          items.sum { |item| item.total }.to_i,
          provider_orders.length,
          provider_orders.map(&:user),
          start_date,
          end_date,
          provider_orders
        ]
      end
    end

    def payment_providers
      @payment_providers ||= Effective::Order.purchased.group(:payment_provider).pluck(:payment_provider) - ['free', 'pretend', '', nil]
    end

  end
end
