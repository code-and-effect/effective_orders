require 'spec_helper'

describe Effective::CartsController do
  routes { EffectiveOrders::Engine.routes }

  let(:user) { FactoryGirl.create(:user) }
  let(:cart) { FactoryGirl.create(:cart) }
  let(:product) { FactoryGirl.create(:product) }

  describe 'First time user - not logged in' do
    it 'creates a new cart and set the session[:cart]' do
      get :show
      assigns(:cart).id.should eq session[:cart]
      assigns(:cart).size.should eq 0
    end

    it 'allows me to add_to_cart' do
      get :add_to_cart, :purchasable_type => product.class, :purchasable_id => product.id
      assigns(:cart).size.should eq 1
      assigns(:cart).find(product).present?.should eq true
    end

    it 'allow me to remove_from_cart' do
      get :add_to_cart, :purchasable_type => product.class, :purchasable_id => product.id
      assigns(:cart).size.should eq 1
      assigns(:cart).find(product).present?.should eq true

      delete :remove_from_cart, :id => assigns(:cart).cart_items.first.id
      assigns(:cart).reload.size.should eq 0
      assigns(:cart).find(product).present?.should eq false
    end

    it 'allow me to destroy the cart' do
      get :add_to_cart, :purchasable_type => product.class, :purchasable_id => product.id
      assigns(:cart).size.should eq 1

      delete :destroy
      response.should redirect_to('/cart')

      # This redirects me, and reassigns the @cart
      assigns(:cart).size.should eq 0
    end
  end

  describe 'Logging in' do
    describe 'with no previous cart' do
      it 'assigns a new cart and unsets session[:cart]' do
        session[:cart] = 12
        sign_in user

        get :show

        assigns(:cart).user.should eq user
        assigns(:cart).size.should eq 0

        session[:cart].should eq nil
      end
    end

    describe 'with an existing cart' do
      it 'assigns me the existing cart' do
        sign_in cart.user
        get :show
        assigns(:cart).should eq cart
        assigns(:cart).size.should eq 3 # As per our factory
        session[:cart].should eq nil
      end
    end

    describe 'with no existing user cart, and a session cart full of items' do
      it 'copies the session cart items into the user cart' do
        get :show
        assigns(:cart).id.should eq session[:cart]
        assigns(:cart).size.should eq 0

        get :add_to_cart, :purchasable_type => product.class, :purchasable_id => product.id
        assigns(:cart).size.should eq 1
        assigns(:cart).find(product).present?.should eq true

        sign_in user 
        controller.instance_variable_set(:@cart, nil) # This is what happens in a real RailsController. zzz.

        get :show

        assigns(:cart).user.should eq user
        assigns(:cart).size.should eq 1
        assigns(:cart).find(product).present?.should eq true
      end
    end

    describe 'with an existing user cart, and a session cart full of items' do
      it 'merges the session cart into the user cart and destroy the session cart' do
        get :show
        session_cart = session[:cart]

        assigns(:cart).id.should eq session[:cart]
        assigns(:cart).size.should eq 0

        get :add_to_cart, :purchasable_type => product.class, :purchasable_id => product.id
        assigns(:cart).size.should eq 1
        assigns(:cart).find(product).present?.should eq true

        sign_in cart.user 
        controller.instance_variable_set(:@cart, nil) # This is what happens in a real RailsController. zzz.

        get :show
        assigns(:cart).user.should eq cart.user
        assigns(:cart).size.should eq 4 # the 3 from my factory, and 1 more we just created
        assigns(:cart).find(product).present?.should eq true

        Effective::Cart.where(:id => session_cart).should eq []
      end
    end
  end

  describe '#add_to_cart' do
    before(:each) do
      sign_in cart.user
    end

    it 'provides a useful error when passed an unknown purchasable_id' do
      get :add_to_cart, :purchasable_type => product.class, :purchasable_id => 'asdf'

      assigns(:purchasable).should eq nil
      flash[:alert].include?('Unable to add item').should eq true
    end

    it 'provides a useful error when passed an unknown purchasable_type' do
      get :add_to_cart, :purchasable_type => 'Something', :purchasable_id => product.id

      assigns(:purchasable).should eq nil
      flash[:alert].include?('Unable to add item').should eq true
    end
  end

  describe '#remove_from_cart' do
    it 'throws ActiveRecord::RecordNotFound when passed an invalid ID' do
      expect { delete :remove_from_cart, :id => 12345 }.to raise_error(ActiveRecord::RecordNotFound)
      assigns(:cart_item).should eq nil
    end
  end

end
