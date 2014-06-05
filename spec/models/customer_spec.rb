require 'spec_helper'

require 'stripe_mock'

# # Attributes
describe Effective::Customer do
  let(:customer) { FactoryGirl.create(:customer) }
  let(:user) { FactoryGirl.create(:user) }

  describe 'Customer.for_user' do
    it 'creates a new Customer when passed a new user' do
      c = Effective::Customer.for_user(user)

      c.kind_of?(Effective::Customer).should eq true
      c.persisted?.should eq true
      c.valid?.should eq true
      c.user.should eq user
    end

    it 'returns an existing Customer when passed an existing user' do
      c =  Effective::Customer.for_user(customer.user)
      c.should eq customer
    end
  end

  describe 'Stripe Integration' do
    before { StripeMock.start }
    after { StripeMock.stop }

    describe '#stripe_customer' do
      it 'creates a new Stripe::Customer if one doesnt exist.' do
        stripe_customer = customer.stripe_customer

        stripe_customer.kind_of?(::Stripe::Customer).should eq true

        stripe_customer.email.should eq customer.user.email
        stripe_customer.id.should eq customer.stripe_customer_id
      end

      it 'retrieves an existing Stripe::Customer if exists' do
        # Test set up. Create the user.
        user = customer.user
        stripe_customer = ::Stripe::Customer.create(:email => user.email, :description => user.id.to_s)
        customer.update_attributes(:stripe_customer_id => stripe_customer.id)

        customer.reload

        customer.stripe_customer.id.should eq stripe_customer.id
      end
    end

    describe '#update_card' do
      it 'can update the card' do
        customer.update_card!('sometoken').should eq true
      end

      it 'updates stripe_active_card when updating the card' do
        customer.should_receive(:save!).and_return(true)
        customer.update_card!('sometoken').should eq true

        customer.stripe_active_card.present?.should eq true
      end

    end

  end




end
