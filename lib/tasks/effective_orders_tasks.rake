# desc "Explaining what the task does"
# task :effective_orders do
#   # Task goes here
# end

namespace :effective_orders do
  task :upgrade_price_column_on_table, [:table] => :environment do |t, args|
    if args.table.blank?
      abort 'Please call with bundle exec rake effective_orders:upgrade_price_column_on_table[products]'
    end

    table = args.table.to_sym
    connection = ActiveRecord::Base.connection

    print "upgrading #{table}..."

    prices = connection.execute("SELECT price from #{table} LIMIT 10").values.flatten
    if prices.blank? || prices.any? { |price| price.to_s.include?('.') }
      connection.execute("UPDATE #{table} O SET price = (O.price * 100.0)")
      connection.change_column(table, :price, :integer, :default => 0)
      print "success"
    else
      print 'looks like the price column is already an integer. skipping.'
    end

    puts ''
  end

  task :upgrade_from_03x => :environment do
    Rake::Task['effective_orders:upgrade_price_column_on_table'].invoke(EffectiveOrders.order_items_table_name.to_s)
    Rake::Task['effective_orders:upgrade_price_column_on_table'].reenable
    Rake::Task['effective_orders:upgrade_price_column_on_table'].invoke(EffectiveOrders.subscriptions_table_name.to_s)
  end

end
