module EffectiveOrders
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc "Creates an EffectiveOrders initializer in your application."

      source_root File.expand_path("../../templates", __FILE__)

      def self.next_migration_number(dirname)
        if not ActiveRecord::Base.timestamped_migrations
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      def copy_initializer
        template "effective_orders.rb", "config/initializers/effective_orders.rb"
      end

      def create_migration_file
        @orders_table_name = ':' + EffectiveOrders.orders_table_name.to_s
        @order_items_table_name = ':' + EffectiveOrders.order_items_table_name.to_s
        @carts_table_name = ':' + EffectiveOrders.carts_table_name.to_s
        @cart_items_table_name = ':' + EffectiveOrders.cart_items_table_name.to_s
        @customers_table_name = ':' + EffectiveOrders.customers_table_name.to_s
        @subscriptions_table_name = ':' + EffectiveOrders.subscriptions_table_name.to_s

        migration_template '../../../db/migrate/01_create_effective_orders.rb.erb', 'db/migrate/create_effective_orders.rb'
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
