if defined?(Formtastic)
  class PriceFormtasticInput < Formtastic::Inputs::NumberInput
    def to_html
      input_wrapping do
        label_html << Inputs::PriceField.new(@object, @object_name, @template, @method, @options).to_html
      end
    end
  end
end
