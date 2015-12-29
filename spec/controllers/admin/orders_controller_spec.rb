require 'spec_helper'

describe Admin::OrdersController, type: :controller do
  routes { EffectiveOrders::Engine.routes }

  let(:cart) { FactoryGirl.create(:cart) }

  before { sign_in cart.user }

  describe 'GET #new' do
    it 'should render admin new order page successfully' do
      get :new

      expect(response).to be_successful
      expect(response).to render_template :new
      expect(assigns(:order)).to be_an Effective::Order
      expect(assigns(:order)).to be_new_record
      expect(assigns(:page_title)).to eq 'New Order'
    end
  end

  describe 'POST #create' do
    let(:user) { FactoryGirl.create(:user, billing_address: FactoryGirl.create(:address), shipping_address: FactoryGirl.create(:address)) }

    context 'when success' do
      let(:order_params) { { effective_order: { user_id: user.id, order_items_attributes: { '0' => { purchasable_attributes: { description: 'test product 1', price: '10000' }, quantity: '2', tax_exempt: '1', '_destroy' => 'false' }, '1' => { purchasable_attributes: { description: 'test product 2', price: '30000' }, quantity: '3', tax_exempt: '0', '_destroy' => 'false' } } } } }

      shared_context 'creates objects in db correctly' do
        it 'should create new custom order with pending state' do
          expect { post :create, order_params.merge(commit: button_pressed) }.to change { Effective::Order.count }.from(0).to(1)

          expect(assigns(:order)).to be_persisted
          expect(assigns(:order).custom?).to be_truthy
          expect(assigns(:order).pending?).to be_truthy
          expect(assigns(:order).user).to eq user
          expect(assigns(:order).billing_address).to eq user.billing_address
          expect(assigns(:order).shipping_address).to eq user.shipping_address

          expect(assigns(:order).order_items.count).to eq 2

          first_item = assigns(:order).order_items.sort.first
          expect(first_item).to be_persisted
          expect(first_item.title).to eq 'test product 1'
          expect(first_item.quantity).to eq 2
          expect(first_item.price).to eq 10000
          expect(first_item.tax_exempt).to be_truthy
          expect(first_item.tax_rate).to eq 0.05

          second_item = assigns(:order).order_items.sort.last
          expect(second_item).to be_persisted
          expect(second_item.title).to eq 'test product 2'
          expect(second_item.quantity).to eq 3
          expect(second_item.price).to eq 30000
          expect(second_item.tax_exempt).to be_falsey
          expect(second_item.tax_rate).to eq 0.05
        end

        it 'should create new custom products' do
          expect { post :create, order_params.merge(commit: button_pressed) }.to change { Effective::CustomProduct.count }.from(0).to(2)

          first_product = Effective::CustomProduct.all.sort.first
          expect(first_product.description).to eq 'test product 1'
          expect(first_product.price).to eq 10000

          second_product = Effective::CustomProduct.all.sort.last
          expect(second_product.description).to eq 'test product 2'
          expect(second_product.price).to eq 30000
        end
      end

      context 'when "Save" button is pressed' do
        let(:button_pressed) { 'Save' }

        it_should_behave_like 'creates objects in db correctly'
        
        it 'should redirect to admin orders index page with success message' do
          post :create, order_params.merge(commit: button_pressed)

          expect(response).to be_redirect
          expect(response).to redirect_to EffectiveOrders::Engine.routes.url_helpers.admin_orders_path
          expect(flash[:success]).to eq 'Successfully created custom order'
        end
      end

      context 'when "Save and Add New" button is pressed' do
        let(:button_pressed) { 'Save and Add New' }

        it_should_behave_like 'creates objects in db correctly'

        it 'should redirect to admin new order page with success message' do
          post :create, order_params.merge(commit: button_pressed)

          expect(response).to be_redirect
          expect(response).to redirect_to EffectiveOrders::Engine.routes.url_helpers.new_admin_order_path
          expect(flash[:success]).to eq 'Successfully created custom order'
        end
      end
    end

    context 'when failed' do
      let(:order_params) { { effective_order: { user_id: user.id, order_items_attributes: { '0' => { purchasable_attributes: { description: 'test product 1', price: '0' }, quantity: '2', tax_exempt: '1', '_destroy' => 'false' } } } } }

      shared_context 'does not create objects in db and redirects to admin new order page with danger message' do
        it 'should not create order' do
          expect { post :create, order_params.merge(commit: button_pressed) }.not_to change { Effective::Order.count }

          expect(assigns(:order)).to be_new_record
          expect(assigns(:order).valid?).to be_falsey
          expect(assigns(:order).custom?).to be_truthy
          expect(assigns(:order).pending?).to be_truthy
          expect(assigns(:order).user).to eq user
          expect(assigns(:order).billing_address).to eq user.billing_address
          expect(assigns(:order).shipping_address).to eq user.shipping_address

          expect(assigns(:order).order_items.to_a.count).to eq 1

          item = assigns(:order).order_items.first
          expect(item).to be_new_record
          expect(item.valid?).to be_falsey
          expect(item.title).to eq 'test product 1'
          expect(item.quantity).to eq 2
          expect(item.price).to eq 0
          expect(item.tax_exempt).to be_truthy
          expect(item.tax_rate).to eq 0.05
        end

        it 'should not create product' do
          expect { post :create, order_params.merge(commit: button_pressed) }.not_to change { Effective::CustomProduct.count }
        end

        it 'should render admin new order page with danger message' do
          post :create, order_params.merge(commit: button_pressed)

          expect(response).to be_successful
          expect(response).to render_template :new
          expect(flash[:danger]).to eq 'Unable to create custom order'
        end
      end

      context 'when "Save" button is pressed' do
        let(:button_pressed) { 'Save' }

        it_should_behave_like 'does not create objects in db and redirects to admin new order page with danger message'
      end

      context 'when "Save and Add New" button is pressed' do
        let(:button_pressed) { 'Save and Add New' }

        it_should_behave_like 'does not create objects in db and redirects to admin new order page with danger message'
      end
    end
  end

  describe 'POST #mark_as_paid' do
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
        expect(flash[:success]).to eq 'Order marked as paid successfully'
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
        expect(flash[:danger]).to eq 'Unable to mark order as paid'
      end
    end
  end

  describe 'POST #send_buyer_invoice' do
    let(:user) { FactoryGirl.create(:user, email: 'user@example.com') }
    let(:order) { FactoryGirl.create(:order, user: user) }

    context 'when success' do
      before { Effective::Order.any_instance.should_receive(:send_custom_order_invoice_to_buyer!).once.and_return(true) }

      context 'when referrer page is present' do
        before { request.env['HTTP_REFERER'] = 'where_i_came_from' }

        it 'should redirect to previous page with success message' do
          post :send_buyer_invoice, id: order.to_param

          expect(response).to be_redirect
          expect(response).to redirect_to 'where_i_came_from'
          expect(flash[:success]).to eq 'Successfully sent order invoice to user@example.com'
        end
      end

      context 'when referrer page is not present' do
        it 'should redirect to admin order show page with success message' do
          post :send_buyer_invoice, id: order.to_param

          expect(response).to be_redirect
          expect(response).to redirect_to EffectiveOrders::Engine.routes.url_helpers.admin_order_path(order)
          expect(flash[:success]).to eq 'Successfully sent order invoice to user@example.com'
        end
      end
    end

    context 'when failed' do
      before { Effective::Order.any_instance.should_receive(:send_custom_order_invoice_to_buyer!).once.and_return(false) }

      context 'when referrer page is present' do
        before { request.env['HTTP_REFERER'] = 'where_i_came_from' }

        it 'should redirect to previous page with danger message' do
          post :send_buyer_invoice, id: order.to_param

          expect(response).to be_redirect
          expect(response).to redirect_to 'where_i_came_from'
          expect(flash[:danger]).to eq 'Unable to send order invoice'
        end
      end

      context 'when referrer page is not present' do
        it 'should redirect to admin order show page with danger message' do
          post :send_buyer_invoice, id: order.to_param

          expect(response).to be_redirect
          expect(response).to redirect_to EffectiveOrders::Engine.routes.url_helpers.admin_order_path(order)
          expect(flash[:danger]).to eq 'Unable to send order invoice'
        end
      end
    end
  end
end
