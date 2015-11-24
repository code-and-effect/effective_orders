if defined?(ActiveAdmin)
  require 'csv'

  ActiveAdmin.register Effective::Order, namespace: EffectiveOrders.active_admin_namespace, as: 'Orders' do
    menu label: 'Orders', if: proc { (authorized?(:manage, Effective::Order.new(user: current_user)) rescue false) }

    actions :index

    filter :id, label: 'Order Number'
    filter :user
    filter :created_at, label: 'Order Date'
    filter :payment

    scope :purchased, default: true do |objs| objs.purchased end
    scope :all

    controller do
      include EffectiveOrdersHelper

      def scoped_collection
        end_of_association_chain.includes(:user).includes(order_items: :purchasable)
      end
    end

    sidebar :export, :only => :index do
      export_csv_path = ['export_csv', EffectiveOrders.active_admin_namespace.presence, 'orders_path'].compact.join('_')
      link_to "Export Orders to .csv", public_send(export_csv_path)
    end

    index :download_links => false do
      column :purchased_at

      column 'Order', :sortable => :id do |order|
        link_to "##{order.to_param}", effective_orders.order_path(order)
      end

      column 'Buyer Email' do |order|
        mail_to order.user.email
      end

      column 'Buyer Name', :sortable => :user_id do |order|
        user_path = [EffectiveOrders.active_admin_namespace.presence, 'user_path'].compact.join('_')
        link_to order.user, (public_send(user_path, order.user) rescue '#')
      end

      column 'Order Items' do |order|
        content_tag(:ul) do
          (order.order_items).map { |oi| content_tag(:li, oi) }.join.html_safe
        end
      end

      column 'Total' do |order|
        price_to_currency(order.total)
      end

      column :payment_method do |order|
        order.payment_method
      end

      column :payment_card_type do |order|
        order.payment_card_type
      end

      column do |order|
        link_to('View Receipt', effective_orders.order_path(order), class: 'member_link view_link') if order.purchased?
      end

    end

    collection_action :export_csv do
      @orders = Effective::Order.purchased.includes(:addresses)

      col_headers = []
      col_headers << "Order"
      col_headers << "Purchased at"
      col_headers << "Email"
      col_headers << "Full Name"
      col_headers << "Subtotal"
      col_headers << "Tax"
      col_headers << "Total"
      col_headers << 'Purchase method'

      csv_string = CSV.generate do |csv|
        csv << col_headers

        @orders.each do |order|
          csv << [
            order.to_param,
            order.purchased_at.strftime("%Y-%m-%d %H:%M:%S %z"),
            order.user.try(:email),
            (order.billing_address.try(:full_name) || order.user.to_s),
            (order.subtotal / 100.0).round(2),
            (order.tax / 100.0).round(2),
            (order.total / 100.0).round(2),
            order.purchase_method
          ]
        end
      end

      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => "orders-export.csv")
    end
  end
end
