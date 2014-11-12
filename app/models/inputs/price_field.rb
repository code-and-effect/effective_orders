module Inputs
  class PriceField
    delegate :content_tag, :text_field_tag, :to => :@template

    def initialize(object, object_name, template, method, opts)
      @object = object
      @object_name = object_name
      @template = template
      @method = method
      @opts = opts
    end

    def to_html
      content_tag(:div, :class => 'input-group') do
        content_tag(:span, '$', :class => 'input-group-addon') +
        text_field_tag(field_name, value, options)
      end
    end

    private

    def field_name
      @object_name + "[#{@method}]"
    end

    def value
      val = @object.send(@method)
      val.kind_of?(Integer) ? ('%.2f' % (val / 100.0)) : ('%.2f' % val)
    end

    def options
      (@opts || {}).tap do |options|
        if options[:class].blank?
          options[:class] = 'numeric'
        elsif options[:class].kind_of?(Array)
          options[:class] << :numeric
        elsif options[:class].kind_of?(String)
          options[:class] << ' numeric'
        end

        options[:pattern] = "[0-9]+(\\.[0-9][0-9]){1}"
        options[:maxlength] = 14
        options[:title] = 'A price formatted like 10000.99, 19.99 or 0.00'
      end
    end
  end
end

