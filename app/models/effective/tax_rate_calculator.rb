module Effective
  class TaxRateCalculator
    attr_reader :order, :country_code, :state_code

    RATES = {
      'CA' => {         # Canada
        'AB' => 5.00,   # Alberta
        'BC' => 5.00,   # British Columbia
        'MB' => 5.00,   # Manitoba
        'NB' => 15.0,   # New Brunswick
        'NL' => 15.0,   # Newfoundland and Labrador
        'NT' => 5.00,   # Northwest Territories
        'NS' => 15.0,   # Nova Scotia
        'ON' => 13.0,   # Ontario
        'PE' => 15.0,   # Prince Edward Island
        'QC' => 5.00,   # Quebec
        'SK' => 5.00,   # Saskatchewan
        'YT' => 5.00,   # Yukon Territory
        'NU' => 5.00    # Nunavut
      }
    }

    def initialize(order: nil, country_code: nil, state_code: nil)
      @order = order
      @country_code = country_code
      @state_code = state_code

      raise 'expected an order, or a country and state code' unless (order || country_code)
      raise 'expected an order OR a country and state code. Not both.' if (order && country_code)
    end

    def tax_rate
      country = country_code
      country ||= order.billing_address.country_code if order.billing_address.present?
      country ||= order.user.billing_address.country_code if order.user.respond_to?(:billing_address) && order.user.billing_address.present?

      state = state_code
      state ||= order.billing_address.state_code if order.billing_address.present?
      state ||= order.user.billing_address.state_code if order.user.respond_to?(:billing_address) && order.user.billing_address.present?

      rate = RATES[country]
      return rate if rate.kind_of?(Numeric)
      return unknown_tax_rate() if rate.nil?

      rate[state].presence || unknown_tax_rate()
    end

    def unknown_tax_rate
      (order && order.skip_buyer_validations?) ? nil : 0
    end

  end
end
