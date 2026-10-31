require "test_helper"

class CertificatesControllerTest < ActionDispatch::IntegrationTest
  def search!(category: "maritime", locale: "pl", params: valid_search_params, as: :turbo_stream)
    post "/#{locale}/certificates/#{category}", params: { certificate_search: params }, as:
  end

  test "formularz w każdej kategorii, domyślnie EN" do
    get "/"
    assert_response :success
    assert_select "html[lang=en]"
    %w[maritime aeronautical amateur].each do |category|
      get "/pl/certificates/#{category}"
      assert_response :success
      assert_select ".category-tabs__tab.is-current[href='/pl/certificates/#{category}']"
    end
  end

  test "nagłówek: przycisk trybu jasny/ciemny, deklaracja dostępności tylko w stopce" do
    get "/pl/certificates/maritime"
    assert_select "header .theme-switch[data-controller=theme] button.theme-switch__button[aria-pressed]", 3
    %w[light dark contrast].each { |theme| assert_select "header button[data-theme-value=#{theme}]", 1 }
    assert_select "header a.brand[aria-label^='Confirmation']", 1
    assert_select "header .brand__org", text: /Urząd Komunikacji\s*Elektronicznej/
    assert_select "header img", 0 # znak tekstowy zamiast obrazka
    assert_select "header a[href='/pl/declaration']", 0
    assert_select "footer a[href='/pl/declaration']", 1
    assert_select "footer .site-footer__copy", "© 2018–#{Date.current.year} UKE"
    assert_match 'setAttribute("data-theme"', response.body # tryb ustawiany w <head>, bez mignięcia
    assert_match "prefers-contrast: more", response.body
  end

  test "przełącznik języka prowadzi do tej samej strony w drugim języku" do
    get "/pl/certificates/aeronautical"
    assert_select "a.lang-switch__link[hreflang=en][href='/en/certificates/aeronautical']"
    assert_select "a.lang-switch__link.is-current[hreflang=pl][href='/pl/certificates/aeronautical']"

    get "/"
    assert_select "a.lang-switch__link[hreflang=pl][href='/pl/certificates/maritime']"

    get "/pl/declaration"
    assert_select "a.lang-switch__link[hreflang=en][href='/en/declaration']"
  end

  test "przełącznik języka zachowuje dane z kodu QR, ale tylko znane parametry" do
    get "/certificates/new", params: { number_prefix: "GG-", number: "05998", script_name: "//evil.example", host: "evil.example" }

    link = css_select("a.lang-switch__link[hreflang=pl]").first["href"]
    assert link.start_with?("/pl/certificates/maritime?"), link
    assert_includes link, "number=05998"
    assert_includes link, "number_prefix=GG-"
    assert_no_match(/evil/, link)
  end

  test "formularz bez walidacji przeglądarki (komunikaty w języku strony), pola nadal oznaczone jako wymagane" do
    get "/pl/certificates/maritime"
    assert_select "form#search_form[novalidate]"
    assert_select "form#search_form select#certificate_search_division_id[required]"
    assert_select "form#search_form input#certificate_search_number[required]"
  end

  test "lista rodzajów: nazwy z NETPAR, prefiks w atrybucie" do
    get "/pl/certificates/maritime"
    assert_select "select#certificate_search_division_id option[value='14'][data-prefix='GS-']", "świadectwo operatora łączności bliskiego zasięgu SRC"
    get "/en/certificates/maritime"
    assert_select "option[value='11']", "General operator's certificate"
    assert_select "option[value='16']", "świadectwo operatora stacji nadbrzeżnej CSO"
  end

  test "stare adresy z kodów QR wypełniają formularz morski" do
    get "/certificates/new", params: { number_prefix: "GG-", number: "05998", date_of_issue: "2018-08-30", valid_thru: "2028-08-30",
                                       name: "Kozłowski", given_names: "Jan Maria", birth_date: "1969-07-06" }
    assert_response :success
    assert_select "option[value='11'][selected]"
    assert_select "input#certificate_search_number[value='05998']"
    assert_select "input#certificate_search_birth_date[value='1969-07-06']"
    get "/pl/certificates"
    assert_response :success
  end

  test "znalezione świadectwo (Turbo Stream)" do
    stub_netpar_token
    stub_netpar_search

    search!

    assert_response :success
    assert_match "Świadectwo potwierdzone", response.body
    assert_match "Ważne do 30.08.2028", response.body
    assert_match "świadectwo ogólne operatora GMDSS", response.body
    assert_match "Pobierz zaświadczenie (PDF)", response.body
  end

  test "znalezione świadectwo bez JavaScriptu (zwykły HTML)" do
    stub_netpar_token
    stub_netpar_search

    search!(as: nil)

    assert_response :success
    assert_select "#search_result h2", "Świadectwo potwierdzone"
    assert_select "aside#search_result.has-result" # na telefonie wynik nad formularzem
    ids = css_select("[id]").map { it["id"] }
    assert_equal ids.uniq, ids, "zdublowane id (np. ukryte pola formularza PDF)" # WCAG 4.1.1
  end

  test "status ważności: bezterminowe i wygasłe" do
    stub_netpar_token
    stub_netpar_search(body: { certificates: [ netpar_certificate("valid_thru" => "") ] })
    search!(params: valid_search_params(no_expiry: "1"))
    assert_match "Bezterminowe", response.body

    stub_netpar_search(body: { certificates: [ netpar_certificate("valid_thru" => "2020-01-31") ] })
    search!(locale: "en")
    assert_match "Expired 31.01.2020", response.body
  end

  test "nie znaleziono" do
    stub_netpar_token
    stub_netpar_search(status: 404)

    search!

    assert_response :success
    assert_match "Nie znaleziono świadectwa", response.body
  end

  test "błędy formularza: 422, podsumowanie i komunikaty przy polach" do
    search!(params: valid_search_params(number: "123", birth_date: ""))

    assert_response :unprocessable_content
    assert_match "Popraw 2 pola", response.body
    assert_match "Numer świadectwa musi mieć dokładnie 5 cyfr", response.body
    assert_match 'aria-invalid="true"', response.body
    assert_not_requested :get, %r{certificates/search} # niepoprawne dane nie trafiają do wyszukiwania w NETPAR
  end

  test "NETPAR niedostępny" do
    stub_netpar_token
    stub_netpar_search(status: 502, body: "Bad Gateway")

    search!

    assert_response :service_unavailable
    assert_match "Weryfikacja chwilowo niedostępna", response.body
  end

  test "NETPAR niedostępny już przy formularzu: komunikat zamiast listy rodzajów" do
    stub_request(:get, "#{NETPAR_URL}/token").to_timeout

    get "/pl/certificates/maritime"

    assert_response :service_unavailable
    assert_match "Weryfikacja chwilowo niedostępna", response.body
    assert_select "select#certificate_search_division_id option[data-prefix]", count: 0
  end

  test "rodzaje pobierane z NETPAR przy każdym wyświetleniu formularza" do
    2.times { get "/pl/certificates/maritime" }

    assert_requested :get, "#{NETPAR_URL}/divisions", times: 2
  end

  test "zakładki tylko dla kategorii włączonych w konfiguracji confirmation8" do
    settings = Rails.configuration.x.confirmation
    previous, settings[:categories] = settings[:categories], %w[M R]

    get "/pl"
    assert_select ".category-tabs__tab", count: 2
    assert_select ".category-tabs__tab[href='/pl/certificates/aeronautical']", count: 0

    get "/pl/certificates/aeronautical"
    assert_response :not_found
  ensure
    settings[:categories] = previous
  end

  test "stopka: kontakt dla każdej włączonej kategorii (adresy z config/statements.yml)" do
    get "/pl"
    assert_select ".site-footer__links a[href='mailto:ske.gdynia@uke.gov.pl']", text: "Morskie: ske.gdynia@uke.gov.pl"
    assert_select ".site-footer__links a[href='mailto:wml@uke.gov.pl']", count: 2
    assert_select ".site-footer__links a", text: "Lotnicze: wml@uke.gov.pl"
    assert_select ".site-footer__links a", text: "Amatorskie: wml@uke.gov.pl"

    settings = Rails.configuration.x.confirmation
    previous, settings[:categories] = settings[:categories], %w[M]
    get "/pl"
    assert_select ".site-footer__links a[href^='mailto:']", count: 1
  ensure
    settings[:categories] = previous if settings
  end

  test "kategoria bez rodzajów włączonych w NETPAR: zakładka widoczna, pusta lista rodzajów" do
    stub_netpar_divisions(NETPAR_DIVISIONS.select { it["category"] == "M" })

    get "/pl/certificates/aeronautical"

    assert_response :success
    assert_select ".category-tabs__tab", count: 3
    assert_select "select#certificate_search_division_id option[data-prefix]", count: 0
  end

  test "PDF dla kategorii z treściami zaświadczenia (config/statements.yml)" do
    stub_netpar_token
    stub_netpar_search(body: { certificates: [ netpar_certificate("number" => "L-1234", "category" => "L") ] })

    search!(category: "aeronautical", params: valid_search_params(division_id: 1, number: "1234"))

    assert_match "Świadectwo potwierdzone", response.body
    assert_match "Pobierz zaświadczenie (PDF)", response.body
  end

  test "bez PDF dla kategorii bez treści zaświadczenia" do
    stub_netpar_token
    stub_netpar_search(body: { certificates: [ netpar_certificate("number" => "L-1234", "category" => "L") ] })
    statements = Rails.configuration.x.statements
    Rails.configuration.x.statements = statements.merge(categories: statements[:categories].except(:L))

    search!(category: "aeronautical", params: valid_search_params(division_id: 1, number: "1234"))

    assert_match "Świadectwo potwierdzone", response.body
    assert_no_match "Pobierz zaświadczenie (PDF)", response.body
  ensure
    Rails.configuration.x.statements = statements
  end

  test "limit zapytań: 50 na minutę z jednego adresu" do
    stub_netpar_token
    stub_netpar_search(status: 404)

    ApplicationController::SEARCH_RATE_LIMIT.times { search! }
    assert_response :success
    search!
    assert_response :too_many_requests
    assert_match "Zbyt wiele prób", response.body
  end

  test "dane osobowe nie trafiają do logów" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("certificate_search" => valid_search_params.stringify_keys)
    assert_equal "[FILTERED]", filtered["certificate_search"]
  end

  test "stary, niebezpieczny adres generowania PDF z parametrów nie istnieje" do
    get "/pl/certificates/statement_to_pdf.pdf", params: { req_data_certificate: { number: "GG-1" } }
    assert_response :not_found
  end
end
