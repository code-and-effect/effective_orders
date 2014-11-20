module EffectiveCartsHelper
  def current_cart(for_user = nil)
    @cart ||= (
      user = for_user || (current_user rescue nil) # rescue protects me against Devise not being installed

      if user.present?
        Effective::Cart.where(:user_id => user.id).first_or_create.tap do |user_cart|
          if session[:cart].present?
            session_cart = Effective::Cart.where('user_id IS NULL').where(:id => session[:cart]).first

            if session_cart.present?
              session_cart.cart_items.update_all(:cart_id => user_cart.id)
              session_cart.destroy
              user_cart.reload
            end

            session[:cart] = nil
          end
        end
      elsif session[:cart].present?
        Effective::Cart.where('user_id IS NULL').where(:id => session[:cart]).first_or_create
      else
        cart = Effective::Cart.create!
        session[:cart] = cart.id
        cart
      end
    )
  end

  def link_to_current_cart(opts = {})
    options = {:id => 'current_cart', :rel => :nofollow}.merge(opts)

    if current_cart.size == 0
      link_to (options.delete(:label) || 'Cart'), effective_orders.cart_path, options
    else
      link_to (options.delete(:label) || "Cart (#{current_cart.size})"), effective_orders.cart_path, options
    end
  end

  def link_to_add_to_cart(purchasable, opts = {})
    raise ArgumentError.new('expecting an acts_as_purchasable object') unless purchasable.respond_to?(:is_effectively_purchasable?)

    options = {:class => 'btn', :rel => :nofollow, 'data-disable-with' => 'Add to Cart...'}.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-add-to-cart')

    link_to (options.delete(:label) || 'Add to Cart'), effective_orders.add_to_cart_path(:purchasable_type => purchasable.class.name, :purchasable_id => purchasable.id.to_i), options
  end

  def link_to_remove_from_cart(cart_item, opts = {})
    raise ArgumentError.new('expecting an Effective::CartItem object') unless cart_item.kind_of?(Effective::CartItem)

    options = {
      :rel => :nofollow,
      :data => {:confirm => 'Are you sure? This cannot be undone!'},
      :method => :delete
    }.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-remove-from-cart')

    link_to (options.delete(:label) || 'Remove'), effective_orders.remove_from_cart_path(cart_item), options
  end

  def link_to_empty_cart(opts = {})
    options = {
      :rel => :nofollow,
      :class => 'btn',
      :data => {:confirm => 'This will clear your entire cart.  Are you sure?  This cannot be undone!'},
      :method => :delete
    }.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-empty-cart btn-danger')

    link_to (options.delete(:label) || 'Empty Cart'), effective_orders.cart_path, options
  end

  def link_to_checkout(opts = {})
    options = {:class => 'btn', :rel => :nofollow}.merge(opts)
    options[:class] = ((options[:class] || '') + ' btn-checkout')

    link_to (options.delete(:label) || 'Proceed to Checkout'), effective_orders.new_order_path, options
  end

  def render_cart(cart = nil)
    cart ||= current_cart
    render(:partial => 'effective/carts/cart', :locals => {:cart => cart})
  end

  def render_purchasables(*purchasables)
    render(:partial => 'effective/orders/order_items', :locals => {:order => Effective::Order.new(purchasables)})
  end

end
