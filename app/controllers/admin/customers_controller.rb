module Admin
  class CustomersController < ApplicationController
    before_filter :authenticate_user!   # This is devise, ensure we're logged in.
    layout 'admin' if -> { view_context.template_exists?('admin') }
    
    def index
      @datatable = ::Effective::Datatables::Customers.new()
      @page_title = 'Customers'

      authorize! :index, Effective::Customer
    end

  end
end
