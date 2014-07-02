require 'spec_helper'

describe Effective::WebhooksController do
  routes { EffectiveOrders::Engine.routes }

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:order) { FactoryGirl.create(:order) }
  let(:buyer) { Effective::Customer.for_user(order.user) }

  let(:event) { StripeMock.mock_webhook_event('customer.subscription.created') }
  let(:event_hash) { event.to_hash }

  describe '#stripe' do
    it 'retrieves the real event from Stripe based on passed ID' do
      Stripe::Event.should_receive(:retrieve).with(event_hash[:id])
      post :stripe, event_hash
      response.code.should eq '200'
    end

    it 'assigns the @event based on the passed ID' do
      post :stripe, event_hash
      assigns(:event).id.should eq event_hash[:id]
      response.code.should eq '200'
    end

    it 'exits immediately when passed a livemode=false event in Production' do
      event_hash[:livemode] = false
      Rails.env.stub(:production?).and_return(true)

      post :stripe, event_hash
      assigns(:event).should eq nil
      response.code.should eq '200'
    end

    it 'exits immediately when passed a non-object event' do
      event_hash[:object] = 'not-object'

      post :stripe, event_hash
      assigns(:event).should eq nil
      response.code.should eq '200'
    end

  end

  describe '#stripe.subscription_created' do
    before(:each) do
      buyer.update_attributes(:stripe_customer_id => event.data.object.customer)
    end

    it 'assigns the existing customer, if exists' do
      post :stripe, event_hash
      assigns(:customer).should eq buyer
    end

    it 'creates a new purchased Order for the Subscription' do
      Effective::Subscription.any_instance.stub(:valid?).and_return(true)
      Effective::Subscription.any_instance.stub(:purchased?).and_return(false)

      post :stripe, event_hash

      assigns(:order).purchased?.should eq true
      assigns(:order).user.should eq buyer.user
      assigns(:order).payment.to_s.include?(event_hash[:id]).should eq true
    end

    it 'does not create an Order for an existing purchased Subscription' do
      Effective::Subscription.any_instance.stub(:valid?).and_return(true)
      Effective::Subscription.any_instance.stub(:purchased?).and_return(true)

      post :stripe, event_hash

      assigns(:order).present?.should eq false
    end

  end

end
