module EffectiveDeluxeDelayedHelper

  # https://developer.deluxe.com/s/article-hosted-payment-form
  def deluxe_delayed_hosted_payment_form_options(order)
    {
      xtoken: EffectiveOrders.deluxe.fetch(:access_token),
      containerId: "deluxeDelayedCheckout",
      xcssid: "deluxeDelayedCheckoutCss",
      xrtype: "Generate Token",
      xpm: "1", # 0 = CC & ACH, 1 = CC, 2 = ACH
      xautoprompt: false,
      xbtntext: order_checkout_label(:deluxe_delayed)
    }
  end
end
