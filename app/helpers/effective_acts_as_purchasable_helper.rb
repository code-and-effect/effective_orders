module EffectiveActsAsPurchasableHelper
  def acts_as_purchasable_fields(form, options = {})
    raise 'expected a form builder' unless form.respond_to?(:object)
    render('effective/acts_as_purchasable/fields', { form: form }.merge(options))
  end

  def qb_item_name_field(form, options = {})
    raise 'expected a form builder' unless form.respond_to?(:object)
    raise 'expected an object that responds to qb_item_name' unless form.object.respond_to?(:qb_item_name)

    collection = Effective::ItemName.unarchived.or(Effective::ItemName.where(name: form.object.qb_item_name.to_s)).sorted.pluck(:name)

    options = options.reverse_merge(
      label: (EffectiveOrders.quickbooks? ? "Quickbooks #{etd(Effective::ItemName)}" : et(Effective::ItemName)),
      hint: "Can't find the #{etd(Effective::ItemName)} you need? #{link_to('Click here to add one', effective_orders.admin_item_names_path, target: '_blank')}",
      required: EffectiveOrders.require_item_names?
    )
    
    form.select :qb_item_name, collection, options
  end

  def qb_item_name_label
    EffectiveOrders.quickbooks? ? "Quickbooks #{etd(Effective::ItemName)}" : et(Effective::ItemName)
  end

  def qb_item_names_label
    EffectiveOrders.quickbooks? ? "Quickbooks #{etsd(Effective::ItemName)}" : ets(Effective::ItemName)
  end

  # This is called on the My Sales Page and is intended to be overridden in the app if needed
  def acts_as_purchasable_path(purchasable, action = :show)
    polymorphic_path(purchasable)
  end
end
