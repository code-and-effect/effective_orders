module Admin
  class OrderReportsController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_orders) }

    include Effective::CrudController

    def transactions
      @datatable = Admin::ReportTransactionsDatatable.new
      @page_title = @datatable.datatable_name

      authorize! :index, @datatable

      render 'index'
    end

    def transactions_grouped_by_name
      @datatable = Admin::ReportTransactionsGroupedByNameDatatable.new
      @page_title = @datatable.datatable_name

      authorize! :index, @datatable

      render 'index'
    end

    def transactions_grouped_by_qb_name
      @datatable = Admin::ReportTransactionsGroupedByQbNameDatatable.new
      @page_title = @datatable.datatable_name

      authorize! :index, @datatable

      render 'index'
    end

    # This is used by the transactions_grouped_by_name and transactions_grouped_by_qb_name datatables
    # To display a nested datatable of the orders
    def nested_orders
      ids = params[:ids].to_s.split("|")
      @datatable = Admin::EffectiveOrdersDatatable.new(ids: ids, skip_filters: true, skip_bulk_actions: true)
      nested_datatable_action
    end

    def payment_providers
      @datatable = Admin::ReportPaymentProvidersDatatable.new
      @page_title = @datatable.datatable_name

      authorize! :index, @datatable

      render 'index'
    end

  end
end
