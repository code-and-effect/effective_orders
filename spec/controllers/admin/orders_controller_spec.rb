require 'spec_helper'

describe Admin::OrdersController, type: :controller do
  routes { EffectiveOrders::Engine.routes }

  let(:cart) { FactoryGirl.create(:cart) }

  before { sign_in cart.user }

  describe '#mark_as_paid' do
    let(:order) { FactoryGirl.create(:pending_order) }

    before { request.env['HTTP_REFERER'] = 'where_i_came_from' }

    context 'when success' do
      it 'should update order state and redirect to orders admin index page with success message' do
        post :mark_as_paid, id: order.to_param

        expect(response).to be_redirect
        expect(response).to redirect_to EffectiveOrders::Engine.routes.url_helpers.admin_orders_path
        expect(assigns(:order)).to eq order
        expect(assigns(:order).purchased?).to be_truthy
        expect(assigns(:order).payment).to eq(details: 'Paid by invoice')
        expect(flash[:success]).to eq 'Order marked as paid successfully.'
      end
    end

    context 'when failed' do
      before { Effective::Order.any_instance.stub(:purchase!).and_return(false) }

      it 'should redirect back with danger message' do
        post :mark_as_paid, id: order.to_param

        expect(response).to be_redirect
        expect(response).to redirect_to 'where_i_came_from'
        expect(assigns(:order)).to eq order
        expect(assigns(:order).purchased?).to be_falsey
        expect(flash[:danger]).to eq 'Unable to mark order as paid.'
      end
    end
  end
end
