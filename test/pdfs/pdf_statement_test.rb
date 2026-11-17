require "test_helper"
require "pdf-reader"

class PdfStatementTest < ActiveSupport::TestCase
  setup do
    @certificate = Certificate.from_api(netpar_certificate)
    @pdf = PdfStatement.new(@certificate)
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
    @pdf = PdfStatement.new(Certificate.from_api(netpar_certificate("valid_thru" => "")))
    assert_includes text_lines.join("\n"), "---------- (without expiry date)"
  end

  test "kod QR – adres z NETPAR (verification_url), bez budowania po stronie confirmation8" do
    assert_equal netpar_certificate["verification_url"], @pdf.qrcode_content
  end

  test "metadane dokumentu" do
    info = PDF::Reader.new(StringIO.new(@pdf.render)).info
    assert_equal "GG-05998.pdf", info[:Title]
    assert_equal "UKE", info[:Author]
  end
  # Teksty L i R – z config/statements.yml (nowe, przygotowane na wzór M).
  def pdf_text_for(overrides)
    pdf = PdfStatement.new(Certificate.from_api(netpar_certificate(overrides)))
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

  # Tabela maxp osadzonych podzbiorów czcionki (config/initializers/ttfunk_maxp.rb): limity nie mniejsze niż rzeczywiste
  # glify – inaczej Adobe Acrobat odrzuca czcionkę i błędnie pokazuje polskie litery („ą” to glif złożony).
  test "polskie litery: osadzone czcionki z poprawną tabelą maxp (Acrobat)" do
    @pdf = PdfStatement.new(Certificate.from_api(netpar_certificate("customer" => netpar_certificate["customer"]
      .merge("name" => "Gątkiewicz-Żółć", "given_names" => "Łukasz Ęńś"))))
    data = @pdf.render
    assert_includes text_lines.join("\n"), "has been issued for Gątkiewicz-Żółć Łukasz Ęńś"

    fonts = embedded_truetype_fonts(data)
    assert_operator fonts.size, :>=, 2
    fonts.each do |name, font|
      maxp, actual = maxp_limits(font), glyph_maxima(font)
      assert_operator maxp[:max_size_of_instructions], :>=, actual[:max_size_of_instructions], "#{name}: maxSizeOfInstructions"
      assert_operator maxp[:max_points], :>=, actual[:max_points], "#{name}: maxPoints"
      assert_operator maxp[:max_contours], :>=, actual[:max_contours], "#{name}: maxContours"
      assert_operator maxp[:max_component_elements], :>=, actual[:max_component_elements], "#{name}: maxComponentElements"
      assert_operator maxp[:max_component_depth], :>=, (actual[:max_component_elements].positive? ? 1 : 0), "#{name}: maxComponentDepth"
    end
    assert fonts.any? { |_, font| glyph_maxima(font)[:max_component_elements].positive? }, "test powinien obejmować glif złożony (np. „ą”)"
  end

  test "łatka maxp przygotowana dla używanej wersji ttfunk" do
    assert_equal TTFUNK_MAXP_PATCHED_VERSION, Gem.loaded_specs["ttfunk"].version.to_s,
                 "Nowa wersja ttfunk – sprawdź, czy błąd maxp jest poprawiony (zaświadczenie z „ą” w Adobe Acrobat) " \
                 "i usuń albo dostosuj config/initializers/ttfunk_maxp.rb"
  end

  private
    def embedded_truetype_fonts(data)
      reader = PDF::Reader.new(StringIO.new(data))
      reader.objects.values.filter_map do |object|
        next unless object.is_a?(Hash) && object[:Type] == :FontDescriptor && object[:FontFile2]

        [ object[:FontName].to_s, reader.objects.deref(object[:FontFile2]).unfiltered_data ]
      end
    end

    def font_tables(font)
      count = font.byteslice(4, 2).unpack1("n")
      (0...count).to_h do |i|
        tag, _checksum, offset, length = font.byteslice(12 + 16 * i, 16).unpack("a4NNN")
        [ tag, font.byteslice(offset, length) ]
      end
    end

    def maxp_limits(font)
      values = font_tables(font)["maxp"].unpack("Nn14")
      %i[version num_glyphs max_points max_contours max_composite_points max_composite_contours max_zones max_twilight_points
         max_storage max_function_defs max_instruction_defs max_stack_elements max_size_of_instructions
         max_component_elements max_component_depth].zip(values).to_h
    end

    # Rzeczywiste maksima z tabeli glyf: instrukcje, punkty i kontury glifów prostych, liczba składników glifów złożonych.
    def glyph_maxima(font)
      tables = font_tables(font)
      num_glyphs = tables["maxp"].byteslice(4, 2).unpack1("n")
      short = tables["head"].byteslice(50, 2).unpack1("s>").zero?
      offsets = short ? tables["loca"].unpack("n*").map { it * 2 } : tables["loca"].unpack("N*")
      glyf = tables["glyf"]
      result = { max_size_of_instructions: 0, max_points: 0, max_contours: 0, max_component_elements: 0 }
      num_glyphs.times do |gid|
        start, stop = offsets[gid], offsets[gid + 1]
        next if stop - start < 10

        contours = glyf.byteslice(start, 2).unpack1("s>")
        if contours >= 0
          end_points = glyf.byteslice(start + 10, 2 * contours).unpack("n*")
          result[:max_contours] = [ result[:max_contours], contours ].max
          result[:max_points] = [ result[:max_points], (end_points.last || -1) + 1 ].max
          instructions = glyf.byteslice(start + 10 + 2 * contours, 2).unpack1("n")
          result[:max_size_of_instructions] = [ result[:max_size_of_instructions], instructions ].max
        else
          position, components = start + 10, 0
          loop do
            flags = glyf.byteslice(position, 2).unpack1("n")
            components += 1
            position += 4 + (flags & 1 == 1 ? 4 : 2)
            position += if flags & 8 != 0 then 2 elsif flags & 0x40 != 0 then 4 elsif flags & 0x80 != 0 then 8 else 0 end
            break if flags & 0x20 == 0
          end
          result[:max_component_elements] = [ result[:max_component_elements], components ].max
        end
      end
      result
    end
end
