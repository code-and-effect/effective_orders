# Effective Orders

A Rails Engine to handle the purchase workflow in a Rails 3.2.x / Rails 4 application.

Includes Carts, Orders, and collecting payment via Stripe, PayPal and Moneris.

Also works with Stripe Connect and Stripe Subscriptions with coupons.

# Getting Started

Add to your Gemfile:

```ruby
gem 'effective_orders', :git => 'https://github.com/code-and-effect/effective_orders'
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

Require the javascript on the asset pipeline by adding the following to your application.js:

```ruby
//= require effective_orders
```

Require the stylesheet on the asset pipeline by adding the following to your application.css:

```ruby
*= require effective_orders
```

## Upgrading from 0.3.x

In the 0.3.x versions of this gem, prices were internally represented as Decimals

This has been changed in 0.4.x to properly be Integer columns

If you're running a 0.3.x or earlier version, please upgrade to 0.4.x with this one command:

```ruby
rails generate effective_orders:upgrade_from03x
```

the above command will upgrade the order_items and subscriptions tables.

If you have additional (products or whatever..) tables with a column `price` represented as a Decimal, they should also be upgraded.

To upgrade, use this generator to create a migration on table `products` with column `price`:

```ruby
bundle exec rails generate effective_orders:upgrade_price_column products price
```

# High Level Overview

Your rails app creates and displays a list of `acts_as_purchsable` objects, each with a `link_to_add_to_cart`.

The user clicks one or more Add to Cart links and adds some purchasables to their cart.

They then click the Checkout link from the My Cart page, or another `link_to_checkout` displayed somewhere, which takes them to `effective_orders.new_order_path`

The checkout is a 2-page process:

The first page gives the user their final option to 'Change Items' and alter the order.

If `require_billing_address` or `require_shipping_address` options are `true` in the `config/initializer/effective_orders.rb` initializer this first checkout page will collect the billing/shipping information.

After clicking 'Save and Continue', the user will be on the collect money page.

If the payment processor is PayPal or Moneris, the user will be sent to their website to enter their credit card details.

If the payment processor is Stripe, there is an in-screen popup form to collect those details.

Once the user has successfully paid, they are returned to a thank you page displaying the order receipt.

An email notification containing the receipt is also sent to the buyer's email address, and the site admin (configurable).


# Usage

effective_orders handles the add_to_cart -> checkout -> collect of payment workflow, but relies on the base application to define, create and display the purchaseable things.

These purchasables could be Products, EventTickets, Memberships or anything else.


## Representing Prices

All prices should be represented as Integers.  For us North Americans, think of it as the number of cents.

To represent the value of `$10.00` the price method should return `1000`.

Similarly, to represent a value of `$0.50` the price method should return `50`.

EffectiveOrders does not deal with a specific currency or do any currency conversions of any kind.


## Creating a purchasable

Once installed, we still need to create something to purchase.

Let's create a `Product` model that uses the `acts_as_purchasable` mixin.

We're also going to prevent the Product from being deleted by overriding `def destroy` and instead setting a boolean `archived = true`.

If someone purchased a Product which is later deleted, the Order History page will be unable to find the Product.

```ruby
class Product < ActiveRecord::Base
  acts_as_purchasable

  # this structure do... block is provided by the migrant gem https://github.com/pascalh1011/migrant
  structure do
    title               :string

    price               :integer, :default => 0
    tax_exempt          :boolean, :default => false

    archived            :boolean, :default => false

    timestamps
  end

  validates_presence_of :title
  validates_numericality_of :price, :greater_than_or_equal_to => 0

  scope :products, -> { where(:archived => false) }

  # This archives Products instead of deleting them
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
      t.integer :price, :default=>0
      t.boolean :tax_exempt, :default=>false
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

Once the database has been migrated, it is time to scaffold/build the CRUD Product screens to create some Products to sell.

### Products#new/#edit

Use the EffectiveOrders price input to enter the price.

It displays the underlying Integer price as a currency formatted value, ensures that a properly formatted price is entered by the user, and POSTs the appropriate Integer value back to the server.

This is available for simple_form, formtastic and Rails default FormBuilder.

```haml
= simple_form_for(@product) do |f|
  = f.input :title
  = f.input :tax_exempt
  = f.input :price, :as => :price
  = f.button :submit
```

or

```ruby
= semantic_form_for(@product) do |f|
  = f.input :price, :as => :price
```

or

```haml
= form_for(@product) do |f|
  = f.price_field :price
```

The `:as => :price` will work interchangeably with SimpleForm or Formtastic, as long as only one of these gems is present in your application

If you use both SimpleForm and Formtastic, you will need to call price input differently:

```ruby
= simple_form_for(@product) do |f|
  = f.input :price, :as => :price_simple_form

= semantic_form_for @user do |f|
  = f.input :price, :as => :price_formtastic
```

### Products#show

So back on the Product#show page, we will render the product with an Add To Cart link

```haml
%h4= @product.title
%p= price_to_currency(@product.price)
%p= link_to_add_to_cart(@product, :class => 'btn btn-primary', :label => 'Add To My Shopping Cart')
```

Please take note of the `price_to_currency` helper above.

This is an EffectiveOrders helper that will display an Integer price as a currency formatted value.

When the user clicks 'Add To My Shopping Cart' the product will be added to the cart.  A flash message is displayed, and the user will return to the same page.

### My Cart

We still need to create a link to the Shopping Cart page so that the user can see his cart.  On your site's main menu:

```ruby
= link_to 'My Cart', effective_orders.carts_path
```

or

```ruby
= link_to_current_cart()  # To display Cart (3) when there are 3 items
```

or

```ruby
= link_to_current_cart(:label => 'My Shopping Cart')  # To display My Shopping Cart (3) when there are 3 items
```

### Checkout

The checkout screen can be reached through the My Cart page, or linked to directly via

```ruby
= link_to 'Go Checkout Already', effective_orders.new_order_path
```

or

```ruby
= link_to_checkout()
```

From here, the effective_orders engine takes over, walks the user through billing and shipping details screens, then finally collects payment through one of the configured payment processors.

## Acts As Purchasable

Mark your rails model with the mixin `acts_as_purchasable` to use it with the effective_orders gem.

This mixin sets up the relationships and provides some validations on price and such.

### Methods

acts_as_purchasable provides the following handy methods:

`.purchased?` has this been purchased by any user in any order?

`.purchased_by?(user)` has this been purchased by the given user?

`.purchased_orders` returns the orders in which the purchases have been made

### Scopes

acts_as_purchsable provides the following scopes:

`Product.purchased` all the Products that have been purchased

`Product.purchased_by(user)` all the Products purchased by a given user.

`Product.sold` all the Products that have been solid (same as purchased)

`Product.sold_by(user)` all the Products that this user has sold via Stripe Connect

`Product.not_purchased` all unpurchased Products

### Digital Downloads

If your product is a digital download, simply specify the URL to download.

The download link will be displayed on all purchased order receipts.

```ruby
def purchased_download_url
  'http://www.something.com/my_cool_product.zip'
end
```

Of course, there's no mechanism here to prevent someone from just copy&pasting this URL to a friend.

If you're interested in this functionality, please check out `effective_assets` and the authenticated-read temporary URLs.


### Tax

All `acts_as_purchasable` objects will respond to `tax_exempt`.

By default, `tax_exempt` is false, meaning that tax must be applied to this item.

The tax calculation is controlled by the config/initializers/effective_orders.rb `config.tax_rate_method` and may be set on an app wide basis.

If `tax_exempt` returns true, it means that no tax will be applied to this item.

Please see the initializer for more information.


### Callbacks

When defined, upon purchase the following callback will be triggered:

```ruby
class Product
  acts_as_purchasable

  after_purchase do |order, order_item|   # These are optional, if you don't care about the order or order_item
    self.do_something() # self is the newly purchased instance of this Product
  end

end
```

# Authorization

All authorization checks are handled via the config.authorization_method found in the `config/initializers/effective_orders.rb` file.

It is intended for flow through to CanCan or Pundit, but neither of those gems are required.

This method is called by the controller action with the appropriate action and resource

This method is called by all controller actions with the appropriate action and resource

Action will be one of [:index, :show, :new, :create, :edit, :update, :destroy]

Resource will the appropriate Effective::Order, Effective::Cart or Effective::Subscription ActiveRecord object or class

The authorization method is defined in the initializer file:

```ruby
# As a Proc (with CanCan)
config.authorization_method = Proc.new { |controller, action, resource| authorize!(action, resource) }
```

```ruby
# As a Custom Method
config.authorization_method = :my_authorization_method
```

and then in your application_controller.rb:

```ruby
def my_authorization_method(action, resource)
  current_user.is?(:admin) || EffectivePunditPolicy.new(current_user, resource).send('#{action}?')
end
```

or disabled entirely:

```ruby
config.authorization_method = false
```

If the method or proc returns false (user is not authorized) an Effective::AccessDenied exception will be raised

You can rescue from this exception by adding the following to your application_controller.rb:

```ruby
rescue_from Effective::AccessDenied do |exception|
  respond_to do |format|
    format.html { render 'static_pages/access_denied', :status => 403 }
    format.any { render :text => 'Access Denied', :status => 403 }
  end
end
```

## Permissions

The permissions you actually want to define are as follows (using CanCan):

```ruby
can [:manage], Effective::Cart, :user_id => user.id
can [:manage], Effective::Order, :user_id => user.id # Orders cannot be deleted
can [:manage], Effective::Subscription, :user_id => user.id
```


## Carts

The standard website shopping cart paradigm.  Add one or more objects to the cart and purchase them all in one step.

When a non-logged-in user comes to the website, a new `Effective::Cart` object is created and stored in the session variable.  This user can add items to the Shopping Cart as normal.

When user proceeds to Checkout, they will be required to login.

When that user logs in, the Cart will be assigned to that User ID and if they had a previous existing cart, the items will be merged.

You shouldn't need to deal with the Cart at all, except to make a link from your Site Menu to the 'My Cart' page

```ruby
= link_to_current_cart()  # To display Cart (3) when there are 3 items
```

or

```ruby
= link_to 'My Cart', effective_orders.carts_path
```

However, if you want to render a cart inline on some random page, or play with the object directly, you can.

Use the helper method `current_cart` to refer to the current `Effective::Cart`.

And call `render_cart(current_cart)` to display the Cart on your very custom page.


## Orders

TODO



## Helpers

TODO


## Admin Screen

To use the Admin screen, please also install the effective_datatables gem:

```ruby
gem 'effective_datatables', :git => 'https://github.com/code-and-effect/effective_datatables.git'
```

Then you should be able to visit:

```ruby
link_to 'Orders', effective_orders.admin_orders_path   # /admin/orders
```


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


# Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

