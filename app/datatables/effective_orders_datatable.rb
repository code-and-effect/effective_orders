unless Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
  class EffectiveOrdersDatatable < Effective::Datatable
    datatable do
      order :created_at, :desc

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

      col :purchase_state, label: 'State', search: { collection: purchase_state_filter_values } do |order|
        order.purchase_state || EffectiveOrders::ABANDONED
      end

      col :order_items

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

    def purchase_state_filter_values
      [
        [EffectiveOrders::ABANDONED, nil],
        [EffectiveOrders::PURCHASED, EffectiveOrders::PURCHASED],
        [EffectiveOrders::DECLINED, EffectiveOrders::DECLINED],
        [EffectiveOrders::PENDING, EffectiveOrders::PENDING]
      ]
    end
  end
end
