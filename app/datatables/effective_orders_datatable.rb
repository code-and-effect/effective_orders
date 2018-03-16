class EffectiveOrdersDatatable < Effective::Datatable
  bulk_actions do
    if EffectiveOrders.authorized?(view.controller, :admin, :effective_orders)
      bulk_action(
      'Send payment request email to selected pending orders',
        effective_orders.bulk_send_payment_request_admin_orders_path,
        data: { confirm: 'Send payment request emails to pending orders?' }
      )
    end

    bulk_action(
    'Send receipt email to selected purchased orders',
      effective_orders.bulk_send_buyer_receipt_orders_path,
      data: { confirm: 'Send receipt emails to purchased orders?' }
    )
  end

  filters do
    scope :purchased, default: true
    scope :not_purchased
    scope :all
  end

  datatable do
    order :id

    bulk_actions_col

    col :created_at, visible: false
    col :updated_at, visible: false
    col :id, visible: false

    col :purchased_at do |order|
      order.purchased_at&.strftime('%F %H:%M') || 'not purchased'
    end

    if attributes[:user_id].blank?
      col :user

      col :email, label: 'Email', visible: false, search: :string, sort: :email do |order|
        link_to order.user.email, (edit_admin_user_path(order.user) rescue admin_user_path(order.user) rescue '#')
      end

      col :billing_name, visible: false
    end

    if EffectiveOrders.billing_address
      col :billing_address, visible: false
    end

    if EffectiveOrders.shipping_address
      col :shipping_address, visible: false
    end

    # col :state, label: 'State', search: { collection: EffectiveOrders::STATES.invert } do |order|
    #   EffectiveOrders::STATES[order.state]
    # end

    col :order_items, search: { as: :string }

    col :subtotal, as: :price, visible: false
    col :tax, as: :price, visible: false

    col :tax_rate, visible: false do |order|
      tax_rate_to_percentage(order.tax_rate)
    end

    col :total, as: :price

    col :payment_provider, label: 'Provider', visible: false, search: { collection: EffectiveOrders.payment_providers }
    col :payment_card, label: 'Card', visible: false

    col :note, visible: EffectiveOrders.collect_note
    col :note_to_buyer, visible: false
    col :note_internal, visible: false

    actions_col partial: 'admin/orders/actions', partial_as: :order

    aggregate :total
  end

  collection do
    scope = Effective::Order.unscoped.includes(:addresses, :order_items, :user)

    if EffectiveOrders.orders_collection_scope.respond_to?(:call)
      scope = EffectiveOrders.orders_collection_scope.call(scope)
    end

    attributes[:user_id].present? ? scope.where(user_id: attributes[:user_id]) : scope
  end

end
