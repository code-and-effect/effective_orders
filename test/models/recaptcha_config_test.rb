require 'test_helper'

# Minimal stub so defined?(::Recaptcha) returns true when needed
module RecaptchaStub
  module_function

  def configuration
    config = Struct.new(:site_key, :secret_key) do
      def site_key!; site_key || raise('No site key'); end
      def secret_key!; secret_key || raise('No secret key'); end
    end

    config.new('global_site_key', 'global_secret_key')
  end
end

class RecaptchaConfigTest < ActiveSupport::TestCase

  test 'recaptcha? returns false when disabled' do
    with_recaptcha(false) do
      assert_equal false, EffectiveOrders.recaptcha?
    end
  end

  test 'recaptcha? returns false without gem defined' do
    with_recaptcha({ site_key: 'sk', secret_key: 'sec' }) do
      # ::Recaptcha is not defined by default in the test environment
      unless defined?(::Recaptcha)
        assert_equal false, EffectiveOrders.recaptcha?
      end
    end
  end

  test 'recaptcha? returns true with hash config and gem defined' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha({ site_key: 'test_site_key', secret_key: 'test_secret_key' }) do
      assert_equal true, EffectiveOrders.recaptcha?
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

  test 'recaptcha? returns true with boolean config and gem defined' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha(true) do
      assert_equal true, EffectiveOrders.recaptcha?
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

  test 'recaptcha_site_key from hash config' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha({ site_key: 'my_site_key', secret_key: 'my_secret_key' }) do
      assert_equal 'my_site_key', EffectiveOrders.recaptcha_site_key
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

  test 'recaptcha_secret_key from hash config' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha({ site_key: 'my_site_key', secret_key: 'my_secret_key' }) do
      assert_equal 'my_secret_key', EffectiveOrders.recaptcha_secret_key
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

  test 'recaptcha_site_key from global Recaptcha configuration' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha(true) do
      assert_equal 'global_site_key', EffectiveOrders.recaptcha_site_key
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

  test 'recaptcha_secret_key from global Recaptcha configuration' do
    Object.const_set(:Recaptcha, RecaptchaStub) unless defined?(::Recaptcha)

    with_recaptcha(true) do
      assert_equal 'global_secret_key', EffectiveOrders.recaptcha_secret_key
    end
  ensure
    Object.send(:remove_const, :Recaptcha) if defined?(::Recaptcha) && ::Recaptcha == RecaptchaStub
  end

end
