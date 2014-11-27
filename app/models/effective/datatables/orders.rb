if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class Orders < Effective::Datatable
        table_column :id do |order|
          order.to_param
        end

        array_column :email, :label => 'Buyer', :if => Proc.new { attributes[:user_id].blank? } do |order|
          link_to order.user.email, (edit_admin_user_path(order.user) rescue admin_user_path(order.user) rescue '#')
        end

        array_column :order_items do |order|
          content_tag(:ul) do
            order.order_items.map { |oi| content_tag(:li, oi.title) }.join().html_safe
          end
        end

        table_column :purchased_at

        array_column :total do |order|
          price_to_currency(order.total)
        end

        table_column :actions, :sortable => false, :filter => false do |order|
          content_tag(:span, :style => 'white-space: nowrap;') do
            [
              link_to('View', (datatables_admin_path? ? effective_orders.admin_order_path(order) : effective_orders.order_path(order))),
              (link_to('Resend Receipt', effective_orders.resend_buyer_receipt_path(order), {'data-confirm' => 'This action will email the buyer a copy of the original email receipt.  Send receipt now?'}) if order.try(:purchased?))
            ].compact.join(' - ').html_safe
          end
        end

        def collection
          if attributes[:user_id].present?
            Effective::Order.purchased.where(:user_id => attributes[:user_id]).includes(:user).includes(:order_items)
          else
            Effective::Order.purchased.includes(:user).includes(:order_items)
          end
        end

        def search_column(collection, table_column, search_term)
          if table_column[:name] == 'id'
            collection.where(:id => search_term)
          else
            super
          end
        end

      end
    end
  end
end
