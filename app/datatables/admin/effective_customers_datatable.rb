class Admin::EffectiveCustomersDatatable < Effective::Datatable
   datatable do

    col :id, visible: false
    col :user
    col 'user.email'

    if EffectiveOrders.stripe?
      col :stripe_customer_id
      col :active_card
    end

    actions_col do |customer|
      link_to('Manage', "https://dashboard.stripe.com/#{'test/' if Rails.env.development?}customers/#{customer.stripe_customer_id}")
    end

  end

  collection do
    Effective::Customer.joins(:user).all
  end
end
