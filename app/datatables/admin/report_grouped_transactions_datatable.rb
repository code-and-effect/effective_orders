module Admin
  class ReportGroupedTransactionsDatatable < Effective::Datatable
    bulk_actions do
      bulk_action(
      'Send payment request email to selected orders',
        effective_orders.bulk_send_payment_request_admin_orders_path,
        data: { confirm: 'Send payment request emails?' }
      )

      bulk_action(
      'Send receipt email to selected purchased orders',
        effective_orders.bulk_send_buyer_receipt_orders_path,
        data: { confirm: 'Send receipt emails?' }
      )
    end

    filters do
      unless attributes[:skip_filters]
        scope :all
        scope :purchased

        scope :deferred if EffectiveOrders.deferred_providers.present?

        scope :pending_refunds if EffectiveOrders.refund && !EffectiveOrders.buyer_purchases_refund?
        scope :refunds if EffectiveOrders.refund

        scope :not_purchased
      end
    end

    datatable do
      order :updated_at

      bulk_actions_col

      col :created_at, visible: false
      col :updated_at, visible: false

      col :id, label: 'Number' do |order|
        '#' + order.to_param
      end

      col :purchased_at do |order|
        order.purchased_at&.strftime('%F %H:%M') || ('pending refund' if order.pending_refund?) || ("pending #{order.payment_provider}" if order.deferred?) || 'not purchased'
      end

      if attributes[:user_id].blank?
        col :user, search: :string
        col :billing_name, visible: false
        col :email, visible: false
      end

      col :parent, visible: false, search: :string

      col :cc, visible: false

      if EffectiveOrders.billing_address
        col :billing_address, visible: false
      end

      if EffectiveOrders.shipping_address
        col :shipping_address, visible: false
      end

      col(:order_items, search: :string).search do |collection, term|
        collection.where(id: Effective::OrderItem.where('name ILIKE ?', "%#{term}%").select('order_id'))
      end

      col :payment_method
      col :payment_provider, label: 'Provider', visible: false, search: { collection: EffectiveOrders.admin_payment_providers }
      col :payment_card, label: 'Card', visible: false

      col :subtotal, as: :price, visible: false

      col :tax, as: :price, visible: false
      col(:tax_rate, visible: false) { |order| rate_to_percentage(order.tax_rate) }

      col :surcharge, as: :price, visible: false
      col(:surcharge_percent, visible: false) { |order| rate_to_percentage(order.surcharge_percent) }

      col :total, as: :price

      if EffectiveOrders.collect_note
        col :note, visible: false
      end

      col :note_to_buyer, visible: false
      col :note_internal, visible: false

      actions_col partial: 'admin/orders/datatable_actions', partial_as: :order

      unless attributes[:total] == false
        aggregate :total
      end

    end

    collection do
      scope = Effective::Order.all.deep

      if EffectiveOrders.orders_collection_scope.respond_to?(:call)
        scope = EffectiveOrders.orders_collection_scope.call(scope)
      end

      if attributes[:user_id].present?
        user_klass = (attributes[:user_type].constantize if attributes[:user_type].present?)
        user_klass ||= current_user.class

        user = user_klass.find(attributes[:user_id])
        scope = scope.where(user: user)
      end

      if attributes[:parent_id].present? && attributes[:parent_type].present?
        scope = scope.where(parent_id: attributes[:parent_id], parent_type: attributes[:parent_type])
      end

      scope
    end

  end
end
