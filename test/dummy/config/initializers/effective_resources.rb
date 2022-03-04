EffectiveResources.setup do |config|
  config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }

  # Mailer Settings
  config.mailer_sender = '"Info" <info@example.com>'
  config.mailer_admin = '"Admin" <admin@example.com>'
end
