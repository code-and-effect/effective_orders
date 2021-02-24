module Effective
  class SubscripterController < ApplicationController
    include Effective::CrudController

    if (config = EffectiveOrders.layout)
      layout(config.kind_of?(Hash) ? (config[:subscriptions] || config[:application]) : config)
    end

    submit :save, 'Save', redirect: :back, success: -> { 'Successfully updated plan.' }

    def resource
      @subscripter ||= Effective::Subscripter.new(current_user: current_user)
    end

    # StrongParameters
    def subscripter_params
      params.require(:effective_subscripter).permit!
    end
  end
end
