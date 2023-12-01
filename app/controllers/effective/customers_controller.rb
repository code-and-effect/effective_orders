module Effective
  class CustomersController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)

    include Effective::CrudController

    if (config = EffectiveOrders.layout)
      layout(config.kind_of?(Hash) ? (config[:customers] || config[:application]) : config)
    end

    submit :save, 'Save', success: -> { 'Successfully updated card.' }
    page_title 'Customer Settings'

    def resource
      @customer = Effective::Customer.deep.where(user: current_user).first!
      @subscripter ||= Effective::Subscripter.new(customer: @customer, current_user: current_user)
    end

    # StrongParameters
    def customer_params
      params.require(:effective_subscripter).permit(:stripe_token)
    end
  end
end
