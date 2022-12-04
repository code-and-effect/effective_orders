# This is a user specific EffectiveOrdersDatatable

class EffectiveOrdersDatatable < Effective::Datatable
  filters do
    unless attributes[:not_purchased]
      scope :all
      scope :purchased

      scope :deferred if EffectiveOrders.deferred_providers.present?
      scope :refunds if EffectiveOrders.refund
      scope :not_purchased
    end
  end

  datatable do
    order :id, :desc

    col :created_at, visible: false
    col :updated_at, visible: false

    col :id, label: 'Number' do |order|
      '#' + order.to_param
    end

    col :parent, visible: false, search: :string

    unless attributes[:not_purchased]
      col :purchased_at do |order|
        order.purchased_at&.strftime('%F %H:%M') || 'not purchased'
      end
    end

    if EffectiveOrders.billing_address
      col :billing_address, visible: false
    end

    if EffectiveOrders.shipping_address
      col :shipping_address, visible: false
    end

    col(:order_items, search: :string).search do |collection, term|
      collection.where(id: Effective::OrderItem.where('name ILIKE ?', "%#{term}%").select('order_id'))
    end

    col :payment_method, visible: false
    col :payment_provider, label: 'Provider', visible: false, search: { collection: EffectiveOrders.payment_providers }
    col :payment_card, label: 'Card', visible: false

    col :subtotal, as: :price, visible: false

    col :tax, as: :price, visible: false
    col(:tax_rate, visible: false) { |order| rate_to_percentage(order.tax_rate) }

    col :surcharge, as: :price, visible: false
    col(:surcharge_percent, visible: false) { |order| rate_to_percentage(order.surcharge_percent) }

    col :total, as: :price

    if EffectiveOrders.collect_note
      col :note
    end

    col :note_to_buyer

    actions_col partial: 'effective/orders/datatable_actions', partial_as: :order
  end

  collection do
    user_klass = (attributes[:user_type].constantize if attributes[:user_type].present?)
    user_klass ||= current_user.class

    user = user_klass.find(attributes[:user_id])

    scope = Effective::Order.all.deep.where(user: user)

    if EffectiveOrders.orders_collection_scope.respond_to?(:call)
      scope = EffectiveOrders.orders_collection_scope.call(scope)
    end

    if attributes[:not_purchased]
      scope = scope.not_purchased
    end

    if attributes[:parent_id].present? && attributes[:parent_type].present?
      scope = scope.where(parent_id: attributes[:parent_id], parent_type: attributes[:parent_type])
    end

    scope
  end

end
