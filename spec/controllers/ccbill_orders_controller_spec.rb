require 'spec_helper'

# We're testing the effective/providers/ccbill.rb file, which is included into the OrdersController at runtime

describe Effective::OrdersController, type: :controller do
  routes { EffectiveOrders::Engine.routes }

  let(:order) { FactoryGirl.create(:order) }

  let(:ccbill_params) do
    {
      "customer_fname"=>"Nathan",
      "customer_lname"=>"Feaver",
      "email"=>"nathan@agilestyle.com",
      "username"=>"",
      "password"=>"[FILTERED]",
      "productDesc"=>"Cool Stuff",
      "price"=>"#{ccbill_formatted_price(order.total)} for 365 days",
      "subscription_id"=>"0216026202000000347",
      "denialId"=>"",
      "clientAccnum"=>"999999",
      "clientSubacc"=>"0000",
      "address1"=>"123 Easy St",
      "city"=>"Edmonton",
      "state"=>"AB",
      "country"=>"CA",
      "phone_number"=>"",
      "zipcode"=>"A1B 2C3",
      "start_date"=>"2016-01-26 13:55:44",
      "referer"=>"",
      "ccbill_referer"=>"",
      "affiliate"=>"",
      "reservationId"=>"",
      "referringUrl"=>"http://localhost:3000/orders/833-7014-992",
      "reasonForDecline"=>"",
      "reasonForDeclineCode"=>"",
      "formName"=>"211cc",
      "cardType"=>"VISA",
      "responseDigest"=>"43492c3db3f97944bab31a0f15d486cb",
      "commit"=>"Checkout with CCBill",
      "authenticity_token"=>"96wvM13VjhtNwgCyRZfO03Gn4x2ntgl7GBSn3U51OdwlGLxe2YYNdCHETtGjm8WwikQfRF79/aHF2zmldwsFCA==",
      "order_id"=>order.to_param,
      "utf8"=>"&#195;&#162;&#197;&#147;&#226;&#128;&#156;",
      "typeId"=>"0",
      "initialPrice"=>"10.5",
      "initialPeriod"=>"365",
      "recurringPrice"=>"0",
      "recurringPeriod"=>"0",
      "rebills"=>"0",
      "initialFormattedPrice"=>ccbill_formatted_price(order.total),
      "recurringFormattedPrice"=>"&#36;0.00",
      "ip_address"=>"00.00.000.00"
    }
  end

  let(:ccbill_declined_params) do
    ccbill_params.merge(
      "denialId"=>"",
      "reasonForDecline"=>"Transaction Denied by Bank",
      "reasonForDeclineCode"=>"24",
    )
  end

  def ccbill_formatted_price(price)
    price_in_dollars = price.to_s.insert(-3, '.')
    "&#36;#{price_in_dollars}"
  end

  describe 'ccbill_postback' do
    before do
      sign_in order.user
      allow_any_instance_of(Effective::CcbillPostback).to receive(:verified?).and_return(true)
    end

    describe 'invalid parameters' do
      it 'raises RecordNotFound when passed an unknown order id' do
        expect {
          post :ccbill_postback, ccbill_params.tap { |x| x[:order_id] = 999 }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'declined purchase params' do
      it 'marks an order declined when params[:result] indicate decline'  do
        expect(subject).to receive(:order_declined).and_call_original

        post :ccbill_postback, ccbill_declined_params

        expect(assigns(:order)).to be_declined
      end
    end

    describe 'approved purchase' do
      it 'marks the order as purchased' do
        expect(subject).to receive(:order_purchased).and_call_original

        post :ccbill_postback, ccbill_params

        expect(assigns(:order)).to be_purchased
      end
    end
  end
end
