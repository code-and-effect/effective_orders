module EffectiveCcbillHelper
  def ccbill_form_digest(order)
    digested_variables = [
      ccbill_price(order.total),
      EffectiveOrders.ccbill[:form_period],
      EffectiveOrders.ccbill[:currency_code],
      EffectiveOrders.ccbill[:dynamic_pricing_salt]
    ]
    string = digested_variables.join('')
    Digest::MD5.hexdigest(string)
  end

  def ccbill_price(price)
    number_to_currency(price/100.0, unit: '')
  end
end

