require 'spec_helper'

describe Effective::WebhooksController do
  routes { EffectiveOrders::Engine.routes }

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:order) { FactoryGirl.create(:order) }
  let(:buyer) { Effective::Customer.for_user(order.user) }

  let(:event_hash) { event.to_hash }

  describe '#stripe' do
    let(:event) { StripeMock.mock_webhook_event('customer.subscription.created') }

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
    let(:event) { StripeMock.mock_webhook_event('customer.subscription.created') }

    before { buyer.update_attributes(stripe_customer_id: event.data.object.customer) }

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

  describe '#stripe.subscription_deleted' do
    let(:event) { StripeMock.mock_webhook_event('customer.subscription.deleted') }
    let!(:subscription) { FactoryGirl.create(:subscription, customer_id: buyer.id) }

    context 'when customer exists' do
      before do
        buyer.update_attributes(stripe_customer_id: event.data.object.customer)
        subscription.stripe_plan_id = event.data.object.plan.id
        subscription.save(validate: false)
      end

      it 'assigns the existing customer' do
        post :stripe, event_hash
        assigns(:customer).should eq buyer
      end

      it 'should destroy customer subscription' do
        expect { post :stripe, event_hash }.to change { buyer.subscriptions.count }.from(1).to(0)
      end

      it 'should invoke subscription_deleted_callback' do
        controller.should_receive(:subscription_deleted_callback).with(kind_of(Stripe::Event)).once
        post :stripe, event_hash
      end
    end

    context 'when customer does not exist' do
      it 'should not destroy any of subscriptions' do
        expect { post :stripe, event_hash }.not_to change { Effective::Subscription.count }
      end

      it 'should not invoke subscription_deleted_callback' do
        controller.should_not_receive(:subscription_deleted_callback)
        post :stripe, event_hash
      end
    end
  end

  describe '#stripe.invoice_payment_succeeded' do
    let(:event) { StripeMock.mock_webhook_event('invoice.payment_succeeded') }

    context 'when customer exists' do
      before { buyer.update_attributes(stripe_customer_id: event.data.object.customer) }

      context 'when subscription payments present' do
        context 'with renewals' do
          let(:subscription_mock) { double('subscription', status: 'active', start: 1383672652) }
          let(:subscriptions) { double('subscriptions', retrieve: subscription_mock) }

          before { Stripe::Customer.should_receive(:retrieve).and_return(double('customer', subscriptions: subscriptions)) }

          it 'assigns the existing customer, if exists' do
            post :stripe, event_hash
            assigns(:customer).should eq buyer
          end

          it 'should invoke subscription_renewed_callback' do
            controller.should_receive(:subscription_renewed_callback).with(kind_of(Stripe::Event)).once
            post :stripe, event_hash
          end
        end

        context 'without renewals' do
          let(:subscription_mock) { double('subscription', status: 'active', start: 1383759053) }  # start and period.start are equal
          let(:subscriptions) { double('subscriptions', retrieve: subscription_mock) }

          before { Stripe::Customer.should_receive(:retrieve).and_return(double('customer', subscriptions: subscriptions)) }

          it 'should not invoke subscription_renewed_callback' do
            controller.should_not_receive(:subscription_renewed_callback)
            post :stripe, event_hash
          end
        end
      end

      context 'when no subscription payments' do
        let(:event) { StripeMock.mock_webhook_event('invoice.payment_succeeded.without_renewals') }

        it 'should not invoke subscription_renewed_callback' do
          controller.should_not_receive(:subscription_renewed_callback)
          post :stripe, event_hash
        end
      end
    end

    context 'when customer does not exist' do
      it 'should not invoke subscription_renewed_callback' do
        controller.should_not_receive(:subscription_renewed_callback)
        post :stripe, event_hash
      end
    end
  end
end
