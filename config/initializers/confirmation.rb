# Uzupełnia ustawienia z config/confirmation.yml o wartości z credentials (config/credentials/<środowisko>.yml.enc).
# Kolejność: zmienna środowiskowa > credentials > wartość domyślna z confirmation.yml.
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
