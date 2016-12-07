module Admin
  class CustomersController < ApplicationController
    respond_to?(:before_action) ? before_action(:authenticate_user!) : before_filter(:authenticate_user!) # Devise

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_customers] : EffectiveOrders.layout)

    def index
      @datatable = Effective::Datatables::Customers.new()
      @page_title = 'Customers'

      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, :index, Effective::Customer)
    end

  end
end
