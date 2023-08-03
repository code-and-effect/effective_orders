class Thing < ApplicationRecord
  acts_as_purchasable

  belongs_to :purchased_by, polymorphic: true, optional: true

  effective_resource do
    title       :string

    price         :integer
    tax_exempt    :boolean
    qb_item_name  :string

    purchased_at  :datetime

    timestamps
  end

  validates :title, presence: true

  def to_s
    title.presence || 'New Thing'
  end

end
