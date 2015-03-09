if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class OrderItems < Effective::Datatable
        default_order :purchased_at, :desc

        table_column(:purchased_at, :type => :datetime, :column => 'orders.purchased_at') do |order_item|
          Time.at(order_item[:purchased_at]).in_time_zone if order_item[:purchased_at].present?
        end

        table_column :id, :visible => false

        table_column(:order, :type => :obfuscated_id, :sortable => false) do |order_item|
          obfuscated_id = Effective::Order.obfuscate(order_item[:order_id])
          link_to(obfuscated_id, (datatables_admin_path? ? effective_orders.admin_order_path(obfuscated_id) : effective_orders.order_path(obfuscated_id)))
        end

        table_column :email, column: 'users.email', label: 'Buyer Email', if: proc { attributes[:user_id].blank? } do |order_item|
          link_to order_item[:email], (edit_admin_user_path(order_item[:user_id]) rescue admin_user_path(order_item[:user_id]) rescue '#')
        end

        if EffectiveOrders.require_billing_address
          table_column :buyer_name, sortable: false, label: 'Buyer Name', if: proc { attributes[:user_id].blank? } do |order_item|
            (order_item[:buyer_name] || '').split('!!SEP!!').find(&:present?)
          end
        end

        table_column :purchase_state, column: 'orders.purchase_state', filter: { type: :select, values: [%w(abandoned abandoned), [EffectiveOrders::PURCHASED, EffectiveOrders::PURCHASED], [EffectiveOrders::DECLINED, EffectiveOrders::DECLINED]], selected: EffectiveOrders::PURCHASED } do |order_item|
          order_item[:purchase_state] || 'abandoned'
        end

        table_column :title do |order_item|
          order_item.quantity == 1 ? order_item.title : "#{order_item.title} (#{order_item.quantity} purchased)"
        end

        table_column(:subtotal) { |order_item| price_to_currency(order_item[:subtotal].to_i) }
        table_column(:tax) { |order_item| price_to_currency(order_item[:tax].to_i) }
        table_column(:total) { |order_item| price_to_currency(order_item[:total].to_i) }

        table_column :created_at, :visible => false
        table_column :updated_at, :visible => false

        def collection
          collection = Effective::OrderItem.unscoped
            .joins(:order => :user)
            .select('order_items.*, orders.*, users.email AS email')
            .select("#{query_subtotal} AS subtotal, #{query_tax} AS tax, #{query_total} AS total")
            .group('order_items.id, orders.id, users.email')

          if EffectiveOrders.require_billing_address && defined?(EffectiveAddresses)
            addresses_tbl = EffectiveAddresses.addresses_table_name

            collection = collection
              .joins("LEFT JOIN (SELECT addressable_id, string_agg(#{addresses_tbl}.full_name, '!!SEP!!') AS buyer_name FROM #{addresses_tbl} WHERE #{addresses_tbl}.category = 'billing' AND #{addresses_tbl}.addressable_type = 'Effective::Order' GROUP BY #{addresses_tbl}.addressable_id) #{addresses_tbl} ON orders.id = #{addresses_tbl}.addressable_id")
              .group("#{addresses_tbl}.buyer_name")
              .select("#{addresses_tbl}.buyer_name AS buyer_name")
          end

          attributes[:user_id].present? ? collection.where("#{EffectiveOrders.orders_table_name.to_s}.user_id = ?", attributes[:user_id]) : collection
        end

        def query_subtotal
          'SUM(price * quantity)'
        end

        def query_total
          'SUM((price * quantity) + (CASE tax_exempt WHEN true THEN 0 ELSE ((price * quantity) * tax_rate) END))'
        end

        def query_tax
          '(CASE tax_exempt WHEN true THEN 0 ELSE ((price * quantity) * tax_rate) END)'
        end

        def search_column(collection, table_column, search_term)
          if table_column[:name] == 'order'
            collection.where("#{EffectiveOrders.order_items_table_name.to_s}.order_id = ?", Effective::Order.deobfuscate(search_term))
          elsif table_column[:name] == 'purchase_state' && search_term == 'abandoned'
            collection.where("#{EffectiveOrders.orders_table_name.to_s}.purchase_state IS NULL")
          elsif table_column[:name] == 'subtotal'
            collection.having("#{query_subtotal} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
          elsif table_column[:name] == 'tax'
            collection.having("#{query_tax} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
          elsif table_column[:name] == 'total'
            collection.having("#{query_total} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
          else
            super
          end
        end

      end
    end
  end
end
