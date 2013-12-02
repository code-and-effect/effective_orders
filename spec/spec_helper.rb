ENV["RAILS_ENV"] ||= 'test'

require File.expand_path("../dummy/config/environment", __FILE__)

require 'rspec/rails'
require 'factory_girl_rails'

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  Rails.logger.level = 4    # Output only minimal stuff to test.log

  config.use_transactional_fixtures = true   # Make this false to once again use DatabaseCleaner
  config.order = 'random'
end

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || retrieve_connection
  end
end

# Forces all threads to share the same connection. This works on
# Capybara because it starts the web server in a thread.
ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection


# To set up this gem for testing:
# spec/dummy> ln -s ../../spec spec
#
# spec/dummy> rails generate effective_orders:install
# spec/dummy> rake db:migrate
# spec/dummy> rake db:test:prepare
