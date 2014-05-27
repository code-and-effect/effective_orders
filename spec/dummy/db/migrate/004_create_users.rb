class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :encrypted_password 
      t.string :reset_password_token 
      t.datetime :reset_password_sent_at 
      t.datetime :remember_created_at 
      t.datetime :confirmation_sent_at 
      t.datetime :confirmed_at 
      t.string :confirmation_token 
      t.string :unconfirmed_email 
      t.integer :sign_in_count, :default=>0 
      t.datetime :current_sign_in_at 
      t.datetime :last_sign_in_at 
      t.string :current_sign_in_ip 
      t.string :last_sign_in_ip 
      t.string :email 
      t.datetime :updated_at 
      t.datetime :created_at 
    end
  end
  
  def self.down
    drop_table :users
  end
end
