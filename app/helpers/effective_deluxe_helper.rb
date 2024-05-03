module EffectiveDeluxeHelper

  # https://developer.deluxe.com/s/article-hosted-payment-form
  def deluxe_hosted_payment_form_options(order)
    customer = Effective::Customer.for_user(order.user || current_user)

    {
      xtoken: EffectiveOrders.deluxe.fetch(:access_token),
      containerId: "deluxeCheckout",
      xcssid: "deluxeCheckoutCss",
      xrtype: "Generate Token",
      xpm: "1", # 0 = CC & ACH, 1 = CC, 2 = ACH
      xautoprompt: false,
      xbtntext: order_checkout_label(:deluxe),

      # This is for our html form and not part of the HostedPaymentForm options
      token_required: true
    }
  end
end
