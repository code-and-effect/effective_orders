require 'test_helper'

# Minimal stub so defined?(::Recaptcha) returns true
module RecaptchaCheckoutStub
  module_function

  def configuration
    config = Struct.new(:site_key, :secret_key) do
      def site_key!; site_key || raise('No site key'); end
      def secret_key!; secret_key || raise('No secret key'); end
    end

    config.new('test_site_key', 'test_secret_key')
  end
end

class RecaptchaCheckoutTest < ActionDispatch::IntegrationTest

  setup do
    @user = create_user!
    sign_in(@user)
  end

  test 'pretend purchase works when recaptcha disabled' do
    order = create_confirmed_order!

    with_recaptcha(false) do
      post effective_orders.pretend_order_path(order), params: { pretend: { purchased_url: '', declined_url: '' } }
      assert_response :redirect
      assert_match /purchased/, response.location
    end
  end

  test 'pretend purchase blocked without recaptcha session when not admin' do
    order = create_confirmed_order!

    enable_recaptcha_with_non_admin do
      post effective_orders.pretend_order_path(order), params: { pretend: { purchased_url: '', declined_url: '' } }
      assert_response :redirect
      assert_match /orders\/#{order.to_param}/, response.location
      assert_equal 'Please complete the verification to proceed with payment.', flash[:danger]
    end
  end

  test 'pretend purchase allowed with recaptcha session when not admin' do
    order = create_confirmed_order!

    enable_recaptcha_with_non_admin do
      set_recaptcha_session(order)

      post effective_orders.pretend_order_path(order), params: { pretend: { purchased_url: '', declined_url: '' } }
      assert_response :redirect
      assert_match /purchased/, response.location
    end
  end

  test 'pretend purchase allowed for admin even without recaptcha session' do
    order = create_confirmed_order!

    # Admin bypass: EffectiveResources.authorized?(self, :admin, :effective_orders) returns true
    # This is the default in the dummy app since authorize! always returns true
    with_recaptcha({ site_key: 'sk', secret_key: 'sec' }) do
      ensure_recaptcha_defined do
        post effective_orders.pretend_order_path(order), params: { pretend: { purchased_url: '', declined_url: '' } }
        assert_response :redirect
        assert_match /purchased/, response.location
      end
    end
  end

  test 'session cleared after purchase' do
    order = create_confirmed_order!

    enable_recaptcha_with_non_admin do
      set_recaptcha_session(order)

      post effective_orders.pretend_order_path(order), params: { pretend: { purchased_url: '', declined_url: '' } }
      assert_response :redirect

      # Session should be cleared after purchase
      assert_nil session[:recaptcha_verified_order_id]
    end
  end

  test 'verify_recaptcha_action sets session on success' do
    order = create_confirmed_order!

    enable_recaptcha_with_non_admin do
      stub_verify_recaptcha(true) do
        post effective_orders.verify_recaptcha_order_path(order)
        assert_response :redirect
        assert_match /orders\/#{order.to_param}/, response.location
        assert_equal order.id, session[:recaptcha_verified_order_id]
      end
    end
  end

  test 'verify_recaptcha_action redirects with error on failure' do
    order = create_confirmed_order!

    enable_recaptcha_with_non_admin do
      stub_verify_recaptcha(false) do
        post effective_orders.verify_recaptcha_order_path(order)
        assert_response :redirect
        assert_match /orders\/#{order.to_param}/, response.location
        assert_equal 'Verification failed. Please try again.', flash[:danger]
        assert_nil session[:recaptcha_verified_order_id]
      end
    end
  end

  private

  def create_confirmed_order!
    order = build_effective_order(user: @user)
    order.save!
    order
  end

  def ensure_recaptcha_defined(&block)
    was_defined = defined?(::Recaptcha)
    Object.const_set(:Recaptcha, RecaptchaCheckoutStub) unless was_defined

    yield
  ensure
    Object.send(:remove_const, :Recaptcha) if !was_defined && defined?(::Recaptcha) && ::Recaptcha == RecaptchaCheckoutStub
  end

  def enable_recaptcha_with_non_admin(&block)
    with_recaptcha({ site_key: 'test_site_key', secret_key: 'test_secret_key' }) do
      ensure_recaptcha_defined do
        # Override EffectiveResources.authorized? to return false for :admin check
        # so verify_recaptcha_checkout! doesn't skip via admin bypass
        original_method = EffectiveResources.method(:authorized?)

        EffectiveResources.define_singleton_method(:authorized?) do |controller, action, resource|
          return false if action == :admin && resource == :effective_orders
          original_method.call(controller, action, resource)
        end

        yield
      ensure
        EffectiveResources.define_singleton_method(:authorized?, original_method)
      end
    end
  end

  # Temporarily define verify_recaptcha on the controller to return the given value
  def stub_verify_recaptcha(return_value, &block)
    Effective::OrdersController.class_eval do
      define_method(:verify_recaptcha) { |**_opts| return_value }
    end

    yield
  ensure
    Effective::OrdersController.class_eval do
      remove_method(:verify_recaptcha) if method_defined?(:verify_recaptcha)
    end
  end

  # Set the recaptcha session via the verify_recaptcha_action endpoint
  def set_recaptcha_session(order)
    stub_verify_recaptcha(true) do
      post effective_orders.verify_recaptcha_order_path(order)
    end
  end

end
