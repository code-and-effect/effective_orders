module Admin
  class ItemNamesController < ApplicationController
    before_action(:authenticate_user!) if defined?(Devise)
    before_action { EffectiveResources.authorize!(self, :admin, :effective_orders) }

    include Effective::CrudController

    if (config = EffectiveOrders.layout)
      layout(config.kind_of?(Hash) ? config[:admin] : config)
    end

  end
end
