module EffectiveDeluxeHelper

  # https://developer.deluxe.com/s/article-hosted-payment-form
  def deluxe_hosted_payment_form_options(order)
    customer = Effective::Customer.for_user(order.user || current_user)
    {
      containerId: "deluxeCheckout",
      xtoken: EffectiveOrders.deluxe.fetch(:access_token),
      xrtype: "Generate Token",
      xpm: '1', # 0 = CC & ACH, 1 = CC, 2 = ACH
      token_required: true,
      xautoprompt: false,
      xbtntext: order_checkout_label(:deluxe),
      xcssid: 'deluxeCheckoutCss'
    }
  end
end
