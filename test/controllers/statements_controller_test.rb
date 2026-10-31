require "test_helper"
require "pdf-reader"

class StatementsControllerTest < ActionDispatch::IntegrationTest
  test "PDF po ponownym potwierdzeniu w NETPAR" do
    stub_netpar_token
    search = stub_netpar_search

    post "/pl/certificates/maritime/statement", params: { certificate_search: valid_search_params }

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_match 'filename="GG-05998.pdf"', response.headers["Content-Disposition"]
    assert_requested search, times: 1
  end

  test "brak PDF, gdy NETPAR nie potwierdza danych" do
    stub_netpar_token
    stub_netpar_search(status: 404)

    post "/pl/certificates/maritime/statement", params: { certificate_search: valid_search_params(name: "Ktokolwiek") }

    assert_redirected_to "/pl/certificates/maritime"
    assert_equal "Nie można wygenerować zaświadczenia: świadectwo nie zostało potwierdzone w rejestrze.", flash[:alert]
  end

  test "PDF świadectwa amatorskiego – treść z config/statements.yml" do
    stub_netpar_token
    stub_netpar_search(body: { certificates: [ netpar_certificate("number" => "A-12345", "category" => "R",
                                                                  "division" => { "short_name" => "A", "number_prefix" => "A-" }) ] })

    post "/pl/certificates/amateur/statement", params: { certificate_search: valid_search_params(division_id: 18, number: "12345") }

    assert_response :success
    assert_match 'filename="A-12345.pdf"', response.headers["Content-Disposition"]
    assert_includes PDF::Reader.new(StringIO.new(response.body)).pages.first.text.squish, "art. 95 ust. 2 ustawy z dnia 12 lipca 2024 r."
  end

  test "brak PDF dla kategorii bez treści zaświadczenia" do
    statements = Rails.configuration.x.statements
    Rails.configuration.x.statements = statements.merge(categories: statements[:categories].except(:R))

    post "/pl/certificates/amateur/statement", params: { certificate_search: valid_search_params(division_id: 18, number: "12345") }

    assert_redirected_to "/pl/certificates/amateur"
    assert_not_requested :get, /netpar\.test/
  ensure
    Rails.configuration.x.statements = statements
  end

  test "NETPAR niedostępny" do
    stub_request(:get, "#{NETPAR_URL}/token").to_timeout

    post "/pl/certificates/maritime/statement", params: { certificate_search: valid_search_params }

    assert_redirected_to "/pl/certificates/maritime"
    assert_match "chwilowo niedostępny", flash[:alert]
  end
end
