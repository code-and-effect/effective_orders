class Admin::EffectiveOrdersDatatable < Effective::Datatable
  bulk_actions do
    bulk_action(
    'Send payment request email to selected orders',
      effective_orders.bulk_send_payment_request_admin_orders_path,
      data: { confirm: 'Send payment request emails?' }
    )

    bulk_action(
    'Send receipt email to selected purchased orders',
      effective_orders.bulk_send_buyer_receipt_orders_path,
      data: { confirm: 'Send receipt emails?' }
    )
  end

  filters do
    scope :purchased, default: true
    scope :deferred
    scope :refunds
    scope :not_purchased
    scope :all
  end

  datatable do
    order :id, :desc

    bulk_actions_col

    col :created_at, visible: false
    col :updated_at, visible: false

    col :id, label: 'Number' do |order|
      '#' + order.to_param
    end

    col :purchased_at do |order|
      order.purchased_at&.strftime('%F %H:%M') || 'not purchased'
    end

    if attributes[:user_id].blank?
      col :user
      col 'user.email', visible: false
      col :billing_name, visible: false
    end

    if EffectiveOrders.billing_address
      col :billing_address, visible: false
    end

    if EffectiveOrders.shipping_address
      col :shipping_address, visible: false
    end

    col :order_items, search: { as: :string }

    col :subtotal, as: :price, visible: false
    col :tax, as: :price, visible: false

    col :tax_rate, visible: false do |order|
      tax_rate_to_percentage(order.tax_rate)
    end

    col :total, as: :price

    col :payment_provider, label: 'Provider', visible: false, search: { collection: EffectiveOrders.payment_providers }
    col :payment_card, label: 'Card', visible: false

    if EffectiveOrders.collect_note
      col :note, visible: false
    end

    col :note_to_buyer, visible: false
    col :note_internal, visible: false

    actions_col partial: 'admin/orders/datatable_actions', partial_as: :order

    aggregate :total
  end

  collection do
    scope = Effective::Order.all.includes(:addresses, :order_items, :user)

    if EffectiveOrders.orders_collection_scope.respond_to?(:call)
      scope = EffectiveOrders.orders_collection_scope.call(scope)
    end

    if attributes[:user_id].present?
      scope = scope.where(user_id: attributes[:user_id])
    else
      scope = scope.joins(:user)
    end

    scope
  end

end
