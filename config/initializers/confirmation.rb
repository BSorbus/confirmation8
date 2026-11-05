# Uzupełnia ustawienia z config/confirmation.yml o dane zależne od serwera.
# Kolejność: zmienna środowiskowa > credentials (config/credentials/<środowisko>.yml.enc).
#
# Struktura credentials:
#   netpar:
#     url: https://…/api/v1
#     user: confirmation
#     password: …
#   matomo:
#     enabled: false                         # opcjonalnie – np. serwer testowy bez statystyk
#   categories: [M, L]                       # opcjonalnie – zakładki na tym serwerze (domyślnie z confirmation.yml)
settings = Rails.configuration.x.confirmation
credentials = Rails.application.credentials

settings[:netpar][:url] = ENV["NETPAR_URL"].presence || credentials.dig(:netpar, :url) || settings[:netpar][:url]
settings[:netpar][:user] = ENV["NETPAR_USER"].presence || credentials.dig(:netpar, :user) || settings[:netpar][:user]
settings[:netpar][:password] = ENV["NETPAR_PASSWORD"].presence || credentials.dig(:netpar, :password)
matomo_enabled = ENV["MATOMO_ENABLED"].presence || credentials.dig(:matomo, :enabled)
settings[:matomo][:enabled] = ActiveModel::Type::Boolean.new.cast(matomo_enabled) unless matomo_enabled.nil?
# Zakładki: "M,L" w zmiennej albo lista / tekst w credentials. W testach zawsze z confirmation.yml.
categories = ENV["CONFIRMATION_CATEGORIES"].presence || credentials[:categories] unless Rails.env.test?
settings[:categories] = Array(categories).flat_map { it.to_s.split(",") }.map { it.strip.upcase }.compact_blank if categories.present?

# Bez kompletnych danych aplikacja nie startuje – zamiast po cichu łączyć się z niewłaściwym NETPAR.
# Pomijane w testach (WebMock) i przy budowaniu zasobów bez kluczy (SECRET_KEY_BASE_DUMMY).
unless Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"].present?
  missing = { "netpar.url" => settings[:netpar][:url], "netpar.user" => settings[:netpar][:user],
              "netpar.password" => settings[:netpar][:password] }
            .select { |_, value| value.blank? }.keys
  if missing.any?
    raise "Brak ustawień: #{missing.join(", ")}. Uzupełnij config/credentials/#{Rails.env}.yml.enc " \
          "(bin/rails credentials:edit --environment #{Rails.env}) albo zmienne środowiskowe – patrz README."
  end
end
