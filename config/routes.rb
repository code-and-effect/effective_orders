EffectiveOrders::Engine.routes.draw do
  scope :module => 'effective' do
    resources :orders, except: [:destroy] do
      member do
        get :purchased
        get :declined
        get :send_buyer_receipt

        post :free if EffectiveOrders.free?
        post :mark_as_paid if EffectiveOrders.mark_as_paid?
        post :pay_by_cheque if EffectiveOrders.cheque?
        post :pretend if EffectiveOrders.pretend?
        post :refund if EffectiveOrders.refunds?
      end

      collection do
        post :bulk_send_buyer_receipt

        post :moneris_postback if EffectiveOrders.moneris?
        post :paypal_postback if EffectiveOrders.paypal?
        post :stripe_charge if EffectiveOrders.stripe?
      end
    end

    post 'orders/:id', to: 'orders#update'

    if EffectiveOrders.subscriptions?
      match 'subscribe', to: 'subscripter#update', via: :post, as: :subscripter

      match 'customer/settings', to: 'customers#edit', as: :customer_settings, via: [:get]
      match 'customer/settings', to: 'customers#update', via: [:patch, :put, :post]
      match 'webhooks/stripe', to: 'webhooks#stripe', via: [:post, :put]
    end

    match 'cart', to: 'carts#show', as: 'cart', via: :get
    match 'cart', to: 'carts#destroy', via: :delete

    # If you Tweak this route, please update EffectiveOrdersHelper too
    match 'cart/:purchasable_type/:purchasable_id', to: 'carts#add_to_cart', via: [:get, :post], as: 'add_to_cart'
    match 'cart/:id', to: 'carts#remove_from_cart', via: [:delete], as: 'remove_from_cart'
  end

  namespace :admin do
    resources :customers, only: [:index, :show]

    resources :orders do
      member do
        post :send_payment_request

        get :checkout
        post :checkout
        patch :checkout
      end

      collection do
        post :bulk_send_payment_request
      end
    end

    post 'orders/:id', to: 'orders#update'

    resources :order_items, only: [:index]
  end
end

Rails.application.routes.draw do
  mount EffectiveOrders::Engine => '/', as: 'effective_orders'
end
