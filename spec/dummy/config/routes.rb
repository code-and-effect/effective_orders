Rails.application.routes.draw do
  devise_for :users
  mount EffectiveOrders::Engine => '/', :as => 'effective_orders'
end
