if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class Orders < Effective::Datatable
        table_column :id do |order|
          order.to_param
        end

        table_column :email, :label => 'Buyer', :column => 'users.email' do |order|
          link_to order.email, (edit_admin_user_path(order.user_id) rescue admin_user_path(order.user_id) rescue '#')
        end

        table_column :purchased_at

        table_column :order_items, :sortable => false, :column => 'order_items.title' do |order|
          content_tag(:ul) do
            (order[:order_items] || '').split('!!ITEM!!').map { |title| content_tag(:li, title.html_safe) }.join().html_safe
          end
        end

        table_column :total, :filter => false do |order|
          number_to_currency(order[:total])
        end

        table_column :actions, :sortable => false, :filter => false, :partial => '/admin/orders/actions'

        def collection
          Effective::Order.unscoped.purchased.uniq
            .joins(:user)
            .joins(:order_items)
            .select("to_char(SUM((order_items.price * order_items.quantity) + (CASE order_items.tax_exempt WHEN true THEN 0 ELSE ((order_items.price * order_items.quantity) * order_items.tax_rate) END)), '9999999D99') AS total")
            .select('orders.*')
            .select("string_agg(order_items.title, '!!ITEM!!') AS order_items")
            .select('users.email AS email')
            .group('orders.id')
            .group('users.email')
        end

        def search_column(collection, table_column, search_term)
          if table_column[:name] == 'id'
            collection.where(:id => Effective::Obfuscater.reveal(search_term))
          else
            super
          end
        end

      end
    end
  end
end

# WORKING GOOOD
            #.select("to_char(SUM((order_items.price * order_items.quantity) + (CASE order_items.tax_exempt WHEN true THEN 0 ELSE ((order_items.price * order_items.quantity) * order_items.tax_rate) END)), '9999999D99') AS total")
