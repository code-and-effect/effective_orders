require 'spec_helper'

# We're testing the effective/providers/moneris.rb file, which is included into the OrdersController at runtime

describe Effective::OrdersController do
  routes { EffectiveOrders::Engine.routes }

  let(:order) { FactoryGirl.create(:order) }
  let(:moneris_params) do
    {
      :response_order_id => "#{order.to_param}",
      :date_stamp => '2014-10-27',
      :time_stamp => '17:42:31',
      :bank_transaction_id =>'660110910011137660',
      :charge_total => "#{'%.2f' % order.total}",
      :bank_approval_code => '497365',
      :response_code => '027',
      :iso_code => '01',
      :message => 'APPROVED           *                    =',
      :trans_name => 'purchase',
      :cardholder => 'Matt',
      :f4l4 => '4242***4242',
      :card =>'V',
      :expiry_date => '1904',
      :result => '1',
      :rvar_authenticity_token => 'nJQf5RKL9SES4uiQIaj4aMNNdIQayEeauOL44iSppD4=',
      :transactionKey => 'C3kYLXwyMDDFD1ArgxiHFph3wIy1Jx'
    }
  end

  describe 'moneris_postback' do
    before do
      subject.stub(:send_moneris_verify_request).and_return('')  # Dont actually make Moneris requests
      sign_in order.user
    end

    describe 'invalid parameters' do
      it 'raises RecordNotFound when passed an unknown order id' do
        expect {
          post :moneris_postback, moneris_params.tap { |x| x[:response_order_id] = 999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'declined purchase params' do
      it 'marks an order declined when params[:result] indicate decline'  do
        subject.should_not_receive(:send_moneris_verify_request)
        subject.should_not_receive(:parse_moneris_response)

        post :moneris_postback, moneris_params.tap { |x| x[:result] = 'null' }

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).declined?.should eq true
      end

      it 'marks an order declined when params[:transactionKey] is blank'  do
        post :moneris_postback, moneris_params.tap { |x| x.delete(:transactionKey) }

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).declined?.should eq true
      end
    end

    describe 'successful purchase params' do
      it 'sends a moneris verify request when passed successful purchase params'  do
        subject.should_receive(:send_moneris_verify_request)
        subject.should_receive(:parse_moneris_response)

        post :moneris_postback, moneris_params
      end
    end

    describe 'transaction verification step' do
      it 'marks the order as purchased when response code is valid' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 1}) # success

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/purchased"
        assigns(:order).purchased?.should eq true
      end

      it 'marks order declined when response_code = null' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 'null'}) # failure

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
        assigns(:order).declined?.should eq true
      end

      it 'marks order declined when response_code blank' do
        subject.stub(:parse_moneris_response).and_return({}) # failure

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
        assigns(:order).declined?.should eq true
      end

      it 'marks order declined when response_code = 0' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 0}) # failure
        post :moneris_postback, moneris_params
        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
      end

      it 'marks order declined when response_code = 50' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 50}) # failure
        post :moneris_postback, moneris_params
        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
      end
    end

    describe 'redirect urls' do
      it 'redirects to the purchased_redirect_url on purchase' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 1}) # success
        post :moneris_postback, moneris_params.tap { |x| x[:rvar_purchased_redirect_url] = '/something' }
        response.should redirect_to '/something'
      end

      it 'redirects to the declined_redirect_url on decline' do
        subject.stub(:parse_moneris_response).and_return({:response_code => 'null'}) # nope
        post :moneris_postback, moneris_params.tap { |x| x[:rvar_declined_redirect_url] = '/something' }
        response.should redirect_to '/something'
      end
    end

  end
end


  # describe '#stripe_charge' do
  #   before do
  #     sign_in order.user
  #   end

  #   describe 'invalid parameters' do
  #     it 'raises RecordNotFound when passed an unknown order id' do
  #       expect {
  #         post :stripe_charge, stripe_charge_params.tap { |x| x[:effective_stripe_charge]['effective_order_id'] = 999 }
  #       }.to raise_error(ActiveRecord::RecordNotFound)
  #     end

  #     it 'renders the :create action on validation failure' do
  #       subject.should_not_receive(:process_stripe_charge)

  #       post :stripe_charge, stripe_charge_params.tap { |x| x[:effective_stripe_charge]['token'] = nil }

  #       flash[:danger].downcase.include?('token').should eq true
  #       assigns(:stripe_charge).errors[:token].present?.should eq true

  #       assigns(:order).purchased?.should eq false
  #       response.should render_template(:checkout)
  #     end
  #   end

  #   describe 'valid parameters' do
  #     it 'redirects to order_purchase_path on success' do
  #       post :stripe_charge, stripe_charge_params
  #       assigns(:order).purchased?.should eq true
  #       response.should redirect_to "/orders/#{assigns(:order).to_param}/purchased"
  #     end

  #     it 'assigns the @stripe_charge, @order and @buyer properly' do
  #       post :stripe_charge, stripe_charge_params

  #       assigns(:stripe_charge).valid?.should eq true
  #       assigns(:stripe_charge).order.should eq order
  #       assigns(:order).should eq order
  #       assigns(:buyer).should eq buyer
  #     end

  #     it 'calls process_stripe_charge when the stripe_charge form object is valid' do
  #       subject.should_receive(:process_stripe_charge)
  #       post :stripe_charge, stripe_charge_params
  #     end

  #     it 'assigns the buyer a new card based on the passed token' do
  #       Effective::Customer.any_instance.should_receive(:update_card!).with(token)
  #       post :stripe_charge, stripe_charge_params
  #     end

  #     it 'stores the Stripe::Charge info in the order.payment' do
  #       post :stripe_charge, stripe_charge_params
  #       assigns(:order).payment[:charge]['object'].should eq 'charge'
  #       assigns(:order).payment[:charge]['amount'].should eq (order.total*100).to_i
  #       assigns(:order).payment[:charge]['customer'].should eq buyer.stripe_customer_id
  #     end
  #   end

  #   describe 'stripe charge errors' do
  #     it 'rollsback the entire transaction when Stripe::Charge fails' do
  #       StripeMock.prepare_card_error(:card_declined)

  #       post :stripe_charge, stripe_charge_params

  #       assigns(:order).purchased?.should eq false
  #       assigns(:stripe_charge).errors[:base].first.downcase.include?('unable to process order with stripe').should eq true
  #       assigns(:stripe_charge).errors[:base].first.downcase.include?('the card was declined').should eq true
  #       response.should render_template(:checkout)
  #     end
  #   end
  # end

  # describe '#stripe_charge with a subscription' do
  #   let(:order) { FactoryGirl.create(:order_with_subscription) }
  #   let(:buyer) { Effective::Customer.for_user(order.user) }
  #   let(:subscription) { order.order_items[1].purchasable }
  #   let(:token) { 'tok_123456789' }
  #   let(:stripe_charge_params) do
  #     {:effective_stripe_charge => {'effective_order_id' => order.to_param, 'token' => token}}
  #   end

  #   before do
  #     sign_in order.user
  #   end

  #   it 'redirects to order_purchase_path on success' do
  #     post :stripe_charge, stripe_charge_params
  #     assigns(:order).purchased?.should eq true
  #     response.should redirect_to "/orders/#{assigns(:order).to_param}/purchased"
  #   end

  #   it 'makes a Stripe::Charge for only the non-Subscription OrderItems' do
  #     post :stripe_charge, stripe_charge_params
  #     assigns(:order).payment[:charge]['object'].should eq 'charge'
  #     assigns(:order).payment[:charge]['amount'].should eq (order.order_items.first.total * 100).to_i
  #   end

  #   it 'makes a Stripe::Subscription for the Subscriptions' do
  #     post :stripe_charge, stripe_charge_params

  #     assigns(:order).payment[:subscriptions]["#{subscription.stripe_plan_id}"]['object'].should eq 'subscription'
  #     assigns(:order).payment[:subscriptions]["#{subscription.stripe_plan_id}"]['plan'].should eq subscription.stripe_plan_id
  #     subscription.reload.stripe_subscription_id.present?.should eq true
  #     subscription.reload.stripe_coupon_id.present?.should eq true

  #     Effective::Subscription.find(subscription.id).purchased?.should eq true
  #   end
  # end
#end
