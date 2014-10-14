# Effective Orders

A full solution for payments in a Rails3/4 application.

Handles Carts, Orders, and taking payment through Moneris, PayPal and Stripe.

Also works with Stripe Connect (for a digital marketplace type app) and Stripe Subscriptions

Rails 3.2.x and Rails 4

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

### Integrating with your app

Once installed, we still need to create something to purchase.

Let's make a 'Product' model that uses the acts_as_purchasable mixin.

We're also going to prevent the Product from being deleted by overriding destroy and setting a boolean archived=true instead.

If someone purchased a Product which is later deleted, the Order History page will be unable to find the Product.

```ruby
class Product < ActiveRecord::Base
  acts_as_purchasable

  # this structure do... block is provided by the migrant gem https://github.com/pascalh1011/migrant
  structure do
    title               :string

    price               :decimal, :precision => 8, :scale => 2, :default => 0.00

    archived            :boolean, :default => false

    timestamps
  end

  validates_presence_of :title
  validates_numericality_of :price, :greater_than => 0.0

  scope :products, -> { where(:archived => false) }

  # This prevents the Product from being deleted
  def destroy
    update_attributes(:archived => true)
  end

end
```

The database migration will look like the following:

```ruby
class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string :title
      t.decimal :price, :default=>0.0, :precision=>8, :scale=>2
      t.boolean :archived, :default=>false
      t.datetime :updated_at
      t.datetime :created_at
    end
  end

  def self.down
    drop_table :products
  end
end
```

Once the database has been migrated, it is time to scaffold/build the CRUD Product screens and create some Products to sell.

...that is an exercise left upto the reader...

So then back on a Product#show page, we will render the product with the Add To Cart link

```haml
%h4= @product.title
%p= number_to_currency(@product.price)
%p= link_to_add_to_cart(@product, :class => 'btn btn-primary', :label => 'Add To My Shopping Cart')
```

When the user clicks 'Add To My Shopping Cart' the product will be added to the cart.  A flash message is displayed, and the user will return to the same page.

We still need to create a link to the Shopping Cart page so that the user can see his cart.  On your site's menu, or wherever:

```ruby
= link_to 'My Cart', effective_orders.carts_path
```

or

```ruby
= link_to_current_cart()  # To display Cart (3) when there are 3 items
```

or

```ruby
= link_to_current_cart(:label => 'My Shopping Cart')  # To display My Shopping Cart Cart (3) when there are 3 items
```

The checkout screen can be reached through the My Cart page, or reached directly via

```ruby
= link_to 'Go Checkout Already', effective_orders.new_order_path
```

or

```ruby
= link_to_checkout()
```


## Permissions

Using CanCan

```ruby
can [:manage], Effective::Cart, :user_id => user.id
can [:manage], Effective::Order, :user_id => user.id # Orders cannot be deleted
can [:manage], Effective::Subscription, :user_id => user.id
```


## Acts As Purchasable

TODO

You can define two callback

```ruby
class Product
  acts_as_purchasable

  after_purchase do |order, order_item|   # These are optional, if you don't care about the order or order_item
    self.do_something() # self is an instance of this Product
  end

  after_decline do |order, order_item|
  end
end
```


## Carts

TODO

## Orders

TODO

## Helpers

TODO

## Using Ngrok to test in Development

Used to use localtunnel, but it looks like its down.  Try ngrok instead.

https://ngrok.com/

## Moneris

TODO

## PayPal

TODO

## Stripe

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
webhook_uri: none

And add these values to the app/config/effective_orders.rb initializer:

```ruby
config.stripe = {
  :secret_key => 'sk_live_IKd6HDaYUfoRjflWQTXfFNfc',
  :publishable_key => 'pk_live_liEGn9f0mcxKmoSjoeNbbuE1',
  :currency => 'usd',
  :connect_client_id => 'ca_35jLok5G9kosyYF7quTOwcauJjTnUnud'
}
```

### Stripe Subscriptions

Subscriptions and Stripe Connect do not currently work together.

Register an additional Webhook, to accept Stripe subscription creation events from Stripe

root_url/webhooks/stripe


## License

MIT License.  Copyright Code and Effect Inc. http://www.codeandeffect.com

You are not granted rights or licenses to the trademarks of Code and Effect

## Testing

The test suite for this gem is mostly complete.

Run tests by:

```ruby
guard
```
