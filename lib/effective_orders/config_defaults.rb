module EffectiveOrders
  class ConfigDefaults
    def self.after_setup
      new.after_setup
    end

    def after_setup
      deliver_method
      paypal
    end

    def deliver_method
      unless EffectiveOrders.mailer[:deliver_method].present?
        EffectiveOrders.mailer[:deliver_method] = case
                              when Rails.gem_version >= Gem::Version.new('4.2')
                                :deliver_now
                              else
                                :deliver
                              end
      end
    end

    def paypal
      if EffectiveOrders.paypal_enabled
        missing = EffectiveOrders.paypal.select do |config, value|
          value.blank?
        end

        raise "Missing effective_orders PayPal configuration values: #{missing.keys.join(', ')}" if missing.present?
      end
    end
  end
end

