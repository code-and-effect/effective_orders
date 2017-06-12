require 'spec_helper'

# We're testing the effective/providers/moneris.rb file, which is included into the OrdersController at runtime

describe Effective::OrdersController, type: :controller do
  routes { EffectiveOrders::Engine.routes }

  let(:order) { FactoryGirl.create(:order) }
  let(:moneris_params) do
    {
      response_order_id: "#{order.to_param}",
      date_stamp: '2014-10-27',
      time_stamp: '17:42:31',
      bank_transaction_id:'660110910011137660',
      charge_total: "#{'%.2f' % order.total}",
      bank_approval_code: '497365',
      response_code: '027',
      iso_code: '01',
      message: 'APPROVED           *                    =',
      trans_name: 'purchase',
      cardholder: 'Matt',
      f4l4: '4242***4242',
      card:'V',
      expiry_date: '1904',
      result: '1',
      rvar_authenticity_token: 'nJQf5RKL9SES4uiQIaj4aMNNdIQayEeauOL44iSppD4=',
      transactionKey: 'C3kYLXwyMDDFD1ArgxiHFph3wIy1Jx'
    }
  end

  describe 'moneris_postback' do
    before do
      allow(subject).to receive(:send_moneris_verify_request).and_return('') # Don't actually make Moneris requests
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
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 1}) # success

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/purchased"
        assigns(:order).purchased?.should eq true
      end

      it 'marks order declined when response_code = null' do
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 'null'}) # failure

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
        assigns(:order).declined?.should eq true
      end

      it 'marks order declined when response_code blank' do
        allow(subject).to receive(:parse_moneris_response).and_return({}) # failure

        post :moneris_postback, moneris_params

        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
        assigns(:order).declined?.should eq true
      end

      it 'marks order declined when response_code = 0' do
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 0}) # failure
        post :moneris_postback, moneris_params
        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
      end

      it 'marks order declined when response_code = 50' do
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 50}) # failure
        post :moneris_postback, moneris_params
        response.should redirect_to "/orders/#{order.to_param}/declined"
        assigns(:order).purchased?.should eq false
      end
    end

    describe 'redirect urls' do
      it 'redirects to the purchased_url on purchase' do
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 1}) # success
        post :moneris_postback, moneris_params.tap { |x| x[:rvar_purchased_url] = '/something' }
        response.should redirect_to '/something'
      end

      it 'redirects to the declined_url on decline' do
        allow(subject).to receive(:parse_moneris_response).and_return({response_code: 'null'}) # failure
        post :moneris_postback, moneris_params.tap { |x| x[:rvar_declined_url] = '/something' }
        response.should redirect_to '/something'
      end
    end

  end
end
