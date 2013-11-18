# Effective Orders

TODO: Description

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

The generator will install an initializer which describes all configuration options and creates two database migrations, one for EffectiveAssets the other for DelayedJob.

If you want to tweak the table name (to use something other than the default 'orders', 'order_items', 'carts', 'cart_items'), manually adjust both the configuration file and the migration now.

Then migrate the database:

```ruby
rake db:migrate
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
