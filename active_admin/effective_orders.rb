if defined?(ActiveAdmin)
  require 'csv'

  ActiveAdmin.register Effective::Order do
    menu :label => "Orders", :if => proc { EffectiveOrders.authorized?(controller, :manage, Effective::Order.new()) rescue false }

    actions :index, :show

    filter :id, :label => "Order Number"
    filter :user
    filter :created_at, :label => "Order Date"
    filter :payment

    scope :purchased, :default => true do |objs| objs.purchased end
    scope :declined do |objs| objs.declined end
    scope :all

    controller do
      include EffectiveOrdersHelper

      def show
        @effective_order = Effective::Order.find(Effective::Obfuscater.reveal(params[:id]))
        render 'show'
      end

      def scoped_collection
        end_of_association_chain.includes(:user).includes(:order_items => :purchasable)
      end
    end

    sidebar :export, :only => :index do
      link_to "Export Orders to .csv", export_csv_admin_effective_orders_path
    end

    index :download_links => false do
      column 'Order', :sortable => :id do |order| link_to "##{order.to_param}", admin_effective_order_path(order) end
      column 'Buyer', :sortable => :user_id do |order| link_to order.user, admin_user_path(order.user) end
      column 'Summary' do |order| order_summary(order) end
      column do |order|
        output = link_to('View', admin_effective_order_path(order), :class => 'member_link view_link')
        output += link_to('Resend Buyer Receipt', resend_receipt_admin_effective_order_path(order), :class => 'member_link') if order.purchased?
        output.html_safe
      end
    end

    show :title => proc { |order| "Order ##{order.to_param}"} do
      render :partial => 'active_admin/effective_orders/orders/show', :locals => {:order => effective_order}
    end

    action_item :only => :show do
      link_to('Resend Buyer Receipt', resend_receipt_admin_effective_order_path(effective_order))
    end

    member_action :resend_receipt do
      @order = Effective::Order.find(Effective::Obfuscater.reveal(params[:id]))

      if (Effective::OrdersMailer.order_receipt_to_buyer(@order).deliver rescue false)
        flash[:success] = "Successfully resent order receipt to #{@order.user.email}"
      else
        flash[:danger] = "Unable to send order receipt"
      end

      redirect_to admin_effective_orders_path
    end

    collection_action :export_csv do
      @orders = Effective::Order.purchased

      col_headers = []
      col_headers << "Order ID"
      col_headers << "Full Name"
      col_headers << "Purchased"
      col_headers << "Subtotal"
      col_headers << "Tax"
      col_headers << "Total"

      csv_string = CSV.generate do |csv|
        csv << col_headers

        @orders.each do |order|
          row = []

          row << order.to_param
          row << (order.billing_address.try(:full_name) || order.user.to_s)
          row << order.purchased_at.strftime("%Y-%m-%d %H:%M:%S %z")
          row << "%.2f" % order.subtotal
          row << "%.2f" % order.tax
          row << "%.2f" % order.total

          csv << row
        end
      end

      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => "orders-export.csv")
    end
  end
end
