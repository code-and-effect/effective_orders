unless Gem::Version.new(EffectiveDatatables::VERSION) < Gem::Version.new('3.0')
  class EffectiveCustomersDatatable < Effective::Datatable
     datatable do
      order :email

      col :id, visible: false
      col :email, sql_column: 'users.email' do |user|
        mail_to user.email, user.email
      end

      if EffectiveOrders.stripe_enabled
        col :stripe_customer_id
        col :stripe_active_card
      end

      if EffectiveOrders.stripe_connect_enabled
        col :stripe_connect_access_token
      end

      col :subscription_types, sql_column: 'subscription_types'

      actions_col partial: 'admin/customers/actions', partial_as: :customer
    end

    collection do
      Effective::Customer.customers.distinct
        .joins(:user, :subscriptions)
        .select('customers.*, users.email AS email')
        .select("array_to_string(array(#{Effective::Subscription.purchased.select('subscriptions.stripe_plan_id').where('subscriptions.customer_id = customers.id').to_sql}), ' ,') AS subscription_types")
        .group('customers.id, subscriptions.stripe_plan_id, users.email')
    end

    # def search_column(collection, table_column, search_term)
    #   return collection.where('subscriptions.stripe_plan_id ILIKE ?', "%#{search_term}%") if table_column[:name] == 'subscription_types'
    #   super
    # end
  end
end
