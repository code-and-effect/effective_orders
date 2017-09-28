# In Rails 4.1 and above, visit:
# http://localhost:3000/rails/mailers
# to see a preview of the following 3 emails:

class EffectiveOrdersMailerPreview < ActionMailer::Preview
  def order_receipt_to_admin
    Effective::OrdersMailer.order_receipt_to_admin(build_preview_order)
  end

  def order_receipt_to_buyer
    Effective::OrdersMailer.order_receipt_to_buyer(build_preview_order)
  end

  def order_receipt_to_seller
    order = build_preview_order
    Effective::OrdersMailer.order_receipt_to_seller(order, preview_customer, order.order_items)
  end

  def payment_request_to_buyer
    Effective::OrdersMailer.payment_request_to_buyer(build_preview_order)
  end

  def pending_order_invoice_to_buyer
    Effective::OrdersMailer.pending_order_invoice_to_buyer(build_preview_order)
  end

  def subscription_payment_succeeded
    Effective::OrdersMailer.subscription_payment_succeeded(preview_customer)
  end

  def subscription_payment_failed
    Effective::OrdersMailer.subscription_payment_failed(preview_customer)
  end

  def subscription_canceled
    Effective::OrdersMailer.subscription_canceled(preview_customer)
  end

  def subscription_trial_expiring
    Effective::OrdersMailer.subscription_trial_expiring(preview_subscribable)
  end

  def subscription_trial_expired
    Effective::OrdersMailer.subscription_trial_expired(preview_subscribable)
  end

  def order_error
    Effective::OrdersMailer.order_error(order: build_preview_order, error: 'Something did not work out')
  end

  protected

  def build_preview_order
    order = Effective::Order.new
    order.user = preview_user
    preview_order_items.each { |atts| order.order_items.build(atts) }
    order.valid?
    order
  end

  def build_address
    Effective::Address.new(category: 'billing', full_name: 'Valued Customer', address1: '1234 Fake Street', address2: 'Suite 200', city: 'Edmonton', state_code: 'AB', country_code: 'CA', postal_code: 'T5T 2T1')
  end

  private

  # We're building Effective::OrderItems directly rather than creating acts_as_purchasable objects
  # so that this mailer will not have to guess at your app's acts_as_purchasable objects
  def preview_order_items
    [
      {title: 'Item One', quantity: 2, price: 999, tax_exempt: false},
      {title: 'Item Two', quantity: 1, price: 25000, tax_exempt: false},
      {title: 'Item Three', quantity: 1, price: 8999, tax_exempt: false},
      {title: 'Item Four', quantity: 1, price: 100000, tax_exempt: false}
    ]
  end

  def preview_user
    User.new(email: 'buyer@website.com').tap do |user|
      user.name = 'Valued Customer' if user.respond_to?(:name=)
      user.full_name = 'Valued Customer' if user.respond_to?(:full_name=)

      if user.respond_to?(:first_name=) && user.respond_to?(:last_name=)
        user.first_name = 'Valued'
        user.last_name = 'Customer'
      end

      user.billing_address = build_address if user.respond_to?(:billing_address=)
    end
  end

  def preview_customer
    Effective::Customer.new(user: preview_user, active_card: '**** **** **** 1234 Visa 04/20')
  end

  def preview_subscribable
    Class.new do
      include ActiveModel::Model
      attr_accessor :buyer

      def to_s
        'My cool service'
      end

      def trial_expires_at
        Time.zone.now + 1.day
      end
    end.new(buyer: preview_user)
  end

end
