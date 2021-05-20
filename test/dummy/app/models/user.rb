class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

  scope :last_name_user, -> { where(last_name: 'User') }
  scope :last_name_nil, -> { where(last_name: nil) }

  scope :first_name_test, -> { where(first_name: 'Test') }
  scope :first_name_nil, -> { where(first_name: nil) }
end
