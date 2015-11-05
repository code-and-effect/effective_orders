$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "effective_orders/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "effective_orders"
  s.version     = EffectiveOrders::VERSION
  s.authors     = ["Code and Effect"]
  s.email       = ["info@codeandeffect.com"]
  s.homepage    = "https://github.com/code-and-effect/effective_orders"
  s.summary     = "Quickly build an online store with carts, orders, automatic email receipts and payment collection via Stripe, StripeConnect, PayPal and Moneris."
  s.description = "Quickly build an online store with carts, orders, automatic email receipts and payment collection via Stripe, StripeConnect, PayPal and Moneris."
  s.licenses    = ['MIT']

  s.files = Dir["{app,config,db,lib,active_admin}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", [">= 3.2.0"]
  s.add_dependency "coffee-rails"
  s.add_dependency "devise"
  s.add_dependency "haml-rails"
  s.add_dependency "sass-rails"
  s.add_dependency "migrant"
  s.add_dependency "simple_form"
  s.add_dependency "effective_addresses", [">= 1.3.6"]
  s.add_dependency "effective_obfuscation", [">= 1.0.2"]
  s.add_dependency "stripe", [">= 1.19.0"]

  s.add_development_dependency "stripe-ruby-mock", [">= 2.0.4"]
  s.add_development_dependency "factory_girl_rails"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "shoulda-matchers"
  s.add_development_dependency "sqlite3"

  s.add_development_dependency "guard"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "guard-livereload"

  s.add_development_dependency "pry"
  s.add_development_dependency "pry-stack_explorer"
  s.add_development_dependency "pry-byebug"

end
