module Effective
  class SoldOutValidator < ActiveModel::Validator
    def validate(record)
      record.errors[:base] << "sold out" if record.sold_out?
    end
  end
end
