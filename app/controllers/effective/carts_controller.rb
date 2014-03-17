module Effective
  class CartsController < ApplicationController
    include EffectiveCartsHelper

    def show
      @cart = current_cart
      @page_title ||= 'Shopping Cart'
      EffectiveOrders.authorized?(self, :read, @cart)
    end

    def destroy
      @cart = current_cart

      EffectiveOrders.authorized?(self, :update, @cart)

      if @cart.destroy
        flash[:notice] = 'Successfully emptied cart'
      else
        flash[:alert] = 'Unable to destroy cart:' + e.message
      end

      redirect_to :back
    end

    def add_to_cart
      @purchasable = add_to_cart_params[:purchasable_type].constantize.find(add_to_cart_params[:purchasable_id].to_i) rescue nil

      EffectiveOrders.authorized?(self, :update, current_cart)

      begin
        raise "please select a valid #{add_to_cart_params[:purchasable_type] || 'item' }" unless @purchasable

        current_cart.add_to_cart(@purchasable, [add_to_cart_params[:quantity].to_i, 1].max)
        flash[:notice] = 'Successfully added item to cart'
      rescue EffectiveOrders::SoldOutException
        flash[:alert] = 'This item is sold out'
      rescue => e
        flash[:alert] = 'Unable to add item to cart: ' + e.message
      end

      redirect_to :back
    end

    def remove_from_cart
      @cart_item = current_cart.cart_items.find(remove_from_cart_params[:id])

      EffectiveOrders.authorized?(self, :update, current_cart)

      if @cart_item.destroy
        flash[:notice] = 'Successfully removed item from cart'
      else
        flash[:alert] = 'Unable to remove item from cart: ' + e.message
      end

      redirect_to :back
    end

    private

    def add_to_cart_params
      params.permit(:purchasable_type, :purchasable_id, :quantity)
    end

    def remove_from_cart_params
      params.permit(:id)
    end

  end
end
