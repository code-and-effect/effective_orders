class CreateThings < ActiveRecord::Migration[4.2]
  def self.up
    create_table :things do |t|
      t.integer   :purchased_order_id

      t.integer   :purchased_by_id
      t.string    :purchased_by_type

      t.string    :title

      t.integer   :price
      t.boolean   :tax_exempt, default: false
      t.string    :qb_item_name

      t.datetime  :purchased_at

      t.timestamps
    end
  end

  def self.down
    drop_table :things
  end

end
