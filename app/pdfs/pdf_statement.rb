# Zaświadczenie PDF. Zatwierdzony dokument – teksty, układ, czcionki i kod QR są przeniesione 1:1
# z poprzedniej wersji aplikacji (app/pdfs/pdf_statement.rb). Nie zmieniać bez zgody urzędu.
# Różnice: dane pochodzą z odpowiedzi API NETPAR (Certificate), a nie z parametrów adresu URL; teksty zależne
# od kategorii świadectwa (język, miejsce, tytuł, podstawa wydania, e-mail) – z config/statements.yml (M bez zmian).
class PdfStatement < Prawn::Document
  FONTS_DIR = Rails.root.join("vendor/fonts")
  IMAGES_DIR = Rails.root.join("app/assets/images")
  PAGE_WIDTH = 525
  LABEL_X = 20 # etykiety Type / No. / Date of issue / Valid till (do 2026-10-31: 70)

  def initialize(certificate, search_url:, author: "UKE")
    @certificate = certificate
    @search_url = search_url
    statements = Rails.configuration.x.statements
    category = statements[:categories].fetch(certificate.category.to_sym)
    # Teksty kategorii, nadpisane tekstami rodzaju świadectwa (np. zaświadczenia kat. 1 i 3 w służbie amatorskiej).
    @texts = category.merge(category.dig(:divisions, certificate.division.short_name.to_s.to_sym) || {})
    @labels = statements[:labels].fetch(@texts[:language].to_sym)

    super(:page_size => "A4",
          :page_layout => :portrait,
          :info => {
                      :Title        => file_name,
                      :Author       => author,
                      :Subject      => "",
                      :CreationDate => Time.current,
                    }
          )

    font_families.update("DejaVu Sans" => {
      :normal => FONTS_DIR.join("DejaVuSans.ttf").to_s,
      :bold  => FONTS_DIR.join("DejaVuSans-Bold.ttf").to_s,
      :italic => FONTS_DIR.join("DejaVuSans-Oblique.ttf").to_s,
      :bold_italic => FONTS_DIR.join("DejaVuSans-BoldOblique.ttf").to_s
    })
    font "DejaVu Sans", size: 11

    logo
    header_right_corner
    qrcode
    data
    footer
  end

  def file_name = "#{@certificate.number}.pdf"

  # Adres w kodzie QR – te same parametry co w poprzedniej wersji; otwiera formularz z wypełnionymi danymi.
  def qrcode_content
    cert = @certificate
    "#{@search_url}?" + URI.encode_www_form(
      number_prefix: cert.division.number_prefix,
      number: cert.number.delete_prefix(cert.division.number_prefix.to_s),
      date_of_issue: cert.date_of_issue.to_s,
      valid_thru: cert.valid_thru.to_s,
      name: cert.holder.name,
      given_names: cert.holder.given_names,
      birth_date: cert.holder.birth_date.to_s
    )
  end

  private
    def logo
      image IMAGES_DIR.join(@labels[:logo]).to_s, :at => [0, 780], :height => 25
      stroke_line [0,735], [525,735], self.line_width = 0.1
    end

    def qrcode
      print_qr_code(qrcode_content, pos: [390, 170], extent: 144, stroke: false, level: :m)
    end

    def header_right_corner
      draw_text "#{@texts[:place]}, " + Time.current.strftime('%Y-%m-%d'), :at => [400, 710], size: 11
    end

    def data
      cert = @certificate
      valid_thru = cert.valid_thru.present? ? "#{cert.valid_thru}" : @labels[:no_expiry]

      title

      draw_text @texts[:intro] || @labels[:intro], :at => [0, 560], size: 11

      draw_text @labels[:type], :at => [LABEL_X, 520], size: 11
            draw_text type_value, :at => [value_x, 520], size: type_size
      draw_text @labels[:number], :at => [LABEL_X, 500], size: 11
            draw_text "#{cert.number}", :at => [value_x, 500], size: 11
      draw_text @labels[:date_of_issue], :at => [LABEL_X, 480], size: 11
            draw_text "#{cert.date_of_issue}", :at => [value_x, 480], size: 11
      draw_text @labels[:valid_thru], :at => [LABEL_X, 460], size: 11
            draw_text "#{valid_thru}", :at => [value_x, 460], size: 11

      draw_text format(@labels[:holder], holder: "#{cert.holder.name} #{cert.holder.given_names}", birth_date: cert.holder.birth_date), :at => [0, 420], size: 11

      text_box basis, size: 11, :align => :justify,
        :at => [0, 380],
        :width => 525,
        :height => 300
    end

    # Tytuł (14 pt) w jednym wierszu; dłuższy niż szerokość strony (np. pełna nazwa świadectwa w służbie
    # radiokomunikacyjnej amatorskiej) – zawinięty, z tym samym położeniem pierwszego wiersza.
    def title
      text = format(@texts[:title], short_name: @certificate.division.short_name)
      if width_of(text, size: 14) <= PAGE_WIDTH
        draw_text text, :at => [0, 610], size: 14
      else
        font_size(14) { text_box text, :at => [0, 610 + font.ascender], :width => PAGE_WIDTH, :height => 40 }
      end
    end

    # Kolumna wartości (rodzaj, numer, daty) – zależy od długości etykiet w danym języku.
    def value_x = @labels[:value_x]

    def type_value
      division = @certificate.division
      # Brak angielskiej nazwy w NETPAR (np. CSO, IWC, rodzaje radioamatorskie) – nazwa polska.
      format(@labels[:type_value], name: division.name, english_name: division.english_name.presence || division.name, short_name: division.short_name)
    end

    # Długie nazwy rodzajów (np. polskie „zaświadczenie uprawniające do uzyskania pozwolenia radiowego kat. 1”)
    # pomniejszone tak, by mieściły się w wierszu; krótsze – bez zmian (11 pt).
    def type_size
      available = PAGE_WIDTH - value_x
      width = width_of(type_value, size: 11)
      width > available ? (11 * available / width).floor(1) : 11
    end

    # Podstawa wydania; dla niektórych rodzajów (skrót z NETPAR) dodatkowe zdanie, np. HAREC dla klasy A.
    def basis = [ @texts[:basis], @texts[:extra] ].compact.join(" ")

    def footer
      stroke_color "BECC25"
      stroke_line [0, 10], [525,10], self.line_width = 2.0
      # Rok końcowy – bieżący (zmiana zatwierdzona 2026-10-27; wcześniej „© 2018 UKE”).
      text format(@labels[:generated], email: @texts[:email], year: Time.current.year), size: 6, :style => :italic, :align => :right, :valign => :bottom
    end
end
