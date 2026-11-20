# Content Security Policy (raport bezpieczeństwa 2026-11-20, F-03) – polityka w aplikacji zamiast szczątkowej w nginx.
#
# - skrypty: tylko z naszego serwera i skrypty inline z nonce (motyw strony w layoucie, Matomo; importmap dodaje nonce
#   sam). Nonce stały w obrębie sesji, nie losowany przy każdym żądaniu: Turbo podmienia strony bez przeładowania
#   dokumentu, a polityka obowiązuje z pierwszego wczytania – nowy nonce przy każdej odpowiedzi blokowałby skrypty;
# - style: z naszego serwera i 'unsafe-inline' – deklaracja dostępności (treść urzędu, bez zmian) ma atrybuty style="…",
#   a Turbo wstawia styl paska postępu; style nie wykonują kodu, więc ryzyko jest niewielkie;
# - obrazy: także data: (strzałki pól wyboru w Bootstrapie);
# - Matomo (gdy włączone): skrypt, zapytania i piksel ze stats.uke.gov.pl;
# - naruszenia zgłaszane na /csp-violation-report (CspReportsController – wpis w logu).
# Tryb: confirmation.yml csp_report_only (true – tylko raport, nic nie blokuje; po sprawdzeniu – false).
Rails.application.configure do
  # Serwer Matomo – liczony przy każdym żądaniu z bieżącej konfiguracji (włączenie w credentials serwera); bez Matomo
  # polityka nie dopuszcza żadnej obcej domeny.
  matomo_host = lambda do
    matomo = Rails.configuration.x.confirmation[:matomo]
    URI(matomo[:url]).then { "#{it.scheme}://#{it.host}" } if matomo[:enabled] && matomo[:url].present?
  end

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, matomo_host
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, :data, matomo_host
    policy.font_src :self
    policy.connect_src :self, matomo_host
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :self
    policy.upgrade_insecure_requests true if Rails.env.production?
    policy.report_uri "/csp-violation-report"
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = config.x.confirmation.fetch(:csp_report_only, true)
end
