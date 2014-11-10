require 'spec_helper'

describe Effective::OrdersController do
  routes { EffectiveOrders::Engine.routes }

  let(:purchased_order) { FactoryGirl.create(:purchased_order) }
  let(:order) { FactoryGirl.create(:order) }

  let(:cart) { FactoryGirl.create(:cart) }
  let(:address) { FactoryGirl.create(:address) }

  let(:billing_address) { FactoryGirl.create(:address) }
  let(:billing_atts) { billing_address.attributes.reject { |k, v| ['id', 'addressable_type', 'addressable_id', 'category', 'updated_at', 'created_at'].include?(k) } }

  let(:shipping_address) { FactoryGirl.create(:address) }
  let(:shipping_atts) { shipping_address.attributes.reject { |k, v| ['id', 'addressable_type', 'addressable_id', 'category', 'updated_at', 'created_at'].include?(k) } }

  let(:valid_order_attributes) do
    {
      :effective_order => {
        :billing_address => billing_atts, :save_billing_address => false,
        :shipping_address => shipping_atts, :save_shipping_address => false,
      }
    }
  end

  it 'uses authenticate_user! to redirect to sign in if not signed in' do
    get :new
    response.should redirect_to '/users/sign_in'
  end

  describe '#new' do
    it 'should assign an @order based off the user cart' do
      sign_in cart.user
      get :new

      assigns(:order).user.should eq cart.user

      assigns(:order).order_items.size.should eq cart.cart_items.size
      assigns(:order).total.should eq cart.total
    end

    it 'redirects if there is an empty order' do
      sign_in cart.user
      cart.cart_items.destroy_all

      get :new

      flash[:danger].downcase.include?('add one or more item to your cart').should eq true
      response.should redirect_to '/cart' # cart_path
    end

    it 'redirects if order total is less than minimum charge' do
      sign_in cart.user
      Effective::CartItem.any_instance.stub(:price).and_return(10)

      get :new

      flash[:danger].downcase.include?('a minimum order of $0.50 is required').should eq true
      response.should redirect_to '/cart' # cart_path
    end
  end

  # "effective_order"=> {
  #   "order_items_attributes"=> {
  #     "0"=> {
  #       "class"=>"Effective::Subscription", "stripe_coupon_id"=>"50OFF", "id"=>"2"}},
  #   "billing_address"=>{"address1"=>"1234 Fake street", "address2"=>"", "city"=>"Edmonton", "country_code"=>"KH", "state_code"=>"1", "postal_code"=>"T5T2T1"},
  #   "save_billing_address"=>"1",
  #   "shipping_address"=>{"address1"=>"123 Shipping street", "address2"=>"", "city"=>"Edmonton", "country_code"=>"KH", "state_code"=>"10", "postal_code"=>"t5t2t1"},
  #   "save_shipping_address"=>"1"},
  #   "commit"=>"Continue Checkout"
  # }

  describe '#create' do
    before(:each) do
      sign_in cart.user
    end

    it 'should assign an @order based off the user cart' do
      post :create

      assigns(:order).user.should eq cart.user
      assigns(:order).order_items.size.should eq cart.cart_items.size
      assigns(:order).total.should eq cart.total
      assigns(:order).purchased?.should eq false
    end

    it 'assign appropriate User fields' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => false,
        :shipping_address => shipping_atts, :save_shipping_address => false,
        :shipping_address_same_as_billing => false,
        :user_attributes => {:first_name => 'First', :last_name => 'Last', :email => 'email@somwhere.com'}
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).user.first_name.should eq 'First'
      assigns(:order).user.last_name.should eq 'Last'
      assigns(:order).user.email.should_not eq 'email@somwhere.com'
    end

    it 'assign addresses to the order and not the user' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => false,
        :shipping_address => shipping_atts, :save_shipping_address => false,
        :shipping_address_same_as_billing => false
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq shipping_atts['address1']

      assigns(:order).user.billing_address.present?.should eq false
      assigns(:order).user.shipping_address.present?.should eq false
    end

    it 'assign addresses to the order and the user' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => true,
        :shipping_address_same_as_billing => false
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq shipping_atts['address1']

      assigns(:order).user.billing_address.address1.should eq billing_atts['address1']
      assigns(:order).user.shipping_address.address1.should eq shipping_atts['address1']

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'does not assign the billing_address to user if save_billing_address is false' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => false,
        :shipping_address => shipping_atts, :save_shipping_address => true,
        :shipping_address_same_as_billing => false
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq shipping_atts['address1']

      assigns(:order).user.billing_address.present?.should eq false
      assigns(:order).user.shipping_address.address1.should eq shipping_atts['address1']

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'does not assign the shipping_address to user if save_shipping_address is false' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => false,
        :shipping_address_same_as_billing => false
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq shipping_atts['address1']

      assigns(:order).user.billing_address.address1.should eq billing_atts['address1']
      assigns(:order).user.shipping_address.present?.should eq false

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'assign billing address to the order shipping_address when shipping_address_same_as_billing' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => true,
        :shipping_address_same_as_billing => true
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq billing_atts['address1']

      assigns(:order).user.billing_address.address1.should eq billing_atts['address1']
      assigns(:order).user.shipping_address.address1.should eq billing_atts['address1']

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'assign billing address to the order shipping_address when shipping_address_same_as_billing and no shipping provided' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address_same_as_billing => true
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq billing_atts['address1']

      assigns(:order).user.billing_address.address1.should eq billing_atts['address1']
      assigns(:order).user.shipping_address.address1.should eq billing_atts['address1']

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'assign billing address to the order shipping_address but not the user when shipping_address_same_as_billing provided' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => false,
        :save_shipping_address => false,
        :shipping_address_same_as_billing => true
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq true

      assigns(:order).billing_address.address1.should eq billing_atts['address1']
      assigns(:order).shipping_address.address1.should eq billing_atts['address1']

      assigns(:order).user.billing_address.present?.should eq false
      assigns(:order).user.shipping_address.present?.should eq false

      response.should redirect_to "/orders/#{assigns(:order).to_param}"
    end

    it 'is invalid when passed an invalid address' do
      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts.tap { |x| x[:address1] = nil }, :save_shipping_address => true,
        :shipping_address_same_as_billing => false
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq false
      assigns(:order).errors[:addresses].present?.should eq true
      assigns(:order).errors[:shipping_address].present?.should eq true

      response.should render_template(:new)
    end

    it 'is invalid when passed an invalid order_item' do
      Effective::OrderItem.any_instance.stub(:valid?).and_return(false)

      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => true,
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq false
      response.should render_template(:new)
    end

    it 'is invalid when passed an invalid user' do
      User.any_instance.stub(:valid?).and_return(false)

      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => true,
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq false
      response.should render_template(:new)
    end

    it 'is invalid when passed an invalid purchasable' do
      Product.any_instance.stub(:valid?).and_return(false)

      post :create, :effective_order => {
        :billing_address => billing_atts, :save_billing_address => true,
        :shipping_address => shipping_atts, :save_shipping_address => true,
      }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq false
      response.should render_template(:new)
    end

    it 'prevents the order from proceeding when missing a required address' do
      post :create, :effective_order => { :billing_address => billing_atts, :save_billing_address => true, :shipping_address_same_as_billing => false }

      (assigns(:order).valid? && assigns(:order).persisted?).should eq false
      assigns(:order).errors[:shipping_address].present?.should eq true

      response.should render_template(:new)
    end
  end

  describe '#create with a Stripe Subscription object' do
    let(:cart_with_subscription) { FactoryGirl.create(:cart_with_subscription) }
    let(:subscription) { cart_with_subscription.cart_items.find { |obj| obj.purchasable.kind_of?(Effective::Subscription)}.purchasable }

    let(:valid_order_with_new_subscription_coupon_attributes) do
      valid_order_attributes.tap { |x| x[:effective_order]['order_items_attributes'] = {'0' => {"class"=>"Effective::Subscription", "stripe_coupon_id"=>"#{::Stripe::Coupon.create().id}", 'id' => "#{subscription.id}"}} }
    end

    before do
      StripeMock.start
      sign_in cart_with_subscription.user
    end

    after { StripeMock.stop }

    it 'has an OrderItem that is a Subscription' do
      post :create, valid_order_attributes
      assigns(:order).persisted?.should eq true

      subscription = assigns(:order).order_items.find { |obj| obj.purchasable.kind_of?(Effective::Subscription) }
      subscription.present?.should eq true
    end

    it 'does not alter the subscription.stripe_coupon_id' do
      post :create, valid_order_attributes
      assigns(:order).persisted?.should eq true

      order_subscription = assigns(:order).order_items.find { |obj| obj.purchasable.kind_of?(Effective::Subscription) }.purchasable
      order_subscription.stripe_coupon_id.should eq subscription.stripe_coupon_id
    end

    it 'updates the subscription.stripe_coupon_id when passed' do
      post :create, valid_order_with_new_subscription_coupon_attributes
      assigns(:order).persisted?.should eq true

      order_subscription = assigns(:order).order_items.find { |obj| obj.purchasable.kind_of?(Effective::Subscription) }.purchasable
      order_subscription.stripe_coupon_id.should_not eq subscription.stripe_coupon_id
    end

    it 'is invalid when passed an invalid coupon code' do
      invalid_coupon_atts = valid_order_with_new_subscription_coupon_attributes.tap { |x| x[:effective_order]['order_items_attributes']['0']['stripe_coupon_id'] = 'SOMETHING INVALID' }

      post :create, invalid_coupon_atts

      assigns(:order).errors['order_items.purchasable'].present?.should eq true
      assigns(:order).errors['order_items.purchasable.stripe_coupon_id'].present?.should eq true
      assigns(:order).persisted?.should eq false
    end
  end

  describe '#order_purchased (with a free order)' do
    before(:each) do
      sign_in cart.user
      cart.cart_items.each { |cart_item| cart_item.purchasable.update_attributes(:price => 0.0) }
    end

    it 'creates a purchased order' do
      post :create, valid_order_attributes
      assigns(:order).purchased?.should eq true
      assigns(:order).payment[:details].should eq 'zero-dollar order'
    end

    it 'destroys the current user cart' do
      post :create, valid_order_attributes

      expect { Effective::Cart.find(cart.id) }.to raise_error(ActiveRecord::RecordNotFound)
      assigns(:cart).cart_items.size.should eq 0
    end

    it 'redirects to the purchased page' do
      post :create, valid_order_attributes
      response.should redirect_to "/orders/#{assigns(:order).to_param}/purchased"
    end
  end

  describe '#show' do

    it 'finds the order by obfuscated ID' do
      sign_in purchased_order.user
      get :show, :id => purchased_order.to_param
      assigns(:order).id.should eq purchased_order.id
    end

    it 'does not find an order by regular ID' do
      sign_in purchased_order.user
      expect { get :show, :id => purchased_order.id }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'renders the show template for a purchased order' do
      sign_in purchased_order.user
      get :show, :id => purchased_order.to_param
      response.should render_template(:show)
    end

    it 'renders the checkout template for a non-purchased order' do
      sign_in order.user
      get :show, :id => order.to_param
      response.should render_template(:checkout)
    end
  end

  describe '#purchased' do
    before(:each) do
      sign_in purchased_order.user
    end

    it 'finds the order by obfuscated ID' do
      get :purchased, :id => purchased_order.to_param
      assigns(:order).id.should eq purchased_order.id
    end

    it 'does not find an order by regular ID' do
      expect { get :purchased, :id => purchased_order.id }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '#declined' do
    before(:each) do
      sign_in purchased_order.user
    end

    it 'finds the order by obfuscated ID' do
      get :declined, :id => purchased_order.to_param
      assigns(:order).id.should eq purchased_order.id
    end

    it 'does not find an order by regular ID' do
      expect { get :declined, :id => purchased_order.id }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

end
