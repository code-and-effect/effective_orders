EffectiveResources.setup do |config|
  # Authorization Method
  #
  # This method is called by all controller actions with the appropriate action and resource
  # If it raises an exception or returns false, an Effective::AccessDenied Error will be raised
  #
  # Use via Proc:
  # Proc.new { |controller, action, resource| authorize!(action, resource) }       # CanCan
  # Proc.new { |controller, action, resource| can?(action, resource) }             # CanCan with skip_authorization_check
  # Proc.new { |controller, action, resource| authorize "#{action}?", resource }   # Pundit
  # Proc.new { |controller, action, resource| current_user.is?(:admin) }           # Custom logic
  #
  # Use via Boolean:
  # config.authorization_method = true  # Always authorized
  # config.authorization_method = false # Always unauthorized
  #
  # Use via Method (probably in your application_controller.rb):
  # config.authorization_method = :my_authorization_method
  # def my_authorization_method(resource, action)
  #   true
  # end
  config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }

  # These default submit actions will be added to each controller
  # and rendered when calling effective_submit(f)
  # based on the controller, and its `submits` if any.
  #
  # Supported values: 'Save', 'Continue', and 'Add New'
  config.default_submits = ['Save', 'Continue', 'Add New']
end
