require "test_helper"

class DivisionTest < ActiveSupport::TestCase
  test "wszystkie rodzaje z NETPAR w trzech kategoriach" do
    assert_equal 23, Division.all.size
    assert_equal %w[L M R], Division.all.map(&:category).uniq.sort
    assert_equal %w[G1E- G2E- GG- GR- GL- GS- MA- GC- IW-], Division.for_category("M").map(&:number_prefix)
  end

  test "nazwa angielska w wersji EN, polska gdy brak tłumaczenia" do
    assert_equal "General operator's certificate", Division.find(11).label(:en)
    assert_equal "świadectwo ogólne operatora GMDSS", Division.find(11).label(:pl)
    assert_equal "świadectwo operatora stacji nadbrzeżnej CSO", Division.find(16).label(:en)
  end

  test "na żywo: raz na żądanie, w kolejnym żądaniu ponownie z NETPAR" do
    api = stub_netpar_divisions([ { "id" => 1, "category" => "M", "number_prefix" => "GG-", "name" => "z API", "english_name" => "" } ])

    assert_equal [ "z API" ], Division.all.map(&:name)
    Division.for_category("M")
    assert_requested api, times: 1

    Current.reset # koniec żądania
    Division.all
    assert_requested api, times: 2
  end

  test "NETPAR niedostępny: błąd, bez lokalnej kopii" do
    stub_request(:get, "#{NETPAR_URL}/token").to_timeout

    assert_raises(Netpar::Unavailable) { Division.all }
    assert_empty Division.all, "do końca żądania bez ponownych prób"
  end

  # Rodzaj GOC (id 11) podlega weryfikacji od 2018-09-01 (divisions.confirmation_issued_from w NETPAR).
  def stub_goc_issued_from(date = "2018-09-01")
    stub_netpar_divisions(NETPAR_DIVISIONS.map { it["id"] == 11 ? it.merge("confirmation_issued_from" => date) : it })
    Current.reset
  end

  test "data, od której rodzaj podlega weryfikacji – z NETPAR; brak pola (starszy NETPAR) – bez ograniczenia" do
    stub_goc_issued_from
    goc = Division.find(11)
    assert_equal Date.new(2018, 9, 1), goc.confirmation_issued_from
    assert goc.issued_before_limit?(Date.new(2018, 8, 31))
    assert_not goc.issued_before_limit?(Date.new(2018, 9, 1)), "dzień graniczny włącznie"
    assert_nil Division.find(14).confirmation_issued_from
    assert_not Division.find(14).issued_before_limit?(Date.new(1990, 1, 1))
  end
end
