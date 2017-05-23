unless Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
  class EffectiveOrderItemsDatatable < Effective::Datatable
    datatable do
      order :purchased_at, :desc

      col(:purchased_at, sql_column: 'orders.purchased_at') do |order_item|
        Time.at(order_item[:purchased_at]).in_time_zone if order_item[:purchased_at].present?
      end

      col :id, visible: false

      col :order

      # if effectiveorders.obfuscate_order_ids
      #   col(:order, type: :obfuscated_id) do |order_item|
      #     obfuscated_id = effective::order.obfuscate(order_item[:order_id])
      #     link_to(obfuscated_id, (datatables_admin_path? ? effective_orders.admin_order_path(obfuscated_id) : effective_orders.order_path(obfuscated_id)))
      #   end
      # else
      #   col(:order) do |order_item|
      #     link_to(order_item.to_param, (datatables_admin_path? ? effective_orders.admin_order_path(order_item.to_param) : effective_orders.order_path(order_item.to_param)))
      #   end
      # end

      unless attributes[:user_id]
        col :email, sql_column: 'users.email', label: 'Buyer Email' do |order_item|
          link_to order_item[:email], (edit_admin_user_path(order_item[:user_id]) rescue admin_user_path(order_item[:user_id]) rescue '#')
        end
      end

      if EffectiveOrders.require_billing_address && attributes[:user_id].blank?
        col :buyer_name, sort: false, label: 'Buyer Name' do |order_item|
          (order_item[:buyer_name] || '').split('!!SEP!!').find(&:present?)
        end
      end

      col :purchase_state, sql_column: 'orders.purchase_state', search: { collection: [%w(abandoned abandoned), [EffectiveOrders::PURCHASED, EffectiveOrders::PURCHASED], [EffectiveOrders::DECLINED, EffectiveOrders::DECLINED]], selected: EffectiveOrders::PURCHASED } do |order_item|
        order_item[:purchase_state] || 'abandoned'
      end

      col :title do |order_item|
        order_item.quantity == 1 ? order_item.title : "#{order_item.title} (#{order_item.quantity} purchased)"
      end

      # col :subtotal, as: :price
      # col :tax, as: :price
      # col :total, as: :price

      col :created_at, visible: false
      col :updated_at, visible: false
    end

    collection do
      collection = Effective::OrderItem.unscoped
        .joins(order: :user)
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

    # def search_column(collection, table_column, search_term)
    #   if table_column[:name] == 'order'
    #     collection.where("#{EffectiveOrders.order_items_table_name.to_s}.order_id = ?", Effective::Order.deobfuscate(search_term))
    #   elsif table_column[:name] == 'purchase_state' && search_term == 'abandoned'
    #     collection.where("#{EffectiveOrders.orders_table_name.to_s}.purchase_state IS NULL")
    #   elsif table_column[:name] == 'subtotal'
    #     collection.having("#{query_subtotal} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
    #   elsif table_column[:name] == 'tax'
    #     collection.having("#{query_tax} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
    #   elsif table_column[:name] == 'total'
    #     collection.having("#{query_total} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
    #   else
    #     super
    #   end
    # end

  end
end
