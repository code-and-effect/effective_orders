if defined?(EffectiveDatatables)
  module Effective
    module Datatables
      class Customers < Effective::Datatable
        table_column :email, :column => 'users.email' do |user|
          mail_to user.email, user.email
        end

        if EffectiveOrders.stripe_enabled
          table_column :stripe_customer_id 
          table_column :stripe_active_card
        end

        if EffectiveOrders.stripe_connect_enabled
          table_column :stripe_connect_access_token 
        end

        if EffectiveOrders.stripe_subscriptions_enabled
          table_column :plans, :label => 'Subscription', :proc => Proc.new { |customer| customer.plans.join(', ') }
        end

        table_column :actions, :sortable => false, :filter => false, :partial => '/admin/customers/actions'

        def collection
          Effective::Customer.customers.joins(:user).select('*').select('users.email AS email')
        end
      end
    end
  end
end
