# Effective Orders

Carts, Orders, and collecting payment via Stripe, PayPal and Moneris.

A Rails Engine to handle the purchase workflow in a Rails 3.2.x / Rails 4 application.

Also works with Stripe Connect and Stripe Subscriptions with coupons.

Sends order receipt emails automatically.

Has Order History, My Purchases, My Sales and Admin screens.

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

If you want to tweak the table name (to use something other than the default 'orders', 'order_items', 'carts', 'cart_items', 'customers', 'subscriptions'), manually adjust both the configuration file and the migration now.

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

### Upgrading from 0.3.x

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

## High Level Overview

Your rails app creates and displays a list of `acts_as_purchsable` objects, each with a `link_to_add_to_cart(object)`.

The user clicks one or more Add to Cart links and adds some purchasables to their cart.

They then click the Checkout link from the My Cart page, or another `link_to_checkout` displayed somewhere, which takes them to `effective_orders.new_order_path` to begin checkout.

The checkout is a 2-page process:

The first page collects billing/shipping details and gives the user their final option to 'Change Items'.

After clicking 'Save and Continue', the user will be on the collect money page.

If the payment processor is PayPal or Moneris, the user will be sent to their website to enter their credit card details.

If the payment processor is Stripe, there is an on-screen popup form to collect those details.

Once the user has successfully paid, they are redirected to a thank you page displaying the order receipt.

An email notification containing the receipt is also sent to the buyer's email address, and the site admin.


## Usage

effective_orders handles the add_to_cart -> checkout -> collect of payment workflow, but relies on the base application to define, create and display the purchaseable things.

These purchasables could be Products, EventTickets, Memberships or anything else.


### Representing Prices

All prices should be internally represented as Integers.  For us North Americans, think of it as the number of cents.

To represent the value of `$10.00` the price method should return `1000`.

Similarly, to represent a value of `$0.50` the price method should return `50`.

EffectiveOrders does not deal with a specific currency or do any currency conversions of any kind.  The main gem authors are North American, and as such this gem is unfortunately North American biased.


### Creating a purchasable

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

This is an EffectiveOrders helper that will display an Integer price as a currency formatted value.  It does an Integer to Float conversion then calls the rails standard `number_to_currency`.

When the user clicks 'Add To My Shopping Cart' the product will be added to the cart.  A flash message is displayed, and the user will return to the same page.

### My Cart

We still need to create a link to the Shopping Cart page so that the user can view their cart.  On your site's main menu:

```ruby
= link_to_current_cart()  # To display Cart (3) when there are 3 items
```

or

```ruby
= link_to_current_cart(:label => 'Shopping Cart', :class => 'btn btn-prmary')  # To display Shopping Cart (3) when there are 3 items
```

or

```ruby
= link_to 'My Cart', effective_orders.carts_path
```

### Checkout

The checkout screen can be reached through the My Cart page, or linked to directly via

```ruby
= link_to_checkout() # To display Proceed to Checkout
```

or

```ruby
= link_to_checkout(:label => 'Continue to Checkout', :class => 'btn btn-primary')
```

or

```ruby
= link_to 'Go Checkout Already', effective_orders.new_order_path
```

From here, the effective_orders engine takes over, walks the user through billing and shipping details screens, then finally collects payment through one of the configured payment processors.


## Acts As Purchasable

Mark your rails model with the mixin `acts_as_purchasable` to use it with the effective_orders gem.

This mixin sets up the relationships and provides some validations on price and such.

### Methods

acts_as_purchasable provides the following methods:

`.purchased?` has this been purchased by any user in any order?

`.purchased_by?(user)` has this been purchased by the given user?

`.purchased_orders` returns the `Effective::Order`s in which the purchases have been made

### Scopes

acts_as_purchsable provides the following scopes:

`Product.purchased` all the Products that have been purchased

`Product.purchased_by(user)` all the Products purchased by a given user.

`Product.sold` all the Products that have been solid (same as purchased)

`Product.sold_by(user)` all the Products that this user has sold via Stripe Connect

`Product.not_purchased` all unpurchased Products

### Digital Downloads

If your product is a digital download, simply create a method in your acts_as_purchasable rails model that returns the full URL to download.

The download link will be displayed on all purchased order receipts and the Order History page.

```ruby
def purchased_download_url
  'http://www.something.com/my_cool_product.zip'
end
```

Of course, there's no mechanism here to prevent someone from just copy&pasting this URL to a friend.

If you're interested in that kind of restricted-download functionality, please check out [effective_assets](https://github.com/code-and-effect/effective_assets) and the authenticated-read temporary URLs.


### Tax

All `acts_as_purchasable` objects will respond to the boolean method `tax_exempt`.

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

## Authorization

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

### Permissions

The permissions you actually want to define are as follows (using CanCan):

```ruby
can [:manage], Effective::Cart, :user_id => user.id
can [:manage], Effective::Order, :user_id => user.id # Orders cannot be deleted
can [:manage], Effective::Subscription, :user_id => user.id
```

## Whats Included

This gem has a lot of screens, all of which are automatically available via the Rails Engine.

Pretty much every screen also has a coresponding helper function that is used in rendering that content.

The idea behind this implementation is that you, the developer, should be able to use effective_orders as a quick drop-in purchasing solution, with all screens and routes provided, but also have all the individual pieces available to customize the workflow.


### Carts

The standard website shopping cart paradigm.  Add one or more objects to the cart and purchase them all in one step.

When a non-logged-in user comes to the website, a new `Effective::Cart` object is created and stored in the session variable.  This user can add items to the Cart as normal.

Only when the user proceeds to Checkout will they be required to login.

Upon log in, the session Cart will be assigned to that User's ID, and if the User had a previous existing cart, all CartItems will be merged.



You shouldn't need to deal with the Cart object at all, except to make a link from your Site Menu to the 'My Cart' page (as documented above).

However, if you want to render a Cart on another page, or play with the Cart object directly, you totally can.

Use the helper method `current_cart` to refer to the current `Effective::Cart`.

And call `render_cart(current_cart)` to display the Cart anywhere.


### Orders

On the Checkout page (`effective_orders.new_order_path`) a new `Effective::Order` object is created and one or more `Effective::OrderItem`s are initialized based on the `current_cart`.

If the configuration options `config.require_billing_address` and/or `config.require_shipping_address` options are `true` then the user will be prompted for the appropriate addresses, based on [effective_addresses](https://github.com/code-and-effect/effective_addresses/).

As well, if the config option `config.collect_user_fields` is present, form fields to collect those user attributes will be present on this page.

When the user submits the form on this screen, a POST to `effective_orders.order_path` is made, and the `Effective::Order` object is validated and created.

On this final checkout screen, links to all configured payment providers are displayed, and the user may choose which payment processor should be used to make a payment.

The payment processor handles collecting the Credit Card number, and through one way or another, the `Effective::Order` `@order.purchase!` method is called.

Once the order has been marked purchased, the user is redirected to the `effective_orders.order_purchased_path` screen where they see a 'Thank You!' message, and the Order receipt.

If the configuration option `config.mailer[:send_order_receipt_to_buyer] == true` the order receipt will be emailed to the user.

As well, if the configuration option `config.mailer[:send_order_receipt_to_admin] == true` the order receipt will be emailed to the site admin.

The Order has now been purchased.


If you are using effective_orders to roll your own custom payment workflow, you should be aware of the following helpers:

- `render_checkout(order)` to display the standard Checkout step inline.
- `render_checkout(order, :purchased_redirect_url => '/', :declined_redirect_url => '/')` to display the Checkout step with custom redirect paths.

- `render_purchasables(one_or_more_acts_as_purchasable_objects)` to display a list of purchasable items

- `render_order(order)` to display the full Order receipt.
- `order_summary(order)` to display some quick details of an Order and its OrderItems.
- `order_payment_to_html(order)` to display the payment processor details for an order's payment transaction.


### Effective::Order Model

There may be times where you want to deal with the `Effective::Order` object directly.

The `acts_as_purchasable` `.purchased?` and `.purchased_by?(user)` methods only return true when a purchased `Effective::Order` exists for that object.

To programatically purchase one or more `acts_as_purchasable` objects:

```ruby
Effective::Order.new([@product1, @product2], current_user).purchase!('from my rake task')
```

Here the `billing_address` and `shipping_address` are copied from the `current_user` object if the `current_user` responds_to `billing_address` / `shipping_address` as per [effective_addresses](https://github.com/code-and-effect/effective_addresses/).

Here's another example of programatically purchasing some `acts_as_purchasable` objects:

```ruby
order = Effective::Order.new()
order.user = @user
order.billing_address = Effective::Address.new(...)
order.shipping_address = Effective::Address.new(...)
order.add(@product1)
order.add(@product2)
order.purchase!(:some => {:complicated => 'details', :in => 'a hash'})
```

The one gotcha with the above two scenarios, is that when `purchase!` is called, the `Effective::Order` in question will run through its validations.  These validations include:

- `validates_presence_of :billing_address` when configured to be required
- `validates_presence_of :shipping_address` when configured to be required
- `validates :user` which can be disabled via config initializer

- `validates_numericality_of :total, :greater_than_or_equal_to => minimum_charge` where minimum_charge is the configured value, once again from the initializer
- `validates_presence_of :order_items` the Order must have at least one OrderItem

You can skip validations with the following command, but be careful as this skips all validations:

```ruby
Effective::Order.new(@product, @user).purchase!('no validations', :validate => false)
```

The `@product` is now considered purchased.


To check an Order's purchase state, you can call `@order.purchased?`

There also exist the scopes: `Effective::Order.purchased` and `Effective::Order.purchased_by(user)` which return a chainable relation of all purchased `Effective::Order` objects.


### My Purchases / Order History

This screen displays all past purchases made by the current user.  You can add it to your site's main menu or User profile area:

```ruby
= link_to_my_purchases()  # To display My Purchases
```

or

```ruby
= link_to_my_purchases(:label => 'Order History', :class => 'btn btn-primary')
```

or

```ruby
= link_to 'My Order History', effective_orders.my_purchases_path
```

or render it inline on an existing page with

```ruby
render_order_history(user_or_orders)
```

If a user is passed, a call to `Effective::Order.purchased_by(user)` will be made to assign all purchased orders.

Totally optional, but another way of displaying the Order History is to use the included datatable, based on [effective_datatables](https://github.com/code-and-effect/effective_datatables/)

In your controller:

```ruby
@datatable = Effective::Datatables::Orders.new(:user_id => @user.id)
```

and then in the view:

```ruby
render_datatable @datatable
```

Please refer to [effective_datatables](https://github.com/code-and-effect/effective_datatables/) for more information about that gem.


### Admin Screen

To use the Admin screen, please also install the effective_datatables gem:

```ruby
gem 'effective_datatables'
```

Then you should be able to visit:

```ruby
link_to 'Orders', effective_orders.admin_orders_path   # /admin/orders
```

or to create your own Datatable of all Orders, in your controller:

```ruby
@datatable = Effective::Datatables::Orders.new()
```

and then in the view:

```ruby
render_datatable @datatable
```


## Testing in Development

Every payment processor seems to have its own development sandbox which allow you to make test purchases in development mode.

You will need an external IP address to work with these sandboxes.

We suggest the free application `https://ngrok.com/` for this ability.


## Paying via Moneris

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


## Paying via Stripe

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


### PayPal

TODO


## License

MIT License.  Copyright Code and Effect Inc. http://www.codeandeffect.com

You are not granted rights or licenses to the trademarks of Code and Effect


## Testing

The test suite for this gem is mostly complete.

Run tests by:

```ruby
guard
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request

