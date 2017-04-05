unless Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
  class EffectiveOrdersDatatable < Effective::Datatable
    datatable do
      order :created_at, :desc

      col :purchased_at

      col :id do |order|
        link_to order.to_param, effective_orders.admin_order_path(order)
      end

      # Don't display email or buyer_name column if this is for a specific user
      if attributes[:user_id].blank?
        col :email, sql_column: 'users.email', label: 'Buyer Email' do |order|
          link_to order.user.email, (edit_admin_user_path(order.user) rescue admin_user_path(order.user) rescue '#')
        end

        if EffectiveOrders.use_address_full_name
          col :buyer_name, sql_column: 'addresses.full_name' do |order|
            order.billing_address.try(:full_name)
          end

        elsif # Not using address full name
          col :buyer_name, sql_column: 'users.*' do |order|
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
        order.purchase_state || 'abandoned'
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
    end

    collection do
      collection = Effective::Order.unscoped
        .joins(:user)
        .includes(:addresses)
        .includes(:user)
        .includes(:order_items)

      if EffectiveOrders.orders_collection_scope.respond_to?(:call)
        collection = EffectiveOrders.orders_collection_scope.call(collection)
      end

      attributes[:user_id].present? ? collection.where(user_id: attributes[:user_id]) : collection
    end

    def purchase_state_filter_values
      [
        %w(abandoned nil),
        [EffectiveOrders::PURCHASED, EffectiveOrders::PURCHASED],
        [EffectiveOrders::DECLINED, EffectiveOrders::DECLINED],
        [EffectiveOrders::PENDING, EffectiveOrders::PENDING]
      ]
    end
  end
end
