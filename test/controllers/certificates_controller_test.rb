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
    assert_not_requested :get, /netpar\.test/
  end

  test "NETPAR niedostępny" do
    stub_netpar_token
    stub_netpar_search(status: 502, body: "Bad Gateway")

    search!

    assert_response :service_unavailable
    assert_match "Weryfikacja chwilowo niedostępna", response.body
  end

  test "PDF tylko dla kategorii morskiej (zatwierdzona treść)" do
    stub_netpar_token
    stub_netpar_search(path: "certificates/search_by_multi_params",
                       body: { certificates: [ netpar_certificate("number" => "L-1234", "category" => "L") ] })

    search!(category: "aeronautical", params: valid_search_params(division_id: 1, number: "1234"))

    assert_match "Świadectwo potwierdzone", response.body
    assert_no_match "Pobierz zaświadczenie (PDF)", response.body
  end

  test "limit zapytań: 10 na minutę z jednego adresu" do
    stub_netpar_token
    stub_netpar_search(status: 404)

    10.times { search! }
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
