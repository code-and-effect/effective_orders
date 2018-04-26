module Effective
  class SubscripterController < ApplicationController
    layout (EffectiveOrders.layout.kind_of?(Hash) ? EffectiveOrders.layout[:subscriptions] : EffectiveOrders.layout)

    include Effective::CrudController

    def resource
      @subscripter ||= Effective::Subscripter.new(user: current_user)
    end

    # StrongParameters
    def subscripter_params
      params.require(:effective_subscripter).permit!
    end
  end
end
