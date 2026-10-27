require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
# require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Confirmation8
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Warsaw"

    # Jak w poprzedniej wersji: domyślnie EN (kody QR bez języka w adresie skanują też zagraniczni kontrolerzy).
    config.i18n.available_locales = %i[en pl]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [ :en ]

    # Ustawienia aplikacji: API NETPAR, adres w kodzie QR, włączone kategorie, Matomo.
    config.x.confirmation = config_for(:confirmation)

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
