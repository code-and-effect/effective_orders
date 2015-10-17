module ActsAsActiveAdminController
  extend ActiveSupport::Concern

  module ActionController
    def acts_as_active_admin_controller(element_lookup_key)
      @active_admin_resource_element_lookup_key = element_lookup_key
      include ::ActsAsActiveAdminController
    end
  end

  included do
    include ActiveAdmin::BaseController::Menu
    include ActiveAdmin::BaseController::Authorization

    helper ActiveAdmin::ViewHelpers
    helper_method :active_admin_config, :active_admin_namespace, :current_active_admin_user

    resource_key = @active_admin_resource_element_lookup_key.to_s
    self.send(:define_method, :active_admin_resource_element_key) { resource_key }

    resource_ivar = '@' + resource_key.singularize
    self.send(:define_method, :resource) { instance_variable_get(resource_ivar) }

    resource_path = "effective_orders.#{resource_key.singularize}_path"

    if resource_path == 'effective_orders.cart_path'
      self.send(:define_method, :resource_path) { |resource| effective_orders.cart_path }
    else
      self.send(:define_method, :resource_path) { |resource| public_send(resource_path, resource) }
    end

    helper_method :resource, :resource_path
  end

  module ClassMethods
  end

  def active_admin_namespace
    ActiveAdmin.application.namespaces[EffectiveOrders.active_admin_namespace || :root]
  end

  def active_admin_config
    active_admin_namespace.resources[active_admin_resource_key]
  end

  def active_admin_resource_key
    @active_admin_resource_key ||= begin
      namespace = ActiveAdmin.application.namespaces[EffectiveOrders.active_admin_namespace || :root]
      namespace.resources.keys.find { |resource| resource.element == active_admin_resource_element_key }
    end
  end

  def current_active_admin_user
    send(active_admin_namespace.current_user_method) if active_admin_namespace.current_user_method
  end

end

