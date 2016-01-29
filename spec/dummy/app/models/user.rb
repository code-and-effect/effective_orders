class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable, :rememberable, :recoverable, :trackable, :validatable, :authentication_keys => [:email]

  acts_as_addressable :billing, :shipping

  attr_accessor :first_name, :last_name

  def to_s
    email
  end
end
