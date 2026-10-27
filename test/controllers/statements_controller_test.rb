require "test_helper"

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

  test "brak PDF dla kategorii bez zatwierdzonej treści" do
    post "/pl/certificates/amateur/statement", params: { certificate_search: valid_search_params(division_id: 18, number: "12345") }

    assert_redirected_to "/pl/certificates/amateur"
    assert_not_requested :get, /netpar\.test/
  end

  test "NETPAR niedostępny" do
    stub_request(:get, "#{NETPAR_URL}/token").to_timeout

    post "/pl/certificates/maritime/statement", params: { certificate_search: valid_search_params }

    assert_redirected_to "/pl/certificates/maritime"
    assert_match "chwilowo niedostępny", flash[:alert]
  end
end
