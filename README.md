# Effective Orders

Carts, Orders, and collecting payment via Stripe, PayPal and Moneris.

A Rails Engine to handle the purchase workflow in a Rails 3.2.x / Rails 4 application.

Also works with Stripe Connect and Stripe Subscriptions with coupons.

Sends order receipt emails automatically.

Has Order History, My Purchases, My Sales and Admin screens.

## Getting Started

Please first install the [effective_addresses](https://github.com/code-and-effect/effective_addresses), [effective_datatables](https://github.com/code-and-effect/effective_datatables) and [effective_form_inputs](https://github.com/code-and-effect/effective_form_inputs) gems.

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

## High Level Overview

Your rails app creates and displays a list of `acts_as_purchasable` objects, each with a `link_to_add_to_cart(object)`.

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

All prices should be internally represented as Integers. For us North Americans, think of it as the number of cents.

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

  # Attributes
  # title               :string
  # price               :integer, default: 0
  # tax_exempt          :boolean, default: false
  # timestamps

  validates_presence_of :title
  validates_numericality_of :price, greater_than_or_equal_to: 0
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

Use an [effective_form_inputs](https://github.com/code-and-effect/effective_form_inputs#effective-price) effective_price input to enter the price.

It displays the underlying Integer price as a currency formatted value, ensures that a properly formatted price is entered by the user, and POSTs the appropriate Integer value back to the server.

This is available for simple_form, formtastic and Rails default FormBuilder.

```haml
= simple_form_for(@product) do |f|
  = f.input :title
  = f.input :tax_exempt
  = f.input :price, as: :effective_price
  = f.button :submit
```

or

```ruby
= semantic_form_for(@product) do |f|
  = f.input :price, as: :effective_price
```

or

```haml
= form_for(@product) do |f|
  = f.effective_price :price
```

### Products#show

So back on the Product#show page, we will render the product with an Add To Cart link

```haml
%h4= @product.title
%p= price_to_currency(@product.price)
%p= link_to_add_to_cart(@product, class: 'btn btn-primary', label: 'Add To My Shopping Cart')
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
= link_to_current_cart(label: 'Shopping Cart', class: 'btn btn-prmary')  # To display Shopping Cart (3) when there are 3 items
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
= link_to_checkout(label: 'Continue to Checkout', class: 'btn btn-primary')
```

or

```ruby
= link_to 'Continue to Checkout', effective_orders.new_order_path
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


### Tax Exempt

All `acts_as_purchasable` objects will respond to the boolean method `tax_exempt`.

By default, `tax_exempt` is false, meaning that tax must be applied to this item.

If `tax_exempt` returns true, it means that no tax will be applied to this item.

### Tax

The tax calculation applied to an order is controlled by the config/initializers/effective_orders.rb `config.order_tax_rate_method`

The default implementation assigns the tax rate based on the order's billing_address:

```ruby
config.order_tax_rate_method = Proc.new { |order| Effective::TaxRateCalculator.new(order: order).tax_rate }
```

Right now, the `Effective::TaxRateCalculator` only supports taxes for Canadian provinces.

US and international tax rates are not currently supported and are assigned 0% tax.

Instead of calculating based on the billing_address, a single static tax rate can be applied to all orders.

To apply 12.5% tax to all orders:

```ruby
config.order_tax_rate_method = Proc.new { |order| 12.5 }
```

Or to apply 0% tax:

```ruby
config.order_tax_rate_method = Proc.new { |order| 0 }
```

Please see the initializer file for more information.


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

This method is called by the controller action with the appropriate action and resource.

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
    format.html { render 'static_pages/access_denied', status: 403 }
    format.any { render text: 'Access Denied', status: 403 }
  end
end
```

### Permissions

The permissions you actually want to define for a regular user are as follows (using CanCan):

```ruby
can [:manage], Effective::Cart, user_id: user.id
can [:manage], Effective::Order, user_id: user.id # Orders cannot be deleted
can [:manage], Effective::Subscription, user_id: user.id
```

In addition to the above, the following permissions allow access to the `/admin` screens:

```ruby
can :admin, :effective_orders # Can access the admin screens
can :show, :payment_details # Can see the payment purchase details on orders
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

If `config.use_address_full_name` is set to `true` then appropriate form field will be shown and the user will be prompted for the appropriate address full name during the checkout process, based on [effective_addresses](https://github.com/code-and-effect/effective_addresses/).

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
- `render_checkout(order, purchased_redirect_url: '/', declined_redirect_url: '/')` to display the Checkout step with custom redirect paths.

- `render_purchasables(one_or_more_acts_as_purchasable_objects)` to display a list of purchasable items

- `render_order(order)` to display the full Order receipt.
- `order_summary(order)` to display some quick details of an Order and its OrderItems.
- `order_payment_to_html(order)` to display the payment processor details for an order's payment transaction.

#### Send Order Receipts in the Background

Emails will be sent immediately unless `config.mailer[:deliver_method] == :deliver_later`.

If you are using [Delayed::Job](https://github.com/collectiveidea/delayed_job) to send emails in a background process then you should set the `delayed_job_deliver` option so that `config.mailer[:delayed_job_deliver] == true`.


### Effective::Order Model

There may be times where you want to deal with the `Effective::Order` object directly.

The `acts_as_purchasable` `.purchased?` and `.purchased_by?(user)` methods only return true when a purchased `Effective::Order` exists for that object.

To programatically purchase one or more `acts_as_purchasable` objects:

```ruby
Effective::Order.new(@product1, @product2, user: current_user).purchase!(details: 'from my rake task')
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
order.purchase!(details: {complicated: 'details', in: 'a hash'})
```

The one gotcha with the above two scenarios, is that when `purchase!` is called, the `Effective::Order` in question will run through its validations.  These validations include:

- `validates_presence_of :billing_address` when configured to be required
- `validates_presence_of :shipping_address` when configured to be required
- `validates :user` which can be disabled via config initializer

- `validates_numericality_of :total, greater_than_or_equal_to: minimum_charge` where minimum_charge is the configured value, once again from the initializer
- `validates_presence_of :order_items` the Order must have at least one OrderItem

You can skip validations with the following command, but be careful as this skips all validations:

```ruby
Effective::Order.new(@product, user: @user).purchase!(validate: false)
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
= link_to_my_purchases(label: 'Order History', class: 'btn btn-primary')
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
@datatable = Effective::Datatables::Orders.new(user_id: @user.id)
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

## Rake Tasks

### Overwrite order item titles

When an order is purchased, the `title()` of each `acts_as_purchasable` object is saved to the database.

If you change the output of `acts_as_purchasable`.`title`, any existing order items will remain unchanged.

Run this script to overwrite all saved order item titles with the current `acts_as_purchasable`.`title`.

```ruby
rake effective_orders:overwrite_order_item_titles
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

Approved URL: https://myapp.herokuapp.com/orders/moneris_postback

Declined URL: https://myapp.herokuapp.com/orders/moneris_postback

Note: The Approved and Declined URLs must match the effective_orders.moneris_postback_path value in your application. By default it is /orders/moneris_postback

Click 'Save Changes'

### PsStoreId and HppKey

At the top of the main 'Hosted Paypage Configuration' page should be the ps_store_id and hpp_key values.

Copy these two values into the appropriate lines of config/effective_orders.rb initializer file.

```ruby
  config.moneris_enabled = true

  if Rails.env.production?
    config.moneris = {
      ps_store_id: '',
      hpp_key: '',
      hpp_url: 'https://www3.moneris.com/HPPDP/index.php',
      verify_url: 'https://www3.moneris.com/HPPDP/verifyTxn.php'
    }
  else
    config.moneris = {
      ps_store_id: 'VZ9BNtore1',
      hpp_key: 'hp1Y5J35GVDM',
      hpp_url: 'https://esqa.moneris.com/HPPDP/index.php',
      verify_url: 'https://esqa.moneris.com/HPPDP/verifyTxn.php'
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

Cancel Button URL: https://myapp.herokuapp.com/

Click 'Save Appearance Settings'

Click 'Return to main configuration'

### Response Fields

None of the 'Return...' checkboxes are needed. Leave unchecked.

Perform asynchronous data post:  false, unchecked

Async Response URL:  leave blank

Click 'Save Response Settings'

Click 'Return to main configuration'


### Security

Referring URL: https://myapp.herokuapp.com/

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

https://www.collinsharper.com/downloadable/download/sample/sample_id/5/

2. Moneris will not process a duplicate order ID

Once Order id=1 has been purchased/declined, you will be unable to purchase an order with id=1 ever again.

effective_orders works around this by appending a timestamp to the order ID.


## Paying via Stripe

Make sure `gem 'stripe'` is included in your Gemfile.

First register for an account with Stripe

https://manage.stripe.com/register

and configure your bank accounts appropriately.

Then enable Stripe in the app/config/effective_orders.rb initializer and enter your keys.

```ruby
config.stripe_enabled = true

config.stripe = {
  secret_key: 'sk_live_IKd6HDaYUfoRjflWQTXfFNfc',
  publishable_key: 'pk_live_liEGn9f0mcxKmoSjoeNbbuE1',
  currency: 'usd'
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
  secret_key: 'sk_live_IKd6HDaYUfoRjflWQTXfFNfc',
  publishable_key: 'pk_live_liEGn9f0mcxKmoSjoeNbbuE1',
  currency: 'usd',
  connect_client_id: 'ca_35jLok5G9kosyYF7quTOwcauJjTnUnud'
}
```

There are a few additional steps you need to take on the rails application side of things:


Before allowing one of your Users to create a Product for sale, you must enforce that they have a Stripe Connect account setup and configured.

You can check if they have an account set up using the built in helper `is_stripe_connect_seller?(current_user)`

If the above check returns false, you must send them to Stripe to set up their StripeConnect account, using the built in helper `link_to_new_stripe_connect_customer`

Once they've registered their account on the Stripe side, Stripe sends a webhook request, which is processed by the `webhooks_controller.rb`

In the webhook controller, an `Effective::Customer` object is created, and your user is now ready to sell stuff via StripeConnect.


Your product model must also define a `seller` method so that effective_orders knows who is selling the Product.  Add the following to your `acts_as_purchasable` model:

```ruby
def seller
  User.find(user_id)
end
```

### Stripe Subscriptions

Subscriptions and Stripe Connect do not currently work together.

Register an additional Webhook, to accept Stripe subscription creation events from Stripe

root_url/webhooks/stripe


## Paying Via PayPal

Use the following to set up a PayPal sandbox store.

### PayPal Account

Start by creating a PayPal Account. [Sign up or login](http://paypal.com/). You'll need a business account for use in production but a personal account is fine for creating sandbox apps.

_During sign up of a personal account, you may go to the next step in these directions when PayPal asks you to link a credit card or bank with your account._

_During sign up of a business account, you may go to the next step in these directions when PayPal asks "How do you want to set up PayPal on your website?"._

Confirm your email address using the email sent to you by PayPal.


### Configuring Your App With a PayPal Sandbox

PayPal uses a series of public and private certificates and keys to communicate with third party applications.

You need to generate your application's private key (so that it is private!). To generate these, we'll use OpenSSL. If you're on Mac/Linux, you can run these commands inside `#{Rails.root}/config/paypalcerts/development/`:

```
openssl genrsa -out app_key.pem 1024
openssl req -new -key app_key.pem -x509 -days 999 -out app_cert.pem
```

The app_key.pem file is your private key and the app_cert.pem is the public certificate. We require one more certificate, the PayPal public certificate. This certificate will come from your sandbox seller account.

To login to the sandbox seller account:

1. Visit the [PayPal developer portal](https://developer.paypal.com/) and click on "Sandbox" -> "Accounts".
   It might take some time for the two default sandbox accounts to show up here if you just created your account (~10 minutes).
2. Click on the facilitator account accordion, then click 'Profile'.
3. Change the password of the facilitator account to whatever you want and copy the facilitator account email address.
4. Go to the [PayPal sandbox site](https://www.sandbox.paypal.com/).
5. Sign in using the facilitator account credentials

**If the seller account is from Canada, you can follow these directions:**

1. Click "Profile". Then click "Encrypted Payment Settings" under the "Selling Preferences" column.
2. Download the PayPal public certicate in the middle of the page and save it as `#{Rails.root}/config/paypalcerts/development/paypal_cert.pem`.
3. Upload the public certificate that you generated earlier, `app_cert.pem`, at the bottom of the page.
4. Copy the new `Cert ID` of the new public certificiate and add it to the effective_orders initializer with other PayPal settings as the `:cert_id`.

While you're logged in to the seller account, you should disable non-encrypted instant payment notifications (IPNs):

1. Click on "Profile".
2. Click on "Website Payment Preferences" under the "Selling Preferences" column.
3. Under "Encrypted Website Payments", turn "Block Non-encrypted Website Payment" to "On"

**If the seller account is from elsewhere, please contribute what you find. =)**

Make sure all of the certificates/keys are available in the proper config directory (i.e. `#{Rails.root}/config/paypalcerts/development/paypal_cert.pem`)
or set up environment variables to hold the full text or file location.

Finally, finish adding config values in the effective_orders initializer. Set `config.paypal_enabled = true` and fill out the `config.paypal` settings:

* seller_email - email that you logged into the sandbox site with above
* secret - can be any string (see below)
* cert_id - provided by PayPal after uploading your public `app_cert.pem`
* paypal_url - https://www.sandbox.paypal.com/cgi-bin/webscr for sandbox or https://www.paypal.com/cgi-bin/webscr for real payments
* currency - [choose your preference](https://developer.paypal.com/docs/integration/direct/rest-api-payment-country-currency-support/)
* paypal_cert - PayPal's public certificate for your app, downloaded from PayPal earlier (this can be a string with `\n` in it or a path to the file)
* app_cert - Your generated public certificate (this can be a string with `\n` in it or a path to the file)
* app_key - Your generated private key (this can be a string with `\n` in it or a path to the file)

The secret can be any string. Here's a good way to come up with a secret:

```irb
 & irb
 > require 'securerandom'
=> true
 > SecureRandom.base64
=> "KWidsksL/KR4LAf2EcRSdQ=="
```

### Configuring PayPal For Use With Real Payments

This process should be very similar although you'll create and configure a seller account on paypal.com rather than the sandbox site.
You should generate separate private and public certificates/keys for this and it is advisable to not keep production certificates/keys in version control.

## Paying via CCBill

Effective Orders has implemented checkout with CCBill using their "Dynamic Pricing" API and does not
integrate with CCBill subscriptions. If you need to make payments for CCBill subscriptions, please help
by improving Effective Orders with this functionality.

### CCBill Account Setup

You need a merchant account with CCBill so go sign up and login. To set up your account with Dynamic
Pricing, you'll need to go through some hoops with CCBill:

1. Get approval to operate a merchant account from CCBill Merchant Services (they'll need to see your
   site in action)
2. Provide CCBill with two valid forms of ID and wait for them to approve your account
3. Create two additional sub accounts for a staging server and your localhost
   ("Account Info" > "Account Setup")
4. Get each new sub account approved by Merchant Services (mention that they are for testing only)
5. Ask CCBill tech support to set up all sub accounts with Dynamic Pricing
6. Set the postback urls for each sub account to be `"#{ your_domain_name }/orders/ccbill_postback`
   (Look for 'Approval Post URL' and 'Denial Post URL' in "Account Info" > "Sub Account Admin" > select sub account
   \> "Advanced" > under 'Background Post Information')

### Effective Orders Configuration

Get the following information and add it
to the Effective Orders initializer. CCBill live chat is generally quick and helpful. They can help you
find any of this information.

- Account number (`:client_accnum`)
- Subaccount number (`:client_subacc`)
- Checkout form id/name (`:form_name`)
- Currency code (`:currency_code`)
- Encryption key/salt (`:dynamic_pricing_salt`)("Account Info" > "Sub Account Admin" > select sub account
  \> "Advanced" > under 'Upgrade Security Setup Information' > 'Encryption key')

Effective Orders will authorize to make changes to the customer's order during CCBill's post back after
the transaction. Since, this is not an action that the customer takes directly, please make sure
that the Effective Orders authorization method returns `true` for the controller/action
`'Effective::OrdersController#ccbill_postback'` with an `Effective::Order` resource.

### Testing transactions with CCBill

To test payments with CCBill:

1. Set up yourself as a user who is authorized to make test transactions
   ([See this guide](https://www.ccbill.com/cs/wiki/tiki-index.php?page=How+do+I+set+up+a+user+to+process+test+transactions%3F))
2. Use ngrok on localhost or a staging server to go through a normal payment (remember to configure the
   postback urls (see #6 of [CCBill Account Setup](#ccbill-account-setup))
3. Use one of the provided credit card numbers in the guide from step 1 for the associated response

### Helpful CCBill Documentation

- [Dynamic Pricing](https://www.ccbill.com/cs/wiki/tiki-index.php?page=Dynamic+Pricing)
- [Dynamic Pricing User Guide](https://www.ccbill.com/cs/wiki/tiki-index.php?page=Dynamic+Pricing+User+Guide)
- [Background Post](https://www.ccbill.com/cs/wiki/tiki-index.php?page=Background+Post)
- [Webhooks](https://www.ccbill.com/cs/wiki/tiki-index.php?page=Webhooks+User+Guide)
- [How do I set up a user to process test transactions?](https://www.ccbill.com/cs/wiki/tiki-index.php?page=How+do+I+set+up+a+user+to+process+test+transactions%3F)

## Paying Using App Currency or Logic

There are situations when you want to handle payment logic inside your application. For example, an app could
have it's own type of currency (tokens, points, kudos) that could be used to make payments.

Let's look at a sample app checkout configuration to see how to get this kind of checkout working:

```ruby
config.app_checkout_enabled = true

config.app_checkout = {
  checkout_label: 'Checkout with Tokens',
  service: TokenCheckoutService,
  declined_flash: "Payment was unsuccessful. Please try again."
}
```

First, decide on a checkout button label (this is only used when there's more than one checkout option available).
Other checkout buttons follow the pattern of "Checkout with \_\_\_", like "Checkout with Moneris".

Second, create a service object in your app and add a reference to it here ([see below for details](#the-app-checkout-service-object)).

The last configuration option is the declined flash message displayed when the `successful?` method
returns `false`.

Finally, *the app checkout button is hidden* unless effective orders receives authorzation to
display it. This is helpful if certain users don't use the in-app currency or in-app checkout.
To authorize effective orders and display the button, you should make sure that the effective
orders `authorization_method`, defined earlier in the config file, returns `true` if the three
arguments are: An instance of `Effective::OrdersController`, the Symbol `:app_checkout`, and the
instance of `Effective::Order`.

### The App Checkout Service Object

The app checkout [service object](http://stevelorek.com/service-objects.html) is responsible for containing
the businiess logic of in-app payments (i.e. with tokens).

There are two recommended ways to implement the service object:

1. Create a service object that inherits from `EffectiveOrders::AppCheckoutService`
2. Use the [interactor gem](https://github.com/collectiveidea/interactor) (interactor is just another
   term for service object)

Here's a sample service object (and likely the minimal implementation that you'll want):

```ruby
# located in /app/services/token_checkout_service.rb

# Instances of this class have access to the Effective::Order object in the instance variable, @order.
class TokenCheckoutService < EffectiveOrders::AppCheckoutService
  # This method is responsible to complete the payment transaction
  def call
    cost_in_tokens = Token.cost_in_tokens(@order.price)
    @order.user.tokens = @order.user.tokens - cost_in_tokens
    @success = @order.user.save
  end

  # Did the purchase finish correctly?
  def successful?
    @success
  end

  # - optional -
  # return a Hash or easily serializable object like a String
  #
  # The return value of this method will be serialized and stored on the `payment_details` attribute
  # of the `Effective::Order`.
  def payment_details
  end
end
```


## License

MIT License.  Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Testing

Run tests by:

```ruby
rspec
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request

