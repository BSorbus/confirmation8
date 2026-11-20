require "test_helper"

# Content Security Policy (config/initializers/content_security_policy.rb) – raport bezpieczeństwa 2026-11-20, F-03.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  HEADER = "Content-Security-Policy-Report-Only" # confirmation.yml csp_report_only: true

  def policy = response.headers[HEADER].to_s

  def nonce = policy[/'nonce-([^']+)'/, 1]

  test "polityka: tylko własne zasoby, skrypty z nonce, raport naruszeń; tryb Report-Only" do
    get "/pl"
    assert_response :success
    assert_nil response.headers["Content-Security-Policy"], "tryb Report-Only – polityka niczego nie blokuje"
    [ "default-src 'self'", "style-src 'self' 'unsafe-inline'", "img-src 'self' data:", "font-src 'self'", "connect-src 'self'",
      "object-src 'none'", "base-uri 'self'", "form-action 'self'", "frame-ancestors 'self'", "report-uri /csp-violation-report" ]
      .each { assert_includes policy, it }
    assert_match(/script-src 'self' 'nonce-[^']+'/, policy)
    assert_no_match(/stats\.uke\.gov\.pl/, policy, "bez Matomo – żadnej obcej domeny")
  end

  test "skrypty inline (motyw, importmap) z nonce z polityki; nonce stały w sesji (Turbo nie przeładowuje dokumentu)" do
    get "/pl"
    first = nonce
    assert first.present?
    assert_select "head script:not([src])" do |scripts|
      scripts.each { assert_equal first, it["nonce"], "skrypt inline bez nonce: #{it.to_html.truncate(80)}" }
    end

    get "/pl/certificates/aeronautical"
    assert_equal first, nonce
  end

  test "Matomo włączone: skrypt z nonce, domena statystyk w script-src, img-src i connect-src" do
    matomo = Rails.configuration.x.confirmation[:matomo]
    previous, matomo[:enabled] = matomo[:enabled], true

    get "/pl"
    %w[script-src img-src connect-src].each { assert_match(/#{it} [^;]*https:\/\/stats\.uke\.gov\.pl/, policy) }
    assert_select "script[nonce='#{nonce}']", text: /_paq/
  ensure
    matomo[:enabled] = previous if matomo
  end

  test "raport naruszenia: wpis w logu bez parametrów adresu (dane osobowe w starych linkach QR)" do
    log = StringIO.new
    previous, Rails.logger = Rails.logger, ActiveSupport::Logger.new(log)
    post "/csp-violation-report", params: { "csp-report" => {
      "document-uri" => "https://confirmation.uke.gov.pl/certificates/new?name=Kowalski&birth_date=1969-07-06",
      "violated-directive" => "script-src", "blocked-uri" => "https://evil.example/x.js?token=1" } }.to_json,
      headers: { "Content-Type" => "application/csp-report" }
    assert_response :no_content
    entry = log.string.lines.grep(/\[CSP\]/)
    assert_equal 1, entry.size
    assert_includes entry.first, "[CSP] document-uri=https://confirmation.uke.gov.pl/certificates/new violated-directive=script-src"
    assert_includes entry.first, "blocked-uri=https://evil.example/x.js"
    assert_no_match(/Kowalski|1969|token/, entry.first)

    post "/csp-violation-report", params: "nie json", headers: { "Content-Type" => "application/csp-report" }
    assert_response :bad_request
  ensure
    Rails.logger = previous if previous
  end
end
