# In Rails 4.1 and above, visit:
# http://localhost:3000/rails/mailers
# to see a preview of the following 3 emails:

class EffectiveOrdersMailerPreview < ActionMailer::Preview
  def order_receipt_to_buyer
    Effective::OrdersMailer.order_receipt_to_buyer(build_preview_order)
  end

  def custom_order_invoice_to_buyer
    Effective::OrdersMailer.custom_order_invoice_to_buyer(build_preview_order)
  end

  def order_receipt_to_admin
    Effective::OrdersMailer.order_receipt_to_admin(build_preview_order)
  end

  # This email is only sent to sellers having sold items via StripeConnect
  def order_receipt_to_seller
    order = build_preview_order
    Effective::OrdersMailer.order_receipt_to_seller(order, preview_customer, order.order_items)
  end

  protected

  def build_preview_order
    order = Effective::Order.new
    order.user = preview_user
    preview_order_items.each { |atts| order.order_items.build(atts) }
    order
  end

  private

  # We're building Effective::OrderItems directly rather than creating acts_as_purchasable objects
  # so that this mailer will not have to guess at your app's acts_as_purchasable objects
  def preview_order_items
    tax_rate = (EffectiveOrders.tax_rate_method.call(Object.new()) rescue -1)
    tax_rate = 0.05 if tax_rate < 0.0

    [
      {title: 'Item One', quantity: 2, price: 999, tax_exempt: false, tax_rate: tax_rate},
      {title: 'Item Two', quantity: 1, price: 25000, tax_exempt: false, tax_rate: tax_rate},
      {title: 'Item Three', quantity: 1, price: 8999, tax_exempt: false, tax_rate: tax_rate},
      {title: 'Item Four', quantity: 1, price: 100000, tax_exempt: false, tax_rate: tax_rate}
    ]
  end

  def preview_user
    User.new(email: 'buyer@example.com').tap do |user|
      user.name = 'Valued Customer' if user.respond_to?(:name=)
      user.full_name = 'Valued Customer' if user.respond_to?(:full_name=)

      if user.respond_to?(:first_name=) && user.respond_to?(:last_name=)
        user.first_name = 'Valued'
        user.last_name = 'Customer'
      end

      if user.respond_to?(:billing_address=)
        user.billing_address = Effective::Address.new(category: 'billing', full_name: 'Test Full Address', address1: 'Test Address 1', address2: 'Test Address 2', city: 'Test City', state_code: 'AB', country_code: 'CA', postal_code: 'AAA AAA')
      end
    end
  end

  def preview_customer
    Effective::Customer.new(user: preview_user)
  end
end
