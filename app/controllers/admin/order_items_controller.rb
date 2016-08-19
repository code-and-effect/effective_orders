module Admin
  class OrderItemsController < ApplicationController
    respond_to?(:before_action) ? before_action(:authenticate_user!) : before_filter(:authenticate_user!) # Devise

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::OrderItems.new() if defined?(EffectiveDatatables)
      @page_title = 'Order Items'

      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, :index, Effective::OrderItem)
    end
  end
end
