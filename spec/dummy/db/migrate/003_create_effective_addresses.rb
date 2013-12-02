class CreateEffectiveAddresses < ActiveRecord::Migration
  def self.up
    create_table :addresses do |t|
      t.string :addressable_type
      t.integer :addressable_id
      t.string :category, :limit => 64
      t.string :full_name
      t.string :address1
      t.string :address2
      t.string :city
      t.string :state_code
      t.string :country_code
      t.string :postal_code
      t.datetime :updated_at
      t.datetime :created_at
    end
    add_index :addresses, [:addressable_type, :addressable_id]
    add_index :addresses, :addressable_id
  end

  def self.down
    drop_table :addresses
  end
end
