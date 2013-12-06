class CreateProducts < ActiveRecord::Migration
  def self.up
    create_table :products do |t|
      t.string    :title
      t.decimal   :price, :precision => 8, :scale => 2, :default => 0.0
      t.boolean   :tax_exempt
      t.string    :quickbooks_item_name

      t.timestamps
    end
  end

  def self.down
    drop_table :products
  end
end
