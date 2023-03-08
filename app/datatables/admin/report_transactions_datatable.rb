# Revenue: Individual Transactions

module Admin
  class ReportTransactionsDatatable < Effective::Datatable

    filters do
      filter_date_range :current_month
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

      col :filtered_start_date, as: :date, search: false, sort: false, visible: false do
        date_range.begin&.strftime('%F')
      end

      col :filtered_end_date, as: :date, search: false, sort: false, visible: false do
        date_range.end&.strftime('%F')
      end

      aggregate :total

      actions_col
    end

    collection do
      Effective::Order.purchased
        .where(purchased_at: date_range)
        .where('total != 0')
        .includes(:user, [order_items: :purchasable])
    end
  end
end
