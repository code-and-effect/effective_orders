namespace :effective_orders do
  desc 'Overwrite all order item titles with current acts_as_purchasable object title'
  task overwrite_order_item_titles: :environment do
    puts 'WARNING: this task will overwrite all existing order items with new titles. Proceed? (y/n)'
    (puts 'Aborted' and exit) unless STDIN.gets.chomp.downcase == 'y'

    Effective::OrderItem.transaction do
      begin

        Effective::OrderItem.includes(:purchasable).find_each do |order_item|
          new_title = order_item.purchasable.title

          unless new_title
            raise "acts_as_purchasable object #{order_item.purchasable_type.try(:classify)}<#{order_item.purchasable_id}>.title() from Effective::OrderItem<#{order_item.id}> cannot be nil."
          end

          order_item.update_column(:title, new_title) # This intentionally skips validation
        end

        puts 'Successfully updated all order item titles.'
      rescue => e
        puts "An error has occurred: #{e.message}"
        puts "(effective_orders) Rollback. No order item titles have been changed."
        raise ActiveRecord::Rollback
      end
    end
  end
end
