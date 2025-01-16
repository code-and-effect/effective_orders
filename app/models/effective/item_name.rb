# frozen_string_literal: true
#
# This is a CRUD model to populate the select field to choose qb_item_name on acts_as_purchasable objects.

module Effective
  class ItemName < ActiveRecord::Base
    self.table_name = (EffectiveOrders.item_names_table_name || :item_names).to_s

    acts_as_archived
    log_changes if respond_to?(:log_changes)

    effective_resource do
      name       :string
      archived   :boolean

      timestamps
    end

    scope :sorted, -> { order(:name) }

    validates :name, uniqueness: true, presence: true

    def to_s
      name.presence || model_name.human
    end

  end
end
