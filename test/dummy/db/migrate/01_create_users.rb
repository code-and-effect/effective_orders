class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      # Devise
      t.string    :encrypted_password, null: false, default: ''
      t.string    :reset_password_token
      t.datetime  :reset_password_sent_at
      t.datetime  :remember_created_at
      t.integer   :sign_in_count, default: 0, null: false
      t.datetime  :current_sign_in_at
      t.datetime  :last_sign_in_at
      t.string    :current_sign_in_ip
      t.string    :last_sign_in_ip
      t.datetime  :confirmed_at
      t.datetime  :confirmation_sent_at
      t.string    :unconfirmed_email

      # User fields
      t.string    :email, null: false, default: ''
      t.string    :first_name
      t.string    :last_name
      t.integer   :roles_mask

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
