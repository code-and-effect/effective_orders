Rails.application.routes.draw do
  scope :module => 'effective' do
    resources :orders
    resources :carts
  end
end
