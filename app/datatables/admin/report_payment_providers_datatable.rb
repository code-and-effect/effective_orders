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

      payment_providers.map do |provider|
        items = order_items.select { |item| item.order.payment_provider == provider }

        [
          provider,
          items.sum { |item| (item.total > 0 ? item.total : 0) }.to_i,
          items.sum { |item| (item.total < 0 ? item.total : 0) }.to_i,
          items.sum { |item| item.total }.to_i,
          start_date,
          end_date
        ]
      end
    end

    def payment_providers
      @payment_providers ||= EffectiveOrders.payment_providers - ['free', 'pretend']
    end

    def date_range
      @date_range ||= (filters[:start_date].presence)..(filters[:end_date].presence)
    end

  end
end
