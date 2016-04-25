if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class Orders < Effective::Datatable
        datatable do
          default_order :created_at, :desc

          table_column :purchased_at

          table_column :id, label: 'ID' do |order|
            link_to order.to_param, effective_orders.admin_order_path(order)
          end

          # Don't display email or buyer_name column if this is for a specific user
          if attributes[:user_id].blank?
            table_column :email, column: 'users.email', label: 'Buyer Email' do |order|
              link_to order.user.email, (edit_admin_user_path(order.user) rescue admin_user_path(order.user) rescue '#')
            end

            if EffectiveOrders.use_address_full_name
              table_column :buyer_name, column: 'addresses.full_name' do |order|
                order.billing_address.try(:full_name)
              end

            elsif # Not using address full name
              table_column :buyer_name, column: 'users.*' do |order|
                order.user.to_s
              end
            end
          end

          if EffectiveOrders.require_billing_address
            table_column :billing_address
          end

          if EffectiveOrders.require_shipping_address
            table_column :shipping_address
          end

          table_column :purchase_state, label: 'State', filter: { values: purchase_state_filter_values } do |order|
            order.purchase_state || 'abandoned'
          end

          table_column :order_items, column: 'order_items.title', filter: :string

          table_column :subtotal, as: :price
          table_column :tax, as: :price

          table_column :tax_rate, visible: false do |order|
            tax_rate_to_percentage(order.tax_rate)
          end

          table_column :total, as: :price

          table_column :payment_provider, label: 'Provider', visible: false, filter: { values: ['nil'] + EffectiveOrders.payment_providers + EffectiveOrders.other_payment_providers }
          table_column :payment_card, label: 'Card'

          table_column :note, visible: false
          table_column :note_to_buyer, visible: false
          table_column :note_internal, visible: false

          table_column :created_at, visible: false
          table_column :updated_at, visible: false

          table_column :actions, sortable: false, filter: false, partial: 'admin/orders/actions'
        end

        def collection
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
  end
end
