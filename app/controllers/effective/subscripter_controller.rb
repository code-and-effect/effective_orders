module Effective
  class SubscripterController < ApplicationController
    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:subscriptions] : EffectiveOrders.layout)

    include Effective::CrudController

    submit :save, 'Save', redirect: :back, success: -> { 'Successfully updated plan.' }

    def resource
      @subscripter ||= Effective::Subscripter.new(user: current_user)
    end

    # I don't want save_resource to wrap my save in a transaction
    def save_resource(resource, action, to_assign)
      resource.assign_attributes(to_assign)
      resource.save!
    end

    # StrongParameters
    def subscripter_params
      params.require(:effective_subscripter).permit!
    end
  end
end
