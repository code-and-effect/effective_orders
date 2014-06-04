module Admin
  class CustomersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_customers] : EffectiveOrders.layout)
    
    def index
      @datatable = Effective::Datatables::Customers.new() if defined?(EffectiveDatatables)
      @page_title = 'Customers'

      EffectiveOrders.authorized?(self, :index, Effective::Customer)
    end

  end
end
