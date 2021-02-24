class Admin::EffectiveCustomersDatatable < Effective::Datatable
   datatable do

    col :id, visible: false

    col :user, search: :string

    col :email do |customer|
      customer.user.email
    end

    if EffectiveOrders.stripe?
      col :stripe_customer_id
      col :active_card
    end

    actions_col do |customer|
      link_to('Manage', "https://dashboard.stripe.com/#{'test/' if Rails.env.development?}customers/#{customer.stripe_customer_id}")
    end

  end

  collection do
    Effective::Customer.includes(:user).all
  end
end
