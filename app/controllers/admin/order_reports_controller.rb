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

    def transactions_grouped_by_name
      @page_title = 'Revenue: Transactions Grouped By Name'
      @datatable = Admin::ReportTransactionsGroupedByNameDatatable.new

      authorize! :index, :report_transactions_grouped_by_name

      render 'index'
    end

    def transactions_grouped_by_qb_name
      @page_title = 'Revenue: Transactions Grouped By Quickbooks Name'
      @datatable = Admin::ReportTransactionsGroupedByQbNameDatatable.new

      authorize! :index, :report_transactions_grouped_by_qb_name

      render 'index'
    end

    def payment_providers
      @page_title = 'Revenue: Payment Providers'
      @datatable = Admin::ReportPaymentProvidersDatatable.new

      authorize! :index, :report_payment_providers

      render 'index'
    end

  end
end
