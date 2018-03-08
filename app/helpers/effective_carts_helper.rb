module EffectiveCartsHelper
  # TODO: Consider unique
  def current_cart(for_user = nil)
    @cart ||= (
      user = for_user || (current_user rescue nil) # rescue protects me against Devise not being installed

      if user.present?
        user_cart = Effective::Cart.where(user: user).first_or_create

        # Merge session cart into user cart.
        if session[:cart].present?
          session_cart = Effective::Cart.where(user: nil).where(id: session[:cart]).first

          if session_cart
            session_cart.cart_items.each { |i| user_cart.add(i.purchasable, quantity: i.quantity, unique: i.unique) }
            session_cart.destroy
          end

          session[:cart] = nil
        end

        user_cart
      elsif session[:cart].present?
        Effective::Cart.where(user_id: nil).where(id: session[:cart]).first_or_create
      else
        cart = Effective::Cart.create!
        session[:cart] = cart.id
        cart
      end
    )
  end

  def link_to_current_cart(opts = {})
    options = {
      label: 'My Cart',
      id: 'current_cart',
      rel: :nofollow,
      class: 'btn btn-default'
    }.merge(opts)

    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-current-cart')

    link_to (current_cart.size == 0 ? label : "#{label} (#{current_cart.size})"), effective_orders.cart_path, options
  end

  def link_to_add_to_cart(purchasable, opts = {})
    raise 'expecting an acts_as_purchasable object' unless purchasable.kind_of?(ActsAsPurchasable)

    options = { label: 'Add to Cart', class: 'btn btn-primary', rel: :nofollow }.merge(opts)

    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-add-to-cart')

    link_to(label, effective_orders.add_to_cart_path(purchasable_type: purchasable.class.name, purchasable_id: purchasable.id.to_i), options)
  end

  def link_to_remove_from_cart(cart_item, opts = {})
    raise 'expecting an Effective::CartItem object' unless cart_item.kind_of?(Effective::CartItem)

    options = {
      label: 'Remove',
      class: 'btn btn-primary',
      rel: :nofollow,
      data: { confirm: 'Are you sure? This cannot be undone!' },
      method: :delete
    }.merge(opts)

    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-remove-from-cart')

    link_to(label, effective_orders.remove_from_cart_path(cart_item), options)
  end

  def link_to_empty_cart(opts = {})
    options = {
      label: 'Empty Cart',
      class: 'btn btn-danger',
      rel: :nofollow,
      data: { confirm: 'This will clear your entire cart. Are you sure?' },
      method: :delete
    }.merge(opts)

    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-empty-cart')

    link_to(label, effective_orders.cart_path, options)
  end

  def link_to_checkout(opts = {})
    options = { label: 'Checkout', class: 'btn btn-primary', rel: :nofollow }.merge(opts)

    order = options.delete(:order)
    label = options.delete(:label)
    options[:class] = ((options[:class] || '') + ' btn-checkout')

    if order.present?
      link_to(label, effective_orders.edit_order_path(order), options)
    else
      link_to(label, effective_orders.new_order_path, options)
    end
  end

  def render_cart(cart = nil)
    cart ||= current_cart
    render(partial: 'effective/carts/cart', locals: { cart: cart })
  end

  def render_purchasables(*purchasables)
    render(partial: 'effective/orders/order_items', locals: { order: Effective::Order.new(purchasables) })
  end

end
