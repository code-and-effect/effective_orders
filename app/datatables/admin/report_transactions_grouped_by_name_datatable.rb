# Revenue: Transactions Grouped By Name

module Admin
  class ReportTransactionsGroupedByNameDatatable < Effective::Datatable
    filters do
      filter_date_range :current_month
    end

    datatable do
      length 250

      col :item
      col :subtotal, as: :price
      col :tax, as: :price
      col :total, as: :price

      payment_providers.each do |provider|
        col("p - #{provider}", as: :price, visible: false)
      end

      col :orders_count

      col :orders, visible: false
      col :users, visible: false

      col :filtered_start_date, as: :date, search: false, sort: false, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :filtered_end_date, as: :date, search: false, sort: false, visible: false do
        date_range.end&.strftime('%F')
      end

      aggregate :total
    end

    collection do
      start_date = date_range.begin&.strftime('%F')
      end_date = date_range.end&.strftime('%F')

      orders = Effective::Order.purchased.where(purchased_at: date_range).where('total != 0')
      order_items = Effective::OrderItem.where(order_id: orders).includes(:purchasable, order: :user)

      items = order_items.group_by(&:to_s).map do |name, items|
        row = [
          name,
          items.sum { |item| item.subtotal }.to_i,
          items.sum { |item| item.tax }.to_i,
          items.sum { |item| item.total }.to_i,
        ]

        row += payment_providers.map do |payment_provider|
          items.sum { |item| (item.order.payment_provider == payment_provider) ? item.total : 0 }.to_i
        end

        row += [
          items.map(&:order_id).uniq.length,
          items.map { |item| item.order },
          items.map { |item| item.order.user },
          start_date,
          end_date
        ]

        row
      end
    end

    def payment_providers
      @payment_providers ||= EffectiveOrders.payment_providers - ['free', 'pretend']
    end

  end
end
