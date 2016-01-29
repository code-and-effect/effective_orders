Rails.application.routes.draw do
  mount EffectiveOrders::Engine => '/', :as => 'effective_orders'
end

EffectiveOrders::Engine.routes.draw do
  scope :module => 'effective' do

    match 'orders/:id/purchased', :to => 'orders#purchased', :as => 'order_purchased', :via => :get
    match 'orders/:id/declined', :to => 'orders#declined', :as => 'order_declined', :via => :get
    match 'orders/:id/resend_buyer_receipt', :to => 'orders#resend_buyer_receipt', :via => :get, :as => 'resend_buyer_receipt'
    match 'orders/my_purchases', :to => 'orders#my_purchases', :as => 'my_purchases', :via => :get

    if EffectiveOrders.cheque_enabled
      match 'orders/:id/pay_by_cheque', :to => 'orders#pay_by_cheque', :via => :post, :as => 'pay_by_cheque'
    end

    if EffectiveOrders.paypal_enabled
      match 'orders/paypal_postback', :to => 'orders#paypal_postback', :as => 'paypal_postback', :via => :post
    end

    if EffectiveOrders.moneris_enabled
      match 'orders/moneris_postback', :to => 'orders#moneris_postback', :as => 'moneris_postback', :via => :post
    end

    if EffectiveOrders.stripe_enabled
      match 'orders/stripe_charge', :to => 'orders#stripe_charge', :as => 'stripe_charges', :via => :post
    end

    if EffectiveOrders.stripe_subscriptions_enabled
      resources :subscriptions, :only => [:index, :show, :new, :create, :destroy]
    end

    if EffectiveOrders.stripe_connect_enabled
      match 'orders/stripe_connect_redirect_uri', :to => 'orders#stripe_connect_redirect_uri', :as => 'stripe_connect_redirect_uri', :via => :get
      match 'orders/my_sales', :to => 'orders#my_sales', :as => 'my_sales', :via => :get
    end

    if EffectiveOrders.ccbill_enabled
      match 'orders/ccbill_postback', :to => 'orders#ccbill_postback', :as => 'ccbill_postback', :via => :post
    end

    if EffectiveOrders.app_checkout_enabled
      match 'orders/:id/app_checkout', :to => 'orders#app_checkout', :as => 'app_checkout', :via => :post
    end

    if (Rails.env.development? || Rails.env.test?) || EffectiveOrders.allow_pretend_purchase_in_production
      match 'orders/:id/pretend_purchase', :to => 'orders#pretend_purchase', :as => 'pretend_purchase', :via => [:get, :post]
    end

    resources :orders, :only => [:new, :create, :update, :show, :index]

    match 'cart', :to => 'carts#show', :as => 'cart', :via => :get
    match 'cart', :to => 'carts#destroy', :via => :delete

    # If you Tweak this route, please update EffectiveOrdersHelper too
    match 'cart/:purchasable_type/:purchasable_id', :to => 'carts#add_to_cart', :via => [:get, :post], :as => 'add_to_cart'
    match 'cart/:id', :to => 'carts#remove_from_cart', :via => [:delete], :as => 'remove_from_cart'

    match 'webhooks/stripe', :to => 'webhooks#stripe', :via => [:post, :put]
  end

  if defined?(EffectiveDatatables) && !EffectiveOrders.use_active_admin? || Rails.env.test?
    namespace :admin do
      resources :customers, :only => [:index]
      resources :orders, :only => [:index, :show, :new, :create] do
        member do
          post :send_payment_request
          post :mark_as_paid
        end
      end
      resources :order_items, :only => [:index]
    end
  end
end
