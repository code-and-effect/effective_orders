if defined?(ActiveAdmin)
  ActiveAdmin.register Effective::Cart, namespace: EffectiveOrders.active_admin_namespace, as: 'Carts' do
    menu label: 'My Cart', if: proc { (authorized?(:manage, Effective::Cart.new(user: current_user)) rescue false) }

    actions :index

    controller do
      def index
        redirect_to(effective_orders.cart_path)
      end
    end

  end
end
