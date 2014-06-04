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

        table_column :subscription_types, :column => 'subscription_types'

        table_column :actions, :sortable => false, :filter => false, :partial => '/admin/customers/actions'

        def collection
          Effective::Customer.customers.uniq
            .joins(:user)
            .joins(:subscriptions)
            .select('customers.*')
            .select('users.email AS email')
            .select("array_to_string(array(#{Effective::Subscription.purchased.select('subscriptions.stripe_plan_id').where('subscriptions.customer_id = customers.id').to_sql}), ' ,') AS subscription_types")
            .group('customers.id')
            .group('subscriptions.stripe_plan_id')
            .group('users.email')
        end

        def search_column(collection, table_column, search_term)
          if table_column[:name] == 'subscription_types'
            collection.where('subscriptions.stripe_plan_id ILIKE ?', "%#{search_term}%")
          else
            super
          end
        end

      end
    end
  end
end
