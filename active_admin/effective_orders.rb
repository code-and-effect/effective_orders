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
      column 'Order', :sortable => :id do |order|
        link_to "##{order.to_param}", effective_orders.order_path(order)
      end

      column 'Buyer', :sortable => :user_id do |order|
        user_path = [EffectiveOrders.active_admin_namespace.presence, 'user_path'].compact.join('_')
        link_to order.user, (public_send(user_path, order.user) rescue '#')
      end

      column 'Summary' do |order|
        order_summary(order)
      end

      column :purchased_at
      column :purchase_method

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
