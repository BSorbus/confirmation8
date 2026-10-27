require "test_helper"

class Netpar::ClientTest < ActiveSupport::TestCase
  setup do
    @search = CertificateSearch.new(valid_search_params.merge(category_slug: "maritime")).tap(&:valid?)
    @client = Netpar::Client.new(password: "secret")
  end

  test "znalezione świadectwo" do
    stub_netpar_token
    search = stub_netpar_search

    certificate = @client.find_certificate(@search, remote_ip: "203.0.113.5")

    assert_equal "GG-05998", certificate.number
    assert_equal Date.new(2028, 8, 30), certificate.valid_thru
    assert_equal "Kozłowski", certificate.holder.name
    assert_requested search.with(
      headers: { "Authorization" => "Token token=tok-1", "X-Real-IP" => "203.0.113.5", "Content-Type" => "application/json" },
      body: { number_prefix: "GG-", number: "05998", date_of_issue: "2018-08-30", valid_thru: "2028-08-30",
              name: "kozlowski", given_names: "JAN MARIA", birth_date: "1969-07-06" }.to_json)
  end

  test "token pobierany z uwierzytelnieniem i zapamiętywany" do
    token = stub_netpar_token
    stub_netpar_search
    2.times { @client.find_certificate(@search, remote_ip: "203.0.113.5") }

    assert_requested token.with(basic_auth: [ "confirmation", "secret" ]), times: 1
  end

  test "wygasły token: pobranie nowego i ponowienie zapytania" do
    stub_netpar_token
    stub_request(:get, "#{NETPAR_URL}/certificates/mor_search_by_multi_params")
      .to_return({ status: 401, body: "{}" }, { status: 200, body: { certificates: [ netpar_certificate ] }.to_json })

    assert @client.find_certificate(@search, remote_ip: "203.0.113.5")
  end

  test "brak danych w rejestrze" do
    stub_netpar_token
    stub_netpar_search(status: 404)

    assert_nil @client.find_certificate(@search, remote_ip: "203.0.113.5")
  end

  test "świadectwo bezterminowe" do
    stub_netpar_token
    stub_netpar_search(body: { certificates: [ netpar_certificate("valid_thru" => "") ] })

    assert @client.find_certificate(@search, remote_ip: "203.0.113.5").unlimited?
  end

  test "kategorie L i R: osobny endpoint z parametrem category" do
    search = CertificateSearch.new(valid_search_params(division_id: 7, number: "1234").merge(category_slug: "aeronautical")).tap(&:valid?)
    stub_netpar_token
    request = stub_netpar_search(path: "certificates/search_by_multi_params")

    @client.find_certificate(search, remote_ip: "203.0.113.5")

    assert_requested request.with { JSON.parse(it.body).values_at("category", "number_prefix") == %w[L L-] }
  end

  test "błędy usługi zgłaszane jako niedostępność" do
    stub_netpar_token
    {
      "błąd serwera" => -> { stub_netpar_search(status: 500) },
      "strona HTML zamiast JSON" => -> { stub_netpar_search(status: 404, body: "<html>Not Found</html>") },
      "przekroczony czas" => -> { stub_request(:get, /mor_search_by_multi_params/).to_timeout },
      "brak połączenia" => -> { stub_request(:get, /mor_search_by_multi_params/).to_raise(Errno::ECONNREFUSED) },
      "niekompletna odpowiedź" => -> { stub_netpar_search(body: { certificates: [ { "number" => "GG-1" } ] }) },
      "200 z treścią null (brak endpointu w NETPAR)" => -> { stub_netpar_search(body: "null") },
      "200 bez listy świadectw" => -> { stub_netpar_search(body: { "id" => 1 }) }
    }.each do |name, stub|
      WebMock.reset!
      stub_netpar_token
      stub.call
      assert_raises(Netpar::Unavailable, name) { @client.find_certificate(@search, remote_ip: "203.0.113.5") }
    end
  end
end
