# Revenue: Transactions Grouped By Name

module Admin
  class ReportTransactionsGroupedByQbNameDatatable < Effective::Datatable
    filters do
      filter_date_range :current_month
    end

    datatable do
      length 250

      col :qb_item_name
      col :subtotal, as: :price
      col :tax, as: :price
      col :total, as: :price

      payment_providers.each do |provider|
        col("p - #{provider}", as: :price, visible: false)
      end

      col :orders_count, visible: false

      col :users, visible: false

      col :start_date, as: :date, search: false, sort: false, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :end_date, as: :date, search: false, sort: false, visible: false do
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

      orders = Effective::Order.purchased.where(purchased_at: date_range).where('total != 0')
      order_items = Effective::OrderItem.includes(:qb_order_item).where(order_id: orders).includes(:purchasable, order: :user)

      items = order_items.group_by(&:qb_item_name).map do |name, items|
        row = [
          name,
          items.sum { |item| item.subtotal }.to_i,
          items.sum { |item| item.tax }.to_i,
          items.sum { |item| item.total }.to_i,
        ]

        row += payment_providers.map do |payment_provider|
          items.sum { |item| (item.order.payment_provider == payment_provider) ? item.total : 0 }.to_i
        end

        orders = items.map { |item| item.order }.uniq.sort

        row += [
          orders.length,
          orders.map(&:user),
          start_date,
          end_date,
          orders
        ]

        row
      end
    end

    def payment_providers
      @payment_providers ||= Effective::Order.purchased.group(:payment_provider).pluck(:payment_provider) - ['free', 'pretend', '', nil]
    end

  end
end
