class EffectiveOrdersDatatable < Effective::Datatable
  bulk_actions do
    if (EffectiveOrders.authorized?(view.controller, :admin, :effective_orders) rescue false)
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

  datatable do
    order :created_at, :desc

    bulk_actions_col

    col :purchased_at

    col :id

    if attributes[:user_id].blank?
      col :user, label: 'Buyer', search: :string, sort: :email do |order|
        link_to order.user.email, (edit_admin_user_path(order.user) rescue admin_user_path(order.user) rescue '#')
      end

      if EffectiveOrders.require_billing_address && EffectiveOrders.use_address_full_name
        val :buyer_name, visible: false do |order|
          order.billing_address.try(:full_name)
        end
      else
        val :buyer_name, visible: false do |order|
          order.user.to_s
        end
      end
    end

    if EffectiveOrders.require_billing_address
      col :billing_address
    end

    if EffectiveOrders.require_shipping_address
      col :shipping_address
    end

    col :purchase_state, label: 'State', search: { collection: EffectiveOrders::PURCHASE_STATES.invert } do |order|
      EffectiveOrders::PURCHASE_STATES[order.purchase_state]
    end

    col :order_items, search: { as: :string }

    col :subtotal, as: :price
    col :tax, as: :price

    col :tax_rate, visible: false do |order|
      tax_rate_to_percentage(order.tax_rate)
    end

    col :total, as: :price

    col :payment_provider, label: 'Provider', visible: false, search: { collection: ['nil'] + (EffectiveOrders.payment_providers + EffectiveOrders.other_payment_providers).sort }
    col :payment_card, label: 'Card'

    col :note, visible: false
    col :note_to_buyer, visible: false
    col :note_internal, visible: false

    col :created_at, visible: false
    col :updated_at, visible: false

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
