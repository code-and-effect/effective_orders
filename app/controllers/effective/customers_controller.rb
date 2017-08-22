module Effective
  class CustomersController < ApplicationController

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:customers] : EffectiveOrders.layout)

    before_action :authenticate_user!

    def edit
      @page_title ||= "Customer #{current_user.to_s}"
      @customer = Effective::Customer.where(user: current_user).first!
      EffectiveOrders.authorized?(self, :edit, @customer)
    end

    private

    # StrongParameters
    def customer_params
      params.require(:effective_customer).permit(:id)
    end

  end
end
