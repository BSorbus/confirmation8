require "test_helper"

# Kod QR karty plastikowej: /qrc/<kod> – od razu wynik weryfikacji na stronie formularza (pola wypełnione, przycisk PDF).
class CodesControllerTest < ActionDispatch::IntegrationTest
  setup { stub_netpar_token }

  test "znaleziony kod: wynik od razu, formularz wypełniony danymi świadectwa, przycisk zaświadczenia" do
    lookup = stub_netpar_code

    get "/qrc/#{CARD_CODE}"

    assert_response :success
    assert_requested lookup, times: 1
    assert_select ".result-card--found"
    assert_select ".result-details dd", text: "GG-05998"
    assert_select ".result-details dd", text: "Jan Maria Kozłowski"
    assert_select "input[name='certificate_search[number]'][value='05998']", minimum: 1
    assert_select "input[name='certificate_search[name]'][value='Kozłowski']", minimum: 1
    # adres z karty nie ma języka – domyślny angielski (jak kod QR zaświadczenia)
    assert_select "form[action='/en/certificates/maritime/statement']"
    assert_select ".category-tabs__tab.is-current[href='/en/certificates/maritime']" # zakładka wg kategorii świadectwa
    assert_select ".lang-switch__link[hreflang='pl'][href='/pl/qrc/#{CARD_CODE}']"   # zmiana języka – ten sam kod
  end

  test "zaświadczenie PDF z wyniku po kodzie – jak z wyszukiwania" do
    stub_netpar_code
    stub_netpar_search
    get "/qrc/#{CARD_CODE}"
    form = css_select("form.result-card__pdf input[type=hidden]").to_h { [ it["name"], it["value"] ] }

    post "/en/certificates/maritime/statement", params: form

    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "nieznany kod: brak danych" do
    stub_netpar_code(status: 404)
    get "/en/qrc/#{CARD_CODE}"
    assert_response :success
    assert_select ".result-card--not-found"
  end

  test "rodzaj wyłączony z weryfikacji internetowej" do
    stub_netpar_code(status: 403, body: { "error" => "Rodzaj świadectwa nie podlega weryfikacji internetowej" })
    get "/pl/qrc/#{CARD_CODE}"
    assert_select ".result-card--warning h2", text: I18n.t("certificates.result.type_not_verifiable.title", locale: :pl)
  end

  test "zły format kodu: brak danych bez zapytania do NETPAR" do
    get "/qrc/ABC"
    assert_response :success
    assert_select ".result-card--not-found"
    assert_not_requested :get, %r{certificates/search_by_code}
  end

  test "NETPAR niedostępny" do
    stub_request(:get, "#{NETPAR_URL}/certificates/search_by_code").to_timeout
    get "/qrc/#{CARD_CODE}"
    assert_response :service_unavailable
    assert_select ".result-card--warning"
  end

  test "świadectwo wydane przed dniem weryfikacji rodzaju (403 issued_before_limit): komunikat z datą" do
    stub_netpar_code(status: 403, body: { "error" => "Świadectwa wydane przed 2018-09-01 …", "reason" => "issued_before_limit",
                                          "verifiable_from" => "2018-09-01" })
    get "/pl/qrc/#{CARD_CODE}"
    assert_select ".result-card--warning h2", text: I18n.t("certificates.result.issued_before_limit.title", date: "01.09.2018", locale: :pl)
  end
end
