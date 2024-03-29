# Effective Orders

Carts, Orders, and collecting payment via Stripe, PayPal and Moneris.

A Rails Engine to handle the purchase workflow in a Rails application.

Also works with Stripe Subscriptions.

Sends order receipt emails automatically.

Has Order History, My Purchases, My Sales and Admin screens.

## effective_orders 6.0

This is the 6.0 series of effective_orders.

This requires Twitter Bootstrap 4 and Rails 5.1+

Please check out [Effective Orders 3.x](https://github.com/code-and-effect/effective_orders/tree/bootstrap3) for more information using this gem with Bootstrap 3. Deprecated and not maintained.

## Getting Started

Please first install the [effective_addresses](https://github.com/code-and-effect/effective_addresses), [effective_datatables](https://github.com/code-and-effect/effective_datatables) and [effective_bootstrap](https://github.com/code-and-effect/effective_bootstrap) gems.

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
  # name                :string
  # price               :integer, default: 0
  # tax_exempt          :boolean, default: false
  # timestamps

  validates_presence_of :name
  validates_numericality_of :price, greater_than_or_equal_to: 0
end
```

The database migration will look like the following:

```ruby
class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string :name
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

Use an [effective_bootstrap](https://github.com/code-and-effect/effective_bootstrap#effective-price) f.price_field input to enter the price.

It displays the underlying Integer price as a currency formatted value, ensures that a properly formatted price is entered by the user, and POSTs the appropriate Integer value back to the server.

This is available for simple_form, formtastic and Rails default FormBuilder.

```haml
= effective_form_with(model: @product) do |f|
  = f.text_field :name
  = f.checkbox :tax_exempt
  = f.price_field :price
  = f.submit
```

### Products#show

So back on the Product#show page, we will render the product with an Add To Cart link

```haml
%h4= @product
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

Or, hardcode a country and state code:

```ruby
config.order_tax_rate_method = Proc.new { |order| Effective::TaxRateCalculator.new(country_code: 'CA', state_code: 'AB').tax_rate }
```

Please see the initializer file for more information.


### Callbacks

There are three interesting callbacks you can define on the purchasable object, `before_purchase`, `after_purchase` and `after_decline`.

The `before_purchase` callback runs just before the `order` object is saved.  This callback lets you do things in the same transaction the order is saved in.

The `after_purchase` callback runs just after the `order` object is saved. It runs outside and just after the order save transaction.

All three of these callbacks will re-raise any exceptions when in development mode, and swallow them in production.

When defined, upon purchase the following callback will be triggered:

```ruby
class Product
  acts_as_purchasable

  # Will automatically be saved when order is saved
  before_purchase do |order, order_item|
    self.completed_at = Time.zone.now
  end

  # Won't be automatically saved. You need to call save on your own.
  after_purchase do |order, order_item|
    self.completed_at = Time.zone.now
    save!
  end

end
```

## Authorization

All authorization checks are handled via the effective_resources gem found in the `config/initializers/effective_resources.rb` file.

### Permissions

The permissions you actually want to define for a regular user are as follows (using CanCan):

```ruby
can [:manage], Effective::Cart, user_id: user.id

can [:manage], Effective::Order, user_id: user.id # Orders cannot be deleted
cannot [:edit, :update], Effective::Order, status: 'purchased'

can [:manage], Effective::Subscription, user_id: user.id
```

In addition to the above, the following permissions allow access to the `/admin` screens:

```ruby
can :admin, :effective_orders # Can access the admin screens

can :index, :report_transactions
can :index, :report_transactions_grouped_by_name
can :index, :report_transactions_grouped_by_qb_name
can :index, :report_payment_providers

can :index, Admin::ReportTransactionsDatatable
can :index, Admin::ReportTransactionsGroupedByNameDatatable
can :index, Admin::ReportTransactionsGroupedByQbNameDatatable
can :index, Admin::ReportPaymentProvidersDatatable
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

If the configuration options `config.billing_address` and/or `config.shipping_address` options are `true` then the user will be prompted for the appropriate addresses, based on [effective_addresses](https://github.com/code-and-effect/effective_addresses/).

When the user submits the form on this screen, a POST to `effective_orders.order_path` is made, and the `Effective::Order` object is validated and created.

On this final checkout screen, links to all configured payment providers are displayed, and the user may choose which payment processor should be used to make a payment.

The payment processor handles collecting the Credit Card number, and through one way or another, the `Effective::Order` `@order.purchase!` method is called.

Once the order has been marked purchased, the user is redirected to the `effective_orders.purchased_order_path` screen where they see a 'Thank You!' message, and the Order receipt.

If the configuration option `config.send_order_receipt_to_buyer == true` the order receipt will be emailed to the user.

As well, if the configuration option `config.send_order_receipt_to_admin == true` the order receipt will be emailed to the site admin.

The Order has now been purchased.


If you are using effective_orders to roll your own custom payment workflow, you should be aware of the following helpers:

- `render_checkout(order)` to display the standard Checkout step inline.
- `render_checkout(order, purchased_url: '/', declined_url: '/')` to display the Checkout step with custom redirect paths.

- `render_purchasables(one_or_more_acts_as_purchasable_objects)` to display a list of purchasable items

- `render_order(order)` to display the full Order receipt.
- `order_summary(order)` to display some quick details of an Order and its OrderItems.
- `order_payment_to_html(order)` to display the payment processor details for an order's payment transaction.

#### Send Order Receipts in the Background

Emails will be sent immediately unless `config.deliver_method == :deliver_later`.

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

You can skip some buyer validations with the following command:

```ruby
Effective::Order.new(@product, user: @user).purchase!(skip_buyer_validations: true)
```

The `@product` is now considered purchased.


To check an Order's purchase state, you can call `@order.purchased?`

There also exist the scopes: `Effective::Order.purchased` and `Effective::Order.purchased_by(user)` which return a chainable relation of all purchased `Effective::Order` objects.


### My Purchases / Order History

```ruby
= link_to 'Order History', effective_orders.orders_path
```

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


### Subscriptions

All subscriptions are completed via stripe subscriptions.

There is a hardcoded trial mode, that does not reach out to stripe.

Every `acts_as_subscribable` object starts as trial mode.

Every `acts_as_subscribable_buyer` gets a single stripe subscription, and then can buy quantities of stripe products


#### Stripe setup

Create a Product with the name you want customers to see on their receipts

Yearly and a Monthly per team


#### Callbacks

The event is the Stripe event JSON.

```ruby
after_invoice_payment_succeeded do |event|
end

after_invoice_payment_failed do |event|
end

after_customer_subscription_created do |event|
end

after_customer_subscription_updated do |event|
end

after_customer_subscription_deleted do |event|
end

after_customer_updated do |event|
end
```


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

### Overwrite order item names

When an order is purchased, the `purchasable_name()` of each `acts_as_purchasable` object is saved to the database. Normally this is just `to_s`.

If you change the output of `acts_as_purchasable`.`purchasable_name`, any existing order items will remain unchanged.

Run this script to overwrite all saved order item names with the current `acts_as_purchasable`.`purchasable_name`.

```ruby
rake effective_orders:overwrite_order_item_names
```

## Testing in Development

Every payment processor seems to have its own development sandbox which allow you to make test purchases in development mode.

You will need an external IP address to work with these sandboxes.

We suggest the free application `https://ngrok.com/` for this ability.

## Paying with Moneris Checkout

Use the following instructions to set up a Moneris Checkout store.

This is the javascript / pay in place form implementation.

We do not use or implement tokenization of credentials with Moneris Checkout.

We are also going to use ngrok to give us a public facing URL

### Create Test / Development Store

Visit https://esqa.moneris.com/mpg/ and login with: demouser / store1 / password

Or for the prod environment https://www3.moneris.com/mpg

- Select Admin -> Moneris Checkout Config from the menu
- Click Create Profile

Checkout Type: I have my custom order form and want to use Moneris simply for payment processing

Multi-Currency: None

Payment:

- Google Pay: No
- Card Logos: Yes
- Payment Security: CVV
- Transaction Type: Purchase
- Transaction Limits: None

Branding & Design

- Logo Url: None
- Colors: Default

Customizations

- Enable Fullscreen: No false (important)
- Card Borders/Shadows: Yes

Order Confirmation

- Order Confirmation Processing: Use Moneris
- Confirmation Page Content: Check all

Email Communications

- None
- Customer Emails: None


Now copy the Checkout id, something like `chktJF76Btore1` into the config/initializers/effective_orders.rb file.

For the store_id and api_token values, you can use

```
config.moneris_checkout = {
  environment: 'qa',
  store_id: 'store1',
  api_token: 'yesguy1',
  checkout_id: '',  # You need to generate this one
}
```

[Testing a Solution](https://developer.moneris.com/en/More/Testing/Testing%20a%20Solution)

### Create a Production Store

Visit https://www3.moneris.com/mpg and follow the above instructions

The Checkout Id, something like `chktJF76Btore1` is on the configuration page.

The Store Id, something like `gwca12345` should match the login information

To find the Api Token, click Admin -> Store Settings -> and copy the API key there


## Paying via Moneris (hosted pay page - old)

Use the following instructions to set up a Moneris TEST store.

The set up process is identical to a Production store, except that you will need to Sign Up with Moneris and get real credentials.

We are also going to use ngrok to give us a public facing URL

### Create Test / Development Store

Visit https://esqa.moneris.com/mpg/ and login with: demouser / store1 / password

Select Admin -> Hosted Paypage Config from the menu

Click the 'Generate a New Configuration' button which should bring us to a "Hosted Paypage Configuration"

### Basic Configuration

Description: My Test Store

Transaction Type: Purchase

Payment Methods: Credit Cards

Response Method: Sent to your server as a POST

Approved URL: https://myapp.herokuapp.com/orders/moneris_postback

Declined URL: https://myapp.herokuapp.com/orders/moneris_postback

Note: The Approved and Declined URLs must match the effective_orders.moneris_postback_orders_path value in your application. By default it is /orders/moneris_postback

Use 'Enhanced Cancel': false
Use 'Enhanced Response Feedback': false


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

Enable input of Billing, Shipping, and extra data fields on the hosted paypage: false

Display merchant name: true, if you have an SSL cert

Cancel Button Text: Cancel

Cancel Button URL: https://myapp.herokuapp.com/

Click 'Save Appearance Settings'

Click 'Return to main configuration'

### Response/Receipt Data

Click 'Configure Response Fields' from the main Hosted Paypage Configuration

None of the 'Return...' checkboxes are needed. Leave unchecked.

Perform asynchronous data post: false, unchecked

Async Response URL: leave blank

Click 'Save Response Settings'

Click 'Return to main configuration'


### Security

Click 'Configure Security' from the main Hosted Paypage Configuration

Referring URL -> Add URL: https://myapp.herokuapp.com/

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

Credit Card Number: 4502 2850 7000 0007

Expiry Date: Any future date

Some gotchas:

1. When using a test store, there are a whole bunch of ways to simulate failures by posting an order less than $10.00

Please refer to:

https://developer.moneris.com/en/More/Testing/Penny%20Value%20Simulator

The following card will always be approved: 4502 2850 7000 0007
The following card will always be declined: 4355 3100 0257 6375

2. Moneris will not process a duplicate order ID

Once Order id=1 has been purchased/declined, you will be unable to purchase an order with id=1 ever again.

effective_orders works around this by appending a timestamp to the order ID.


## Paying via Stripe

Make sure `gem 'stripe'` is included in your Gemfile.

Add to your application layout / header

```
= javascript_include_tag 'https://js.stripe.com/v3/'
```

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

### Stripe Subscriptions

To set up stripe subscriptions:

Define your model

```ruby
acts_as_subscribable
```

and then in your form, to choose a subscription:

```ruby
= effective_subscription_fields(f, item_wrapper_class: 'col-sm-3')
```

and in your controller:

```ruby
@team.save! && @team.subscripter.save!
```

and in your application controller:

```ruby
before_action :set_subscription_notice

def set_subscription_notice
  return unless team && team.subscription_active? == false

  if team.trial_expired?
    flash.now[:warning] = 'Your trial has expired'
  elsif team.subscription_active? == false
    flash.now[:warning] = 'Your subscription has become unpaid'
  end
end
```

And you can link to the customer#show page

```ruby
link_to 'Customer', effective_orders.customer_settings_path
```

To set up stripe:

1.) Set up a stripe account as above.

2.) Ceate one or more plans. Don't include any trial or trial periods.

3.) Subscription Settings: 3-days. Then 1-day, 3-days, 3-days, then Cancel subscription

4.) Click API -> Webhooks and add an endpoint `root_url/webhooks/stripe`. You will need something like ngrok to test this.

5.) Record the webhook Signing secret in `config.subscriptions[:webhook_secret]`


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


## License

MIT License. Copyright [Code and Effect Inc.](http://www.codeandeffect.com/)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Bonus points for test coverage
6. Create new Pull Request
