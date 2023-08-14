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
    end

    def tax_rate
      country = country_code
      state = state_code

      if order.present?
        country ||= order.billing_address.try(:country_code)
        country ||= order.organization.try(:billing_address).try(:country_code)
        country ||= order.user.try(:billing_address).try(:country_code)

        state ||= order.billing_address.try(:state_code)
        state ||= order.organization.try(:billing_address).try(:state_code)
        state ||= order.user.try(:billing_address).try(:state_code)
      end

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
