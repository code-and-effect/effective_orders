# Effective Orders

A full solution for payments in a Rails3 application.

Handles Carts, Orders, and taking payment through Moneris, PayPal and Stripe.

## Getting Started

Add to your Gemfile:

```ruby
gem 'effective_orders'
```

Run the bundle command to install it:

```console
bundle install
```

Then run the generator:

```ruby
rails generate effective_orders:install
```

The generator will install an initializer which describes all configuration options and creates a database migration.

If you want to tweak the table name (to use something other than the default 'orders', 'order_items', 'carts', 'cart_items', 'customers'), manually adjust both the configuration file and the migration now.

Then migrate the database:

```ruby
rake db:migrate
```

### Carts

TODO

### Orders

TODO

### Helpers

TODO

### Using Ngrok to test in Development

Used to use localtunnel, but it looks like its down.  Try ngrok instead.

https://ngrok.com/

### Moneris

TODO

### PayPal

TODO

### Stripe

First register for an account with Stripe

https://manage.stripe.com/register

and configure your bank accounts appropriately.

Then enable Stripe in the app/config/effective_orders.rb initializer and enter your keys.

```ruby
config.stripe_enabled = true

config.stripe = {
  :secret_key => 'sk_live_IKd6HDaYUfoRjflWQTXfFNfc',
  :publishable_key => 'pk_live_liEGn9f0mcxKmoSjoeNbbuE1',
  :currency => 'usd'
}
```

You an find these keys from the Stripe Dashbaord -> Your Account (dropdown) -> Account Settings -> API Keys

You're ready to accept payments.

### Stripe Connect

Stripe Connect allows effective_orders to collect payments on behalf of users.

First register your application with Stripe

Stripe Dashbaord -> Your Account (dropdown) -> Account Settings -> Apps

Register your application

Name: Your Application Name
Website URL:  root_url

Development:

client_id: given by stripe, we need to record this.
redirect_uri: stripe_connect_redirect_uri_url  # http://www.example.com/effective/orders/stripe_connect_redirect_uri
webhook_uri:

And add these values to the app/config/effective_orders.rb initializer:

```ruby
config.stripe = {
  :secret_key => 'sk_live_IKd6HDaYUfoRjflWQTXfFNfc',
  :publishable_key => 'pk_live_liEGn9f0mcxKmoSjoeNbbuE1',
  :currency => 'usd',
  :connect_client_id => 'ca_35jLok5G9kosyYF7quTOwcauJjTnUnud'
}
```



## License

MIT License.  Copyright Code and Effect Inc. http://www.codeandeffect.com

You are not granted rights or licenses to the trademarks of Code and Effect

### Testing

The test suite for this gem is unfortunately not yet complete.

Run tests by:

```ruby
rake spec
```
