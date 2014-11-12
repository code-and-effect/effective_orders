module Inputs
  module PriceFormInput
    def price_field(method, opts = {})
      Inputs::PriceField.new(@object, @object_name, @template, method, opts).to_html
    end
  end
end
