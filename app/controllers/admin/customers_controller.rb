module Admin
  class CustomersController < ApplicationController
    before_action :authenticate_user!

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:admin_customers] : EffectiveOrders.layout)

    def index
      if Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
        @datatable = Effective::Datatables::Customers.new()
      else
        @datatable = EffectiveCustomersDatatable.new(self)
      end

      @page_title = 'Customers'

      EffectiveOrders.authorized?(self, :admin, :effective_orders)
      EffectiveOrders.authorized?(self, :index, Effective::Customer)
    end

  end
end
