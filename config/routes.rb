EffectiveOrders::Engine.routes.draw do
  acts_as_archived

  scope module: 'effective' do
    resources :orders, except: [:destroy] do
      member do
        get :purchased
        get :deferred
        get :declined
        post :send_order_email_to_buyer

        post :cheque
        post :deluxe              # 1-off payment and purchase
        post :deluxe_delayed      # 1-off payment_intent saving
        post :deluxe_delayed_purchase # Admin action to purchase a delayed order

        post :etransfer
        post :free
        post :mark_as_paid
        post :moneris_checkout
        post :phone
        post :pretend
        post :refund
        post :stripe
      end

      collection do
        post :bulk_send_order_email_to_buyer

        post :moneris_postback
        post :paypal_postback
      end
    end

    post 'orders/:id', to: 'orders#update'

    # Subscriptions
    match 'subscribe', to: 'subscripter#update', via: :post, as: :subscripter
    match 'customer/settings', to: 'customers#edit', as: :customer_settings, via: [:get]
    match 'customer/settings', to: 'customers#update', via: [:patch, :put, :post]
    match 'webhooks/stripe', to: 'webhooks#stripe', via: [:get, :post, :put]

    # Carts
    match 'cart', to: 'carts#show', as: 'cart', via: :get
    match 'cart', to: 'carts#destroy', via: :delete

    # If you Tweak this route, please update EffectiveOrdersHelper too
    match 'cart/:purchasable_type/:purchasable_id', to: 'carts#add_to_cart', via: [:get, :post], as: 'add_to_cart'
    match 'cart/:id', to: 'carts#remove_from_cart', via: [:delete], as: 'remove_from_cart'
  end

  namespace :admin do
    resources :customers, only: [:index, :show]
    resources :item_names, except: [:show, :destroy], concerns: :acts_as_archived

    resources :orders do
      member do
        post :send_payment_request
        post :send_order_email_to_buyer

        delete :void
        post :unvoid

        # GET should be last here
        post :checkout
        patch :checkout
        get :checkout
      end

      collection do
        post :bulk_send_payment_request
      end
    end

    post 'orders/:id', to: 'orders#update'

    resources :order_items, only: [:index]

    resources :order_reports, only: [] do
      collection do
        get :nested_orders
        get :transactions
        get :transactions_grouped_by_name
        get :transactions_grouped_by_qb_name
        get :payment_providers
      end
    end

  end
end

Rails.application.routes.draw do
  mount EffectiveOrders::Engine => '/', as: 'effective_orders'
end
