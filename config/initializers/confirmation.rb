# Uzupełnia ustawienia z config/confirmation.yml o dane zależne od serwera.
# Kolejność: zmienna środowiskowa > credentials (config/credentials/<środowisko>.yml.enc).
#
# Struktura credentials:
#   netpar:
#     url: https://…/api/v1
#     user: confirmation
#     password: …
#   search_url: https://…/certificates/new   # adres formularza w kodzie QR na zaświadczeniu
settings = Rails.configuration.x.confirmation
credentials = Rails.application.credentials

settings[:netpar][:url] = ENV["NETPAR_URL"].presence || credentials.dig(:netpar, :url) || settings[:netpar][:url]
settings[:netpar][:user] = ENV["NETPAR_USER"].presence || credentials.dig(:netpar, :user) || settings[:netpar][:user]
settings[:netpar][:password] = ENV["NETPAR_PASSWORD"].presence || credentials.dig(:netpar, :password)
settings[:search_url] = ENV["CONFIRMATION_SEARCH_URL"].presence || credentials[:search_url] || settings[:search_url]

# Bez kompletnych danych aplikacja nie startuje – zamiast po cichu łączyć się z niewłaściwym NETPAR.
# Pomijane w testach (WebMock) i przy budowaniu zasobów bez kluczy (SECRET_KEY_BASE_DUMMY).
unless Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"].present?
  missing = { "netpar.url" => settings[:netpar][:url], "netpar.user" => settings[:netpar][:user],
              "netpar.password" => settings[:netpar][:password], "search_url" => settings[:search_url] }
            .select { |_, value| value.blank? }.keys
  if missing.any?
    raise "Brak ustawień: #{missing.join(", ")}. Uzupełnij config/credentials/#{Rails.env}.yml.enc " \
          "(bin/rails credentials:edit --environment #{Rails.env}) albo zmienne środowiskowe – patrz README."
  end
end
