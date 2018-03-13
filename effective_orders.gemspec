$:.push File.expand_path('../lib', __FILE__)

require 'effective_orders/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'effective_orders'
  s.version     = EffectiveOrders::VERSION
  s.authors     = ['Code and Effect']
  s.email       = ['info@codeandeffect.com']
  s.homepage    = 'https://github.com/code-and-effect/effective_orders'
  s.summary     = 'Quickly build an online store with carts, orders, automatic email receipts and payment collection via Stripe, StripeConnect, PayPal and Moneris.'
  s.description = 'Quickly build an online store with carts, orders, automatic email receipts and payment collection via Stripe, StripeConnect, PayPal and Moneris.'
  s.licenses    = ['MIT']

  s.files = Dir['{app,config,db,lib}/**/*'] + ['MIT-LICENSE', 'README.md']

  s.add_dependency 'rails', '>= 4.0.0'
  s.add_dependency 'coffee-rails'
  s.add_dependency 'devise'
  s.add_dependency 'sass-rails'
  s.add_dependency 'effective_datatables', '>= 4.0.0'
  s.add_dependency 'effective_resources'
end
