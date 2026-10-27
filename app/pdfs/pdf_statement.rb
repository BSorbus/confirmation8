# Zaświadczenie PDF. Zatwierdzony dokument – teksty, układ, czcionki i kod QR są przeniesione 1:1
# z poprzedniej wersji aplikacji (app/pdfs/pdf_statement.rb). Nie zmieniać bez zgody urzędu.
# Jedyna różnica: dane pochodzą z odpowiedzi API NETPAR (Certificate), a nie z parametrów adresu URL.
class PdfStatement < Prawn::Document
  FONTS_DIR = Rails.root.join("vendor/fonts")
  LOGO = Rails.root.join("app/assets/images/logo_uke_en_do_lewej.png")

  def initialize(certificate, search_url:, author: "UKE")
    @certificate = certificate
    @search_url = search_url

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
      image LOGO.to_s, :at => [0, 780], :height => 25
      stroke_line [0,735], [525,735], self.line_width = 0.1
    end

    def qrcode
      print_qr_code(qrcode_content, pos: [390, 170], extent: 144, stroke: false, level: :m)
    end

    def header_right_corner
      draw_text "Gdynia, " + Time.current.strftime('%Y-%m-%d'), :at => [400, 710], size: 11
    end

    def data
      cert = @certificate
      valid_thru = cert.valid_thru.present? ? "#{cert.valid_thru}" : "---------- (without expiry date)"

      draw_text "Confirmation #{cert.division.short_name}", :at => [0, 610], size: 14

      draw_text "Office of Electronic Communications informs that the certificate:", :at => [0, 560], size: 11

      draw_text "Type:", :at => [70, 520], size: 11
            draw_text "#{cert.division.english_name} (#{cert.division.short_name})", :at => [150, 520], size: 11
      draw_text "No.:", :at => [70, 500], size: 11
            draw_text "#{cert.number}", :at => [150, 500], size: 11
      draw_text "Date of issue:", :at => [70, 480], size: 11
            draw_text "#{cert.date_of_issue}", :at => [150, 480], size: 11
      draw_text "Valid till:", :at => [70, 460], size: 11
            draw_text "#{valid_thru}", :at => [150, 460], size: 11

      draw_text "has been issued for #{cert.holder.name} #{cert.holder.given_names} (date of birth #{cert.holder.birth_date}).", :at => [0, 420], size: 11

      text_box "The above certificate has been issued according to ITU Radio Regulations and the IMO STCW Convention by the " +
               "President of the Office of Electronic Communications.", size: 11, :align => :justify,
        :at => [0, 380],
        :width => 525,
        :height => 300
    end

    def footer
      stroke_color "BECC25"
      stroke_line [0, 10], [525,10], self.line_width = 2.0
      text "generated from https://confirmation.uke.gov.pl,  e-mail: ske.gdynia@uke.gov.pl,  © 2018 UKE", size: 6, :style => :italic, :align => :right, :valign => :bottom
    end
end
