ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

module NetparStubs
  NETPAR_URL = "https://netpar.test/api/v1"
  # Rodzaje świadectw (nazwy jak w produkcyjnym NETPAR, stan na 2026-10-27) – w testach wszystkie włączone do weryfikacji.
  NETPAR_DIVISIONS = JSON.parse(File.read(File.expand_path("fixtures/files/netpar_divisions.json", __dir__))).freeze

  # Odpowiedź w formacie API NETPAR (api/v1/confirmation/certificates#search). Dane fikcyjne.
  def netpar_certificate(overrides = {})
    {
      "id" => 81115, "number" => "GG-05998", "date_of_issue" => "2018-08-30", "valid_thru" => "2028-08-30", "category" => "M",
      "division" => { "id" => 11, "name" => "świadectwo ogólne operatora GMDSS", "english_name" => "General operator's certificate",
                      "short_name" => "GOC", "number_prefix" => "GG-" },
      "customer" => { "id" => 1, "name" => "Kozłowski", "given_names" => "Jan Maria", "birth_date" => "1969-07-06" }
    }.deep_merge(overrides)
  end

  def stub_netpar_token(token: "tok-1")
    stub_request(:get, "#{NETPAR_URL}/token").to_return(status: 200, body: { token: }.to_json, headers: json_headers)
  end

  def stub_netpar_divisions(rows = NETPAR_DIVISIONS)
    stub_request(:get, "#{NETPAR_URL}/divisions").with(body: { enabled_in_confirmation: true })
      .to_return(status: 200, body: { divisions: rows, meta: { total_count: rows.size } }.to_json, headers: json_headers)
  end

  def stub_netpar_search(status: 200, body: nil, path: "confirmation/certificates/search")
    body ||= status == 200 ? { "certificates" => [ netpar_certificate ], "meta" => {} } : { "error" => "Brak danych / No data" }
    stub_request(:get, "#{NETPAR_URL}/#{path}").to_return(status:, body: body.is_a?(String) ? body : body.to_json, headers: json_headers)
  end

  def json_headers = { "Content-Type" => "application/json" }

  def valid_search_params(overrides = {})
    { division_id: 11, number: "05998", date_of_issue: "2018-08-30", valid_thru: "2028-08-30", no_expiry: "0",
      name: "kozlowski", given_names: "JAN MARIA", birth_date: "1969-07-06" }.merge(overrides)
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    include NetparStubs

    setup do
      Rails.cache.clear
      WebMock.disable_net_connect!
      stub_netpar_token
      stub_netpar_divisions
    end
  end
end

class ActionDispatch::IntegrationTest
  include NetparStubs
end
