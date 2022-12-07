# Revenue: Individual Transactions

module Admin
  class ReportTransactionsDatatable < Effective::Datatable

    filters do
      filter :start_date, nil, as: :date
      filter :end_date, nil, as: :date
    end

    datatable do
      order :id, :desc
      length 250

      col :created_at, visible: false

      col :id, label: 'Order' do |order|
        link_to(order.to_param, effective_orders.admin_order_path(order))
      end

      col :purchased_at
      col :user
      col :order_items

      col :subtotal, as: :price
      col :tax, as: :price
      col(:tax_rate) { |order| rate_to_percentage(order.tax_rate) }.aggregate { nil }

      col :amount_owing, as: :price

      if EffectiveOrders.surcharge?
        col :surcharge, as: :price
        col(:surcharge_percent) { |order| rate_to_percentage(order.surcharge_percent) }.aggregate { nil }
      end

      col :total, as: :price

      col :start_date, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :end_date, visible: false do
        date_range.end&.strftime('%F')
      end

      aggregate :total

      actions_col
    end

    collection do
      Effective::Order.purchased.where(purchased_at: date_range).includes(:user, [order_items: :purchasable])
    end

    def date_range
      @date_range ||= (filters[:start_date].presence)..(filters[:end_date].presence)
    end

  end
end
