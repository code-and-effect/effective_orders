module EffectiveDeluxeHelper

  # https://developer.deluxe.com/s/article-hosted-payment-form
  def deluxe_hosted_payment_form_options(order)
    {
      xtoken: EffectiveOrders.deluxe.fetch(:access_token),
      containerId: "deluxeCheckout",
      xcssid: "deluxeCheckoutCss",
      xrtype: "Generate Token",
      xpm: "1", # 0 = CC & ACH, 1 = CC, 2 = ACH
      xautoprompt: false,
      xbtntext: order_checkout_label(:deluxe)
    }
  end
end
