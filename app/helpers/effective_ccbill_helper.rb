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

  def ccbill_customer_name(order, name = :full_name)
    if order.user.present? && order.user.try(name).present?
      order.user.public_send(name)
    elsif order.billing_address.present?
      order.billing_address.public_send(name)
    end
  end
end

