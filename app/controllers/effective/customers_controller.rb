module Effective
  class CustomersController < ApplicationController
    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:customers] : EffectiveOrders.layout)

    include Effective::CrudController

    submit :save, 'Save', success: -> { 'Successfully updated card.' }
    page_title 'Customer Settings'

    def resource
      @customer = Effective::Customer.where(user: current_user).first!
      @subscripter ||= Effective::Subscripter.new(customer: @customer, current_user: current_user)
    end

    # StrongParameters
    def customer_params
      params.require(:effective_subscripter).permit(:stripe_token)
    end
  end
end
