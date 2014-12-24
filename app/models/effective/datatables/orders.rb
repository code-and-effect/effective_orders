if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class Orders < Effective::Datatable
        default_order :purchased_at, :desc

        table_column :id do |order|
          order.to_param
        end

        table_column :email, :column => 'users.email', :label => 'Buyer', :if => Proc.new { attributes[:user_id].blank? } do |order|
          link_to order[:email], (edit_admin_user_path(order.user_id) rescue admin_user_path(order.user_id) rescue '#')
        end

        table_column :order_items, :sortable => false, :column => 'order_items.title' do |order|
          content_tag(:ul) do
            order[:order_items].split('!!OI!!').map { |oi| content_tag(:li, oi) }.join().html_safe
          end
        end

        table_column :purchased_at

        table_column :total do |order|
          price_to_currency(order[:total].to_i)
        end

        table_column :actions, :sortable => false, :filter => false do |order|
          content_tag(:span, :style => 'white-space: nowrap;') do
            [
              link_to('View', (datatables_admin_path? ? effective_orders.admin_order_path(order) : effective_orders.order_path(order))),
              (link_to('Resend Receipt', effective_orders.resend_buyer_receipt_path(order), {'data-confirm' => 'This action will resend a copy of the original email receipt.  Send receipt now?'}) if order.try(:purchased?))
            ].compact.join(' - ').html_safe
          end
        end

        def collection
          collection = Effective::Order.unscoped.purchased
            .joins(:user)
            .joins(:order_items)
            .group('users.email')
            .group('orders.id')
            .select('users.email AS email')
            .select('orders.*')
            .select("#{query_total} AS total")
            .select("string_agg(order_items.title, '!!OI!!') AS order_items")

          if attributes[:user_id].present?
            collection.where(:user_id => attributes[:user_id])
          else
            collection
          end

        end

        def query_total
          "SUM((order_items.price * order_items.quantity) + (CASE order_items.tax_exempt WHEN true THEN 0 ELSE ((order_items.price * order_items.quantity) * order_items.tax_rate) END))"
        end

        def search_column(collection, table_column, search_term)
          if table_column[:name] == 'total'
            collection.having("#{query_total} = ?", (search_term.gsub(/[^0-9.]/, '').to_f * 100.0).to_i)
          else
            super
          end
        end

      end
    end
  end
end
