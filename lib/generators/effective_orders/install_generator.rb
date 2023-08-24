module EffectiveOrders
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc 'Creates an EffectiveOrders initializer in your application.'

      source_root File.expand_path('../../templates', __FILE__)

      def self.next_migration_number(dirname)
        unless ActiveRecord::Base.timestamped_migrations
          Time.new.utc.strftime("%Y%m%d%H%M%S")
        else
          "%.3d" % (current_migration_number(dirname) + 1)
        end
      end

      def install_effective_addresses
        run 'rails generate effective_addresses:install'
      end

      def copy_initializer
        template ('../' * 3) + 'config/effective_orders.rb', 'config/initializers/effective_orders.rb'
      end

      def copy_mailer_layout
        layout = 'app/views/layouts/effective_orders_mailer_layout.html.haml'
        template ('../' * 3) + layout, layout
      end

      def copy_mailer_templates
        path = 'app/views/effective/orders_mailer/'

        Dir["#{source_paths.first}/../../../#{path}**"].map { |file| file.split('/').last }.each do |name|
          template (('../' * 3) + path + name), (path + name)
        end
      end

      def copy_mailer_preview
        mailer_preview_path = (Rails.application.config.action_mailer.preview_path rescue nil)

        if mailer_preview_path.present?
          template 'effective_orders_mailer_preview.rb', File.join(mailer_preview_path, 'effective_orders_mailer_preview.rb')
        else
          puts "couldn't find action_mailer.preview_path. Skipping effective_orders_mailer_preview."
        end
      end

      def create_migration_file
        migration_template ('../' * 3) + 'db/migrate/101_create_effective_orders.rb', 'db/migrate/create_effective_orders.rb'
      end

    end
  end
end
