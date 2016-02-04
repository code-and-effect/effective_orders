require 'spec_helper'

# We're testing the effective/providers/stripe.rb file, which is included into the OrdersController at runtime

describe Effective::OrdersController, type: :controller do
  routes { EffectiveOrders::Engine.routes }

  before { StripeMock.start }
  after { StripeMock.stop }

  let(:stripe_helper) { StripeMock.create_test_helper }
  let(:order) { FactoryGirl.create(:order) }
  let(:buyer) { Effective::Customer.for_user(order.user) }
  let(:token) { stripe_helper.generate_card_token }
  let(:stripe_charge_params) do
    {:effective_stripe_charge => {'effective_order_id' => order.to_param, 'token' => token}}
  end

  describe '#stripe_charge' do
    before do
      sign_in order.user
    end

    describe 'invalid parameters' do
      it 'raises RecordNotFound when passed an unknown order id' do
        expect {
          post :stripe_charge, stripe_charge_params.tap { |x| x[:effective_stripe_charge]['effective_order_id'] = 999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'renders the :create action on validation failure' do
        expect(subject).not_to receive(:process_stripe_charge)

        post :stripe_charge, stripe_charge_params.tap { |x| x[:effective_stripe_charge]['token'] = nil }

        flash[:danger].downcase.include?('token').should eq true
        assigns(:stripe_charge).errors[:token].present?.should eq true

        assigns(:order).purchased?.should eq false
        response.should render_template(:checkout_step2)
      end
    end

    describe 'valid parameters' do
      it 'redirects to order_purchase_path on success' do
        post :stripe_charge, stripe_charge_params
        assigns(:order).purchased?.should eq true
        response.should redirect_to "/orders/#{assigns(:order).to_param}/purchased"
      end

      it 'assigns the @stripe_charge, @order and @buyer properly' do
        post :stripe_charge, stripe_charge_params

        assigns(:stripe_charge).valid?.should eq true
        assigns(:stripe_charge).order.should eq order
        assigns(:order).should eq order
        assigns(:buyer).should eq buyer
      end

      it 'calls process_stripe_charge when the stripe_charge form object is valid' do
        expect(subject).to receive(:process_stripe_charge)
        post :stripe_charge, stripe_charge_params
      end

      it 'assigns the buyer a new card based on the passed token' do
        Effective::Customer.any_instance.should_receive(:update_card!).with(token)
        post :stripe_charge, stripe_charge_params
      end

      it 'stores the Stripe::Charge info in the order.payment' do
        post :stripe_charge, stripe_charge_params
        assigns(:order).payment[:charge]['object'].should eq 'charge'
        assigns(:order).payment[:charge]['amount'].should eq order.total
        assigns(:order).payment[:charge]['customer'].should eq buyer.stripe_customer_id
      end
    end

    describe 'stripe charge errors' do
      it 'rollsback the entire transaction when Stripe::Charge fails' do
        StripeMock.prepare_card_error(:card_declined)

        post :stripe_charge, stripe_charge_params

        assigns(:order).purchased?.should eq false
        assigns(:stripe_charge).errors[:base].first.downcase.include?('unable to process order with stripe').should eq true
        assigns(:stripe_charge).errors[:base].first.downcase.include?('the card was declined').should eq true
        response.should render_template(:checkout_step2)
      end
    end
  end

  describe '#stripe_charge with a subscription' do
    let(:order) { FactoryGirl.create(:order_with_subscription) }
    let(:buyer) { Effective::Customer.for_user(order.user) }
    let(:subscription) { order.order_items[1].purchasable }
    let(:token) { stripe_helper.generate_card_token }
    let(:stripe_charge_params) do
      {:effective_stripe_charge => {'effective_order_id' => order.to_param, 'token' => token}}
    end

    before do
      sign_in order.user
    end

    it 'redirects to order_purchase_path on success' do
      post :stripe_charge, stripe_charge_params
      assigns(:order).purchased?.should eq true
      response.should redirect_to "/orders/#{assigns(:order).to_param}/purchased"
    end

    it 'makes a Stripe::Charge for only the non-Subscription OrderItems' do
      post :stripe_charge, stripe_charge_params
      assigns(:order).payment[:charge]['object'].should eq 'charge'
      assigns(:order).payment[:charge]['amount'].should eq order.order_items.first.total
    end

    it 'makes a Stripe::Subscription for the Subscriptions' do
      post :stripe_charge, stripe_charge_params

      assigns(:order).payment[:subscriptions]["#{subscription.stripe_plan_id}"]['object'].should eq 'subscription'
      assigns(:order).payment[:subscriptions]["#{subscription.stripe_plan_id}"]['plan']['id'].should eq subscription.stripe_plan_id
      subscription.reload.stripe_subscription_id.present?.should eq true
      subscription.reload.stripe_coupon_id.present?.should eq true

      Effective::Subscription.find(subscription.id).purchased?.should eq true
    end
  end
end
