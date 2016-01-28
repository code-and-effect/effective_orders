module Effective
  class TaxRateCalculator
    attr_reader :order

    RATES = {
      'CA' => {         # Canada
        'AB' => 5.00,   # Alberta
        'BC' => 5.00,   # British Columbia
        'MB' => 5.00,   # Manitoba
        'NB' => 13.0,   # New Brunswick
        'NL' => 13.0,   # Newfoundland and Labrador
        'NT' => 5.00,   # Northwest Territories
        'NS' => 15.0,   # Nova Scotia
        'ON' => 13.0,   # Ontario
        'PE' => 14.0,   # Prince Edward Island
        'QC' => 5.00,   # Quebec
        'SK' => 5.00,   # Saskatchewan
        'YT' => 5.00,   # Yukon Territory
        'NU' => 5.00    # Nunavut
      }
    }

    def initialize(order:)
      @order = order
    end

    def tax_rate
      return nil unless (order.billing_address.try(:valid?) rescue false)

      country = order.billing_address.country_code
      state = order.billing_address.state_code

      rate = RATES[country]
      return rate if rate.kind_of?(Numeric) || rate.nil?

      rate[state]
    end
  end
end
