require "test_helper"
require "pdf-reader"

class PdfStatementTest < ActiveSupport::TestCase
  setup do
    @certificate = Certificate.from_api(netpar_certificate)
    @pdf = PdfStatement.new(@certificate, search_url: "https://confirmation.uke.gov.pl/certificates/new")
  end

  def text_lines
    PDF::Reader.new(StringIO.new(@pdf.render)).pages.first.text.lines.map(&:strip).reject(&:empty?)
  end

  # Treść zatwierdzonego dokumentu – identyczna jak w poprzedniej wersji aplikacji.
  test "teksty zaświadczenia" do
    text = text_lines.join("\n")
    [
      "Gdynia, #{Time.current.strftime('%Y-%m-%d')}",
      "Confirmation GOC",
      "Office of Electronic Communications informs that the certificate:",
      "General operator's certificate (GOC)",
      "GG-05998",
      "2018-08-30",
      "2028-08-30",
      "has been issued for Kozłowski Jan Maria (date of birth 1969-07-06)."
    ].each { assert_includes text, it }
    # pdf-reader skleja wielokrotne spacje przy odczycie – porównujemy po ich ujednoliceniu.
    assert_includes text.squish, "generated from https://confirmation.uke.gov.pl,  e-mail: ske.gdynia@uke.gov.pl,  © 2018–#{Time.current.year} UKE".squish
    assert_includes text.squish, "The above certificate has been issued according to ITU Radio Regulations and the IMO STCW Convention by the President of the Office of Electronic Communications."
  end

  test "świadectwo bezterminowe" do
    @pdf = PdfStatement.new(Certificate.from_api(netpar_certificate("valid_thru" => "")), search_url: "x")
    assert_includes text_lines.join("\n"), "---------- (without expiry date)"
  end

  test "kod QR prowadzi do formularza z danymi (te same parametry co w poprzedniej wersji)" do
    assert_equal "https://confirmation.uke.gov.pl/certificates/new?number_prefix=GG-&number=05998&date_of_issue=2018-08-30" \
                 "&valid_thru=2028-08-30&name=Koz%C5%82owski&given_names=Jan+Maria&birth_date=1969-07-06", @pdf.qrcode_content
  end

  test "metadane dokumentu" do
    info = PDF::Reader.new(StringIO.new(@pdf.render)).info
    assert_equal "GG-05998.pdf", info[:Title]
    assert_equal "UKE", info[:Author]
  end
  # Teksty L i R – z config/statements.yml (nowe, przygotowane na wzór M).
  def pdf_text_for(overrides)
    pdf = PdfStatement.new(Certificate.from_api(netpar_certificate(overrides)), search_url: "x")
    PDF::Reader.new(StringIO.new(pdf.render)).pages.first.text.squish
  end

  test "świadectwo lotnicze (L) – po angielsku" do
    text = pdf_text_for("category" => "L", "number" => "L-12345",
                        "division" => { "name" => "świadectwo ogólne operatora radiotelefonisty", "short_name" => "OR", "number_prefix" => "L-",
                                        "english_name" => "the radiotelephone operator's general certificate" })
    assert_includes text, "Warszawa, #{Time.current.strftime("%Y-%m-%d")}"
    assert_includes text, "Confirmation OR"
    assert_includes text, "the radiotelephone operator's general certificate (OR)"
    assert_includes text, "The above certificate has been issued by the President of the Office of Electronic Communications as the Polish authority " \
                          "competent to issue radio operator's certificates in the aeronautical radiocommunication service, in accordance with " \
                          "the international radio regulations."
    assert_includes text, "e-mail: wml@uke.gov.pl"
    assert_not_includes text, "STCW"
  end

  test "świadectwo amatorskie klasy A (R) – po polsku, art. 95 ust. 2, kategoria 1" do
    text = pdf_text_for("category" => "R", "number" => "A-1234", "valid_thru" => "",
                        "division" => { "name" => "świadectwo klasy A operatora urządzeń radiowych", "short_name" => "A", "number_prefix" => "A-", "english_name" => "" })
    [
      "Warszawa, #{Time.current.strftime("%Y-%m-%d")}",
      "Potwierdzenie świadectwa operatora urządzeń radiowych w służbie radiokomunikacyjnej amatorskiej",
      "Urząd Komunikacji Elektronicznej informuje, że świadectwo:",
      "Rodzaj: świadectwo klasy A operatora urządzeń radiowych",
      "Nr: A-1234",
      "Data wydania: 2018-08-30",
      "Ważne do: ---------- (bezterminowe)",
      "zostało wydane dla: Kozłowski Jan Maria (data urodzenia 1969-07-06).",
      "Powyższe świadectwo zostało wydane przez Prezesa Urzędu Komunikacji Elektronicznej; na podstawie art. 95 ust. 2 ustawy " \
      "z dnia 12 lipca 2024 r. – Przepisy wprowadzające ustawę – Prawo komunikacji elektronicznej zachowuje moc i jest " \
      "równoważne zaświadczeniu o pozytywnym wyniku egzaminu, o którym mowa w art. 143 ust. 2 ustawy – Prawo komunikacji " \
      "elektronicznej. Uprawnia do ubiegania się o pozwolenie radiowe kategorii 1, wydawane z uwzględnieniem zalecenia " \
      "CEPT T/R 61-01.",
      "wygenerowano z https://confirmation.uke.gov.pl, e-mail: wml@uke.gov.pl, © 2018–#{Time.current.year} UKE"
    ].each { assert_includes text, it }
    assert_not_includes text, "Office of Electronic Communications"
    assert_not_includes text, "HAREC"
  end

  test "świadectwa amatorskie klas B, C, D – kategoria pozwolenia, bez HAREC i ERC Report 32" do
    division = { "name" => "x", "number_prefix" => "C-", "english_name" => "" }
    { "B" => "kategorii 1, wydawane z uwzględnieniem zalecenia CEPT T/R 61-01.",
      "C" => "kategorii 3, wydawane z uwzględnieniem Zalecenia ECC (05)06 CEPT.",
      "D" => "kategorii 3, wydawane z uwzględnieniem Zalecenia ECC (05)06 CEPT." }.each do |short_name, sentence|
      text = pdf_text_for("category" => "R", "division" => division.merge("short_name" => short_name))
      assert_includes text, sentence
      assert_not_includes text, "HAREC"
      assert_not_includes text, "ERC Report"
    end
  end

  test "brak angielskiej nazwy rodzaju w NETPAR (np. CSO) – nazwa polska" do
    text = pdf_text_for("division" => { "name" => "świadectwo operatora stacji nadbrzeżnej CSO", "english_name" => "", "short_name" => "CSO" })
    assert_includes text, "Type: świadectwo operatora stacji nadbrzeżnej CSO (CSO)"
  end

  test "zaświadczenie kat. 1 (R) – własny tytuł i podstawa, HAREC; długa nazwa rodzaju mieści się w wierszu" do
    name = "zaświadczenie uprawniające do uzyskania pozwolenia radiowego kat. 1"
    text = pdf_text_for("category" => "R", "number" => "I-123", "division" => { "name" => name, "short_name" => "1", "number_prefix" => "I-" })
    [
      "Potwierdzenie zaświadczenia uprawniającego do uzyskania pozwolenia radiowego w służbie radiokomunikacyjnej amatorskiej",
      "Urząd Komunikacji Elektronicznej informuje, że zaświadczenie:",
      "Rodzaj: #{name}",
      "Powyższe zaświadczenie o pozytywnym wyniku egzaminu, o którym mowa w art. 143 ust. 2 ustawy z dnia 12 lipca 2024 r. – " \
      "Prawo komunikacji elektronicznej, zostało wydane przez Prezesa Urzędu Komunikacji Elektronicznej. Złożony egzamin " \
      "odpowiada wymaganiom egzaminacyjnym, określonym w zaleceniu CEPT T/R 61-02 (HAREC)."
    ].each { assert_includes text, it }
    assert_not_includes text, "Regulaminem Radiokomunikacyjnym"
  end

  test "zaświadczenie kat. 3 (R) – ERC Report 32" do
    text = pdf_text_for("category" => "R", "division" => { "name" => "zaświadczenie … kat. 3", "short_name" => "3", "number_prefix" => "III-" })
    assert_includes text, "informuje, że zaświadczenie:"
    assert_includes text, "określonym w ERC Report 32."
  end
end
