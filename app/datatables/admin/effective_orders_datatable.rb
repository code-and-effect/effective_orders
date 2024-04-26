module Admin
  class EffectiveOrdersDatatable < Effective::Datatable
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
        scope :voided

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

      col :status

      col :purchased_at do |order|
        order.purchased_at&.strftime('%F %H:%M') || ('pending refund' if order.pending_refund?) || ("pending #{order.payment_provider}" if order.deferred?) || 'not purchased'
      end

      col :purchased_by, search: :string, visible: EffectiveOrders.organization_enabled?

      if attributes[:user_id].blank?
        col :user, search: :string, visible: !EffectiveOrders.organization_enabled?
      end

      if attributes[:organization_id].blank?
        col :organization, visible: EffectiveOrders.organization_enabled?
      end

      if defined?(EffectiveMemberships)
        col(:member_number, label: 'Member #', sort: false, visible: false) do |order|
          order.organization.try(:membership).try(:number) || order.user.try(:membership).try(:number)
        end.search do |collection, term|
          # TODO add organizations too
          user_memberships = Effective::Membership.where(owner_type: current_user.class.name).where('number ILIKE ?', "%#{term}%")
          collection.where(user_id: user_memberships.select('owner_id'))
        end
      end

      col :billing_name, visible: false
      col :email, visible: false

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

      actions_col

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

        user = user_klass.where(id: attributes[:user_id]).first!
        scope = scope.where(user: user)
      end

      if attributes[:organization_id].present? && attributes[:organization_type].present?
        scope = scope.where(organization_id: attributes[:organization_id], organization_type: attributes[:organization_type])
      end

      if attributes[:parent_id].present? && attributes[:parent_type].present?
        scope = scope.where(parent_id: attributes[:parent_id], parent_type: attributes[:parent_type])
      end

      scope
    end

  end
end
