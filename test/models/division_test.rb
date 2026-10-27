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
end
