EffectiveEmailTemplates.setup do |config|
  # Configure Database Tables
  config.email_templates_table_name = :email_templates

  # Layout Settings
  # config.layout = { application: 'application', admin: 'admin' }

  # Not allowed to select text/html by default
  config.select_content_type = false
end
