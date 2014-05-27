class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :trackable, :validatable, :authentication_keys => [:email]

  acts_as_addressable :billing => {:presence => false, :use_full_name => false}

  structure do
    # Devise attributes
    encrypted_password      :string, :validates => [:presence]
    reset_password_token    :string
    reset_password_sent_at  :datetime
    remember_created_at     :datetime
    confirmation_sent_at    :datetime
    confirmed_at            :datetime
    confirmation_token      :string
    unconfirmed_email       :string
    sign_in_count           :integer, :default => 0
    current_sign_in_at      :datetime
    last_sign_in_at         :datetime
    current_sign_in_ip      :string
    last_sign_in_ip         :string

    email                   :string

    timestamps
  end
end
