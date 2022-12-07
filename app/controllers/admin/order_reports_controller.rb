module Admin
  class OrderReportsController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_orders) }

    include Effective::CrudController

    def transactions
      @page_title = 'Revenue: Individual Transactions'
      @datatable = Admin::ReportTransactionsDatatable.new

      authorize! :index, :report_transactions

      render 'index'
    end

    def grouped_transactions
      @page_title = 'Revenue: Grouped Transactions'
      @datatable = Admin::ReportGroupedTransactionsDatatable.new

      authorize! :index, :report_grouped_transactions

      render 'index'
    end

    def payment_methods
      @page_title = 'Revenue: Payment Methods'
      @datatable = Admin::ReportPaymentMethodsDatatable.new

      authorize! :index, :report_payment_methods

      render 'index'
    end

  end
end
