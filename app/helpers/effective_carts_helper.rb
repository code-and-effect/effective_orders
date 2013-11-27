module EffectiveCartsHelper
  def current_cart
    @cart ||= (
      if (user = (current_user rescue nil)).present? # This protects me against Devise not being installed
        Effective::Cart.where(:user_id => user.try(:id)).first_or_create.tap do |user_cart|
          if session[:cart].present?
            if (session_cart = Effective::Cart.where(:id => session[:cart]).first).present?
              session_cart.cart_items.update_all(:cart_id => user_cart.try(:id))
            end

            session[:cart] = nil
          end
        end
      elsif session[:cart].present?
        Effective::Cart.where(:id => session[:cart]).first_or_create
      else
        cart = Effective::Cart.create!
        session[:cart] = cart.id
        cart
      end
    )
  end

  def link_to_current_cart(opts = {})
    options = {:id => 'current_cart'}.merge(opts)
    link_to "Cart (#{current_cart.size})", EffectiveOrders::Engine.routes.url_helpers.cart_path, options
  end

  def link_to_add_to_cart(purchasable, opts = {})
    raise ArgumentError.new('expecting an acts_as_purchasable object') unless purchasable.respond_to?(:is_effectively_purchasable?)

    options = {:class => 'btn'}.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-add-to-cart')

    link_to(
      (options.delete(:label) || 'Add to Cart'),
      EffectiveOrders::Engine.routes.url_helpers.add_to_cart_path(:purchasable_type => purchasable.class.name, :purchasable_id => purchasable.id.to_i),
      options
    )
  end

  def link_to_remove_from_cart(cart_item, opts = {})
    raise ArgumentError.new('expecting an Effective::CartItem object') unless cart_item.kind_of?(Effective::CartItem)

    options = {
      :data => {:confirm => 'Are you sure? This cannot be undone!'},
      :method => :delete
    }.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-remove-from-cart')

    link_to(
      (options.delete(:label) || 'Remove'),
      EffectiveOrders::Engine.routes.url_helpers.remove_from_cart_path(cart_item),
      options
    )
  end

  def link_to_empty_cart(opts = {})
    options = {
      :class => 'btn',
      :data => {:confirm => 'This will clear your entire cart.  Are you sure?  This cannot be undone!'},
      :method => :delete
    }.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-empty-cart')

    link_to(
      (options.delete(:label) || 'Empty Cart'),
      EffectiveOrders::Engine.routes.url_helpers.cart_path,
      options
    )
  end

  def link_to_checkout(opts = {})
    options = {:class => 'btn'}.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-checkout')

    link_to(
      (options.delete(:label) || 'Proceed to Checkout'),
      EffectiveOrders::Engine.routes.url_helpers.new_order_path,
      options
    )
  end

end
