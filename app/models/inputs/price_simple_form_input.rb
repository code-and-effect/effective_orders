if defined?(SimpleForm)
  class PriceSimpleFormInput < SimpleForm::Inputs::NumericInput
    def input(wrapper_options = nil)
      options = merge_wrapper_options(input_html_options, wrapper_options)
      Inputs::PriceField.new(object, object_name, template, attribute_name, options).to_html
    end
  end
end
