module EffectiveStripeHelper

  STRIPE_CONNECT_AUTHORIZE_URL = 'https://connect.stripe.com/oauth/authorize'
  STRIPE_CONNECT_TOKEN_URL = 'https://connect.stripe.com/oauth/token'

  def is_stripe_connect_seller?(user)
    Effective::Customer.for_user(user).try(:is_stripe_connect_seller?) == true
  end

  def link_to_new_stripe_connect_customer(opts = {})
    client_id = EffectiveOrders.stripe[:connect_client_id]

    raise ArgumentError.new('effective_orders config: stripe.connect_client_id has not been set') unless client_id.present?

    authorize_params = {
      :response_type => :code,
      :client_id => client_id,            # This is the Application's ClientID
      :scope => :read_write,
      :state => {
        :form_authenticity_token => form_authenticity_token,   # Rails standard CSRF
        :redirect_to => URI.encode(request.original_url)  # TODO: Allow this to be customized
      }.to_json
    }

    authorize_url = STRIPE_CONNECT_AUTHORIZE_URL.chomp('/') + '?' + authorize_params.to_query

    options = {}.merge(opts)
    link_to image_tag('/assets/effective_orders/stripe_connect.png'), authorize_url, options
  end

  ### Subscriptions Helpers
  def stripe_plans_collection(plans)
    (plans || []).map { |plan| [stripe_plan_description(plan), plan.id, {'data-amount' => plan.amount}] }
  end

  def stripe_plan_description(plan)
    occurrence = case plan.interval
      when 'weekly'   ; '/week'
      when 'monthly'  ; '/month'
      when 'yearly'   ; '/year'
      when 'week'     ; plan.interval_count == 1 ? '/week' : " every #{plan.interval_count} weeks"
      when 'month'    ; plan.interval_count == 1 ? '/month' : " every #{plan.interval_count} months"
      when 'year'     ; plan.interval_count == 1 ? '/year' : " every #{plan.interval_count} years"
      else            ; plan.interval
    end

    "#{plan.name} - #{ActionController::Base.helpers.number_to_currency(plan.amount / 100.0)} #{plan.currency.upcase}#{occurrence}"
  end

  def stripe_coupon_description(coupon)
    amount = coupon.amount_off.present? ? number_to_currency(coupon.amount_off / 100.0) : "#{coupon.percent_off}%"

    if coupon.duration_in_months.present?
      "#{coupon.id} - #{amount} off for #{coupon.duration_in_months} months"
    else
      "#{coupon.id} - #{amount} off #{coupon.duration}"
    end
  end



end
