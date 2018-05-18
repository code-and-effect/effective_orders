module Effective
  class CustomersController < ApplicationController
    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:customers] : EffectiveOrders.layout)

    include Effective::CrudController

    submit :save, 'Save', redirect: :back, success: -> { 'Successfully updated card.' }
    page_title 'Customer Settings'

    def resource
      @customer ||= Effective::Customer.where(user: current_user).first!
      @subscripter ||= Effective::Subscripter.new(customer: @customer, user: @customer.user)
    end

    # I don't want save_resource to wrap my save in a transaction
    def save_resource(resource, action, to_assign)
      resource.assign_attributes(to_assign)
      resource.save!
    end

    # StrongParameters
    def customer_params
      params.require(:effective_subscripter).permit(:stripe_token)
    end
  end
end
