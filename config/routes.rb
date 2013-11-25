EffectiveOrders::Engine.routes.draw do
  scope '/effective', :module => 'effective' do
    resources :orders, :only => [:new, :create, :index]

    match 'cart', :to => 'carts#show', :as => 'cart', :via => :get
    match 'cart', :to => 'carts#destroy', :via => :delete

    # If you Tweak this route, please update EffectiveOrdersHelper too
    match 'cart/:purchasable_type/:purchasable_id', :to => 'carts#add_to_cart', :via => [:get, :post], :as => 'add_to_cart'

    match 'cart/:id', :to => 'carts#remove_from_cart', :via => [:delete], :as => 'remove_from_cart'
  end
end
