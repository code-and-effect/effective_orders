Rails.application.routes.draw do
  unless EffectiveOrders.skip_mount_engine
    mount EffectiveOrders::Engine => '/', as: 'effective_orders'
  end
end

EffectiveOrders::Engine.routes.draw do
  scope module: 'effective' do

    resources :orders, except: [:destroy] do
      member do
        get :purchased
        get :declined
        get :resend_buyer_receipt

        post :app_checkout if EffectiveOrders.app_checkout_enabled
        post :free if EffectiveOrders.allow_free_orders
        post :mark_as_paid if EffectiveOrders.mark_as_paid_enabled
        post :pay_by_cheque if EffectiveOrders.cheque_enabled
        post :pretend if EffectiveOrders.allow_pretend_purchase_in_production && Rails.env.production?
        post :pretend if EffectiveOrders.allow_pretend_purchase_in_development && !Rails.env.production?
      end

      collection do
        get :my_purchases

        if EffectiveOrders.stripe_connect_enabled
          get :stripe_connect_redirect_uri # oAuth2
          get :my_sales
        end

        post :ccbill_postback if EffectiveOrders.ccbill_enabled
        post :moneris_postback if EffectiveOrders.moneris_enabled
        post :paypal_postback if EffectiveOrders.paypal_enabled
        post :stripe_charge if EffectiveOrders.stripe_enabled
      end
    end

    if true || EffectiveOrders.stripe_subscriptions_enabled
      resources :subscriptions, only: [:index, :show, :new, :create, :destroy]
      match 'webhooks/stripe', to: 'webhooks#stripe', via: [:post, :put]
      get 'plans', to: 'subscriptions#new', as: :plans
    end

    match 'cart', to: 'carts#show', as: 'cart', via: :get
    match 'cart', to: 'carts#destroy', via: :delete

    # If you Tweak this route, please update EffectiveOrdersHelper too
    match 'cart/:purchasable_type/:purchasable_id', to: 'carts#add_to_cart', via: [:get, :post], as: 'add_to_cart'
    match 'cart/:id', to: 'carts#remove_from_cart', via: [:delete], as: 'remove_from_cart'
  end

  namespace :admin do
    resources :customers, only: [:index]
    resources :orders do
      member do
        post :send_payment_request
        post :checkout
        patch :checkout
      end
    end
    resources :order_items, only: [:index]
  end

end
