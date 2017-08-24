module Effective
  class CustomersController < ApplicationController

    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:customers] : EffectiveOrders.layout)

    before_action :authenticate_user!

    def edit
      @page_title ||= "Customer #{current_user.to_s}"
      @customer = Effective::Customer.where(user: current_user).first!
      EffectiveOrders.authorized?(self, :edit, @customer)
    end

    def update
      @page_title ||= "Customer #{current_user.to_s}"

      @customer = Effective::Customer.find(params[:id])
      EffectiveOrders.authorized?(self, :edit, @customer)

      if (@customer.update_card!(customer_params[:stripe_token]) rescue false)
        flash[:success] = "Successfully updated customer"
        redirect_to(effective_orders.edit_customer_path(@customer))
      else
        flash.now[:danger] = "Unable to update customer: #{@customer.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    private

    # StrongParameters
    def customer_params
      params.require(:effective_customer).permit(:stripe_token)
    end

  end
end
