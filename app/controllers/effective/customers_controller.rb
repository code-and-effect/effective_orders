module Effective
  class CustomersController < ApplicationController
    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:customers] : EffectiveOrders.layout)

    before_action :authenticate_user!

    # Get here by visiting /customer/settings
    def edit
      @customer = Effective::Customer.where(user: current_user).first!
      EffectiveOrders.authorized?(self, :edit, @customer)

      @subscripter = Effective::Subscripter.new(customer: @customer, user: @customer.user)

      @page_title ||= "Customer #{current_user.to_s}"
    end

    def update
      @customer = Effective::Customer.where(user: current_user).first!
      EffectiveOrders.authorized?(self, :edit, @customer)

      @subscripter = Effective::Subscripter.new(customer: @customer, user: @customer.user)
      @subscripter.assign_attributes(subscripter_params)

      @page_title ||= "Customer #{current_user.to_s}"

      if (@subscripter.save! rescue false)
        flash[:success] = "Successfully updated customer settings"
        redirect_to(effective_orders.customer_settings_path)
      else
        flash.now[:danger] = "Unable to update customer settings: #{@subscripter.errors.full_messages.to_sentence}"
        render :edit
      end
    end

    private

    # StrongParameters
    def subscripter_params
      params.require(:effective_subscripter).permit(:stripe_token)
    end

  end
end
