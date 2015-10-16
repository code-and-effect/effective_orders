module Effective
  module ActiveAdminHelpers
    module Carts
      extend ActiveSupport::Concern

      included do
        include ::ActiveAdmin::BaseController::Menu
        include ::ActiveAdmin::BaseController::Authorization

        helper ::ActiveAdmin::ViewHelpers
        helper_method :active_admin_config, :active_admin_namespace, :current_active_admin_user
        helper_method :resource, :resource_path
      end

      module ClassMethods
      end

      def resource
        instance_variable_get(@cart)
      end

      def resource_path(resource)
        effective_orders.cart_path
      end

      def active_admin_namespace
        ::ActiveAdmin.application.namespaces[EffectiveOrders.active_admin_namespace || :root]
      end

      def active_admin_config
        active_admin_namespace.resources[active_admin_resource_key]
      end

      def active_admin_resource_key
        @active_admin_resource_key ||= begin
          namespace = ::ActiveAdmin.application.namespaces[EffectiveOrders.active_admin_namespace || :root]
          namespace.resources.keys.find { |resource| resource.element == 'carts' }
        end
      end

      def current_active_admin_user
        send(active_admin_namespace.current_user_method) if active_admin_namespace.current_user_method
      end

    end
  end
end
