# bundle exec rails generate effective_orders:upgrade_price_column TABLE COLUMN

module EffectiveOrders
  module Generators
    class UpgradePriceColumn < Rails::Generators::Base
      include Rails::Generators::Migration

      desc "Upgrade a table with a decimal column to integer"

      source_root File.expand_path("../../templates", __FILE__)
      argument :table, :type => :string, :default => nil
      argument :column, :type => :string, :default => :price

      def self.next_migration_number(dirname)
        if not ActiveRecord::Base.timestamped_migrations
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      def create_migration_file
        @table = table.to_s.downcase
        @column = column.to_s.downcase

        migration_template '../../../db/upgrade/upgrade_price_column_on_table.rb.erb', "db/migrate/upgrade_price_column_on_#{table}.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end
