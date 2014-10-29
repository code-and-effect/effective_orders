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

## PayPal

TODO

## Moneris

Use the following instructions to set up a Moneris TEST store.

The set up process is identical to a Production store, except that you will need to Sign Up with Moneris and get real credentials.

We are also going to use ngrok to give us a public facing URL

### Create Test / Development Store

Visit https://esqa.moneris.com/mpg/ and login with: demouser / store1 / password

Select ADMIN -> hosted config from the menu

Click the 'Generate a New Configuration' button which should bring us to a "Hosted Paypage Configuration"

### Basic Configuration

Description:  'My Test store'

Transaction Type: Purchase

Response Method: Sent to your server as a POST

Approved URL: http://4f972556.ngrok.com/orders/moneris_postback

Declined URL: http://4f972556.ngrok.com/orders/moneris_postback

Note: The Approved and Declined URLs must match the effective_orders.moneris_postback_path value in your application. By default it is /orders/moneris_postback

Click 'Save Changes'

### PsStoreId and HppKey

At the top of the main 'Hosted Paypage Configuration' page should be the ps_store_id and hpp_key values.

Copy these two values into the appropriate lines of config/effective_orders.rb initializer file.

```ruby
  config.moneris_enabled = true

  if Rails.env.production?
    config.moneris = {
      :ps_store_id => '',
      :hpp_key => '',
      :hpp_url => 'https://www3.moneris.com/HPPDP/index.php',
      :verify_url => 'https://www3.moneris.com/HPPDP/verifyTxn.php',
      :order_nudge => 0
    }
  else
    config.moneris = {
      :ps_store_id => 'VZ9BNtore1',
      :hpp_key => 'hp1Y5J35GVDM',
      :hpp_url => 'https://esqa.moneris.com/HPPDP/index.php',
      :verify_url => 'https://esqa.moneris.com/HPPDP/verifyTxn.php',
      :order_nudge => 0
    }
  end
```

### Paypage Appearance

Click 'Configure Appearance' from the main Hosted Paypage Configuration

Display item details: true

Display customer details: true

Display billing address details: true

Display shipping address details: true

Enable input of Billing, Shipping and extra fields: false

Display merchange name: true, if you have an SSL cert

Cancel Button Text:  'Cancel'

Cancel Button URL: http://4f972556.ngrok.com

Click 'Save Appearance Settings'

Click 'Return to main configuration'

### Response Fields

None of the 'Return...' checkboxes are needed. Leave unchecked.

Perform asynchronous data post:  false, unchecked

Async Response URL:  leave blank

Click 'Save Response Settings'

Click 'Return to main configuration'


### Security

Referring URL: Depends how you're using effective_orders in your application, you can add multiple URLs
By default, use http://4f972556.ngrok.com/orders/new

Enable Card Verification: false, unused

Enable Transaction Verification: true
Response Method: Displayed as key/value pairs on our server.
Response URL: leave blank

Click 'Save Verification Settings'
Click 'Return to main configuration'


### Configure Email Receipts

effective_orders automatically sends its own receipts.

If you'd prefer to use the Moneris receipt, disable email sendouts from the config/effective_orders.rb initializer


### Purchasing an Order through Moneris

With this test store set up, you can make a successful purchase with:

Cardholder Name: Any name
Credit Card Number: 4242 4242 4242 4242
Expiry Date: Any future date

Some gotchas:

1. When using a test store, if your order total price is less than $10, the penny amount may be used to raise an error code.

Order totals ending in .00 will be Approved
Order totals ending in .05 will be Declined

And there's a whole bunch more.  Please refer to:

https://www.google.ca/url?sa=t&rct=j&q=&esrc=s&source=web&cd=1&ved=0CB8QFjAA&url=https%3A%2F%2Fcartthrob.com%2F%3FACT%3D50%26fid%3D25%26aid%3D704_jvVKOeo1a8d3aSYeT3R4%26board_id%3D1&ei=_p1OVOysEpK_sQTZ8oDgCg&usg=AFQjCNHJGH_hEm4kUJAzkvKrzTqEpFnrgA&sig2=XJdE6PZoOY9habWH_B4uWA&bvm=bv.77880786,d.cWc&cad=rja

2. Moneris will not process a duplicate order ID

Once Order id=1 has been purchased/declined, you will be unable to purchase an order with id=1 ever again.

This is what the moneris order_nudge configuration setting is used for.

You can set this to 1000 to start the IDs at 1+1000 instead of 1.


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
