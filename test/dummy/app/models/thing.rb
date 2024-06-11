class Thing < ApplicationRecord
  acts_as_purchasable

  belongs_to :purchased_by, polymorphic: true, optional: true

  attr_accessor :before_defer_value
  attr_accessor :after_defer_value
  attr_accessor :before_purchase_value
  attr_accessor :after_purchase_value

  effective_resource do
    title       :string

    price         :integer
    tax_exempt    :boolean
    qb_item_name  :string

    purchased_at  :datetime

    timestamps
  end

  validates :title, presence: true

  before_defer { self.before_defer_value = true }
  after_defer { self.after_defer_value = true }
  before_purchase { self.before_purchase_value = true }
  after_purchase { self.after_purchase_value = true }

  def to_s
    title.presence || 'New Thing'
  end

end
