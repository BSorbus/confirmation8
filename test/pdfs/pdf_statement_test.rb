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
    assert_includes text.squish, "generated from https://confirmation.uke.gov.pl,  e-mail: ske.gdynia@uke.gov.pl,  © 2018 UKE".squish
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
end
