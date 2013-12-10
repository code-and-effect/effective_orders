module EffectiveStripeHelper
  def is_stripe_connect_seller?(user)
    Effective::Customer.is_stripe_connect_seller?(user)
  end

  def link_to_new_stripe_connect_customer(opts = {})
    client_id = EffectiveOrders.stripe[:connect_client_id]
    connect_authorize_url = EffectiveOrders.stripe[:connect_authorize_url]

    raise ArgumentError.new('effective_orders config: stripe.connect_client_id has not been set') unless client_id.present?
    raise ArgumentError.new('effective_orders config: stripe.connect_authorize_url has not been set') unless connect_authorize_url.present?

    authorize_params = {
      :response_type => :code,
      :client_id => client_id,            # This is the Application's ClientID
      :scope => :read_write,
      :state => {
        :form_authenticity_token => form_authenticity_token,   # Rails standard CSRF
        :redirect_to => URI.encode(request.original_url)  # TODO: Allow this to be customized
      }.to_json
    }

    authorize_url = connect_authorize_url.chomp('/') + '?' + authorize_params.to_query

    options = {}.merge(opts)
    link_to image_tag('/assets/effective_orders/stripe_connect.png'), authorize_url, options
  end

end
