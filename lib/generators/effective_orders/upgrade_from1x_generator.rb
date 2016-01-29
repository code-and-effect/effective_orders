module EffectiveOrders
  module Generators
    class UpgradeFrom1xGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc 'Upgrade effective_orders from the 1.x branch'

      source_root File.expand_path('../../templates', __FILE__)

      def self.next_migration_number(dirname)
        ActiveRecord::Migration.new.next_migration_number(1) #=> “20160114171807"
      end

      def create_migration_file
        @orders_table_name = ':' + EffectiveOrders.orders_table_name.to_s
        @order_items_table_name = ':' + EffectiveOrders.order_items_table_name.to_s
        @carts_table_name = ':' + EffectiveOrders.carts_table_name.to_s
        @cart_items_table_name = ':' + EffectiveOrders.cart_items_table_name.to_s
        @customers_table_name = ':' + EffectiveOrders.customers_table_name.to_s
        @subscriptions_table_name = ':' + EffectiveOrders.subscriptions_table_name.to_s
        @products_table_name = ':' + EffectiveOrders.products_table_name.to_s

        migration_template '../../../db/upgrade/03_upgrade_effective_orders_from1x.rb.erb', 'db/migrate/upgrade_effective_orders_from1x.rb'
      end

      def show_readme
        readme 'README' if behavior == :invoke
      end
    end
  end
end
