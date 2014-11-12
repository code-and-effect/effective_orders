# This allows the app to call f.input :something, :as => :price
# in either Formtastic or SimpleForm, but not both at the same time

if defined?(SimpleForm)
  class PriceInput < SimpleForm::Inputs::NumericInput
    def input(wrapper_options = nil)
      options = merge_wrapper_options(input_html_options, wrapper_options)
      Inputs::PriceField.new(object, object_name, template, attribute_name, options).to_html
    end
  end
elsif defined?(Formtastic)
  class PriceInput < Formtastic::Inputs::NumberInput
    def to_html
      input_wrapping do
        label_html << Inputs::PriceField.new(@object, @object_name, @template, @method, @options).to_html
      end
    end
  end
end
