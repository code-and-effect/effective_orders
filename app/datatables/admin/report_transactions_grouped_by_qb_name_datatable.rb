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

      col :orders_count

      val(:details, visible: false) do |_, orders|
        orders.map do |order|
          content_tag(:div, class: 'col-resource_item') do
            link_to(order.full_to_s, effective_orders.admin_order_path(order), title: order.full_to_s)
          end
        end.join.html_safe
      end

      col :users, visible: false

      col :start_date, as: :date, search: false, sort: false, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :end_date, as: :date, search: false, sort: false, visible: false do
        date_range.end&.strftime('%F')
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
          orders,
          orders.map(&:user),
          start_date,
          end_date
        ]

        row
      end
    end

    def payment_providers
      @payment_providers ||= Effective::Order.purchased.group(:payment_provider).pluck(:payment_provider) - ['free', 'pretend', '', nil]
    end

  end
end
