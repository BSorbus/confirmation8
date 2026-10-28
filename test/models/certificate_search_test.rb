require "test_helper"

class CertificateSearchTest < ActiveSupport::TestCase
  def search(overrides = {})
    CertificateSearch.new({ category_slug: "maritime" }.merge(valid_search_params(overrides)))
  end

  test "poprawne dane morskie" do
    assert search.valid?
  end

  test "numer morski musi mieć dokładnie 5 cyfr" do
    record = search(number: "5998")
    assert_not record.valid?
    assert_equal [ :number_exact_digits ], record.errors.details[:number].map { it[:error] }
  end

  test "numer lotniczy i radioamatorski: od 2 do 5 cyfr" do
    aero = CertificateSearch.new(valid_search_params(division_id: 7, number: "12").merge(category_slug: "aeronautical"))
    assert aero.valid?
    aero.number = "123456"
    assert_not aero.valid?
    assert_equal :number_digits_range, aero.errors.details[:number].first[:error]
  end

  test "rodzaj świadectwa musi należeć do wybranej kategorii" do
    assert_not search(division_id: 7).valid? # 7 = lotnicze
    assert_not search(division_id: nil).valid?
  end

  test "data ważności wymagana, chyba że świadectwo jest bezterminowe" do
    assert_not search(valid_thru: "").valid?
    record = search(valid_thru: "2030-01-01", no_expiry: "1")
    assert record.valid?
    assert_equal "", record.to_netpar_params[:valid_thru]
  end

  test "daty muszą być poprawne" do
    record = search(date_of_issue: "2018-13-40")
    assert_not record.valid?
    assert_equal :invalid_date, record.errors.details[:date_of_issue].first[:error]
  end

  test "normalizacja: spacje w nazwiskach i numerze" do
    record = search(name: "  Kozłowski  ", given_names: "Jan    Maria", number: " 05 998 ")
    assert record.valid?
    assert_equal "Kozłowski", record.name
    assert_equal "Jan Maria", record.given_names
    assert_equal "05998", record.number
  end

  test "błędy w kolejności pól formularza" do
    record = CertificateSearch.new(category_slug: "maritime", date_of_issue: "2018-13-45")
    record.validate
    assert_equal %i[division_id number date_of_issue valid_thru name given_names birth_date], record.error_attributes_in_form_order
  end

  test "komunikaty po polsku pasują do każdego pola (bez odmiany „puste/pusty/pusta”)" do
    I18n.with_locale(:pl) do
      record = CertificateSearch.new(category_slug: "maritime", division_id: 11, no_expiry: "1")
      record.validate
      assert_equal "Numer świadectwa – to pole jest wymagane", record.errors.full_messages_for(:number).first
      assert_equal "Data wydania – to pole jest wymagane", record.errors.full_messages_for(:date_of_issue).first
      assert_equal "Imiona – to pole jest wymagane", record.errors.full_messages_for(:given_names).first
      record.name = "x" * 101
      record.validate
      assert_equal "Nazwisko – maksymalnie 100 znaków", record.errors.full_messages_for(:name).first
    end
  end

  test "parametry dla NETPAR" do
    assert_equal({ number_prefix: "GG-", number: "05998", date_of_issue: "2018-08-30", valid_thru: "2028-08-30",
                   name: "kozlowski", given_names: "JAN MARIA", birth_date: "1969-07-06" }, search.tap(&:valid?).to_netpar_params)
  end

  test "wypełnienie z linku w kodzie QR" do
    link = ActionController::Parameters.new(number_prefix: "GS-", number: "12345", date_of_issue: "2019-01-01", valid_thru: "",
                                            name: "Kowalski", given_names: "Jan", birth_date: "1970-01-01")
    record = CertificateSearch.from_link(link, Category.find("maritime"))
    assert_equal 14, record.division_id
    assert record.no_expiry
    assert record.valid?
  end
end
