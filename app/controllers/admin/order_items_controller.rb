module Admin
  class OrderItemsController < ApplicationController
    before_action :authenticate_user!

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_orders] : EffectiveOrders.layout)

    def index
      @datatable = Admin::EffectiveOrderItemsDatatable.new(self)

      @page_title = 'Order Items'

      EffectiveOrders.authorize!(self, :admin, :effective_orders)
      EffectiveOrders.authorize!(self, :index, Effective::OrderItem)
    end
  end
end
