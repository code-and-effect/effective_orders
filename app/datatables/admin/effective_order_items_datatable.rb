module Admin
  class EffectiveOrderItemsDatatable < Effective::Datatable
    datatable do
      order :created_at

      col :id, visible: false
      col :created_at, visible: false
      col :updated_at, visible: false

      col :order

      col :order_status, search: Effective::Order.new.all_statuses do |order_item|
        order_item.order.status
      end

      col :purchasable, visible: false

      col :name
      col :quantity
      col :price, as: :price

      col :total, as: :price

      col :qb_item_name, label: qb_item_name_label, search: Effective::ItemName.sorted.map(&:to_s)

      actions_col
    end

    collection do
      Effective::OrderItem.all.includes(:order)
    end
  end
end
