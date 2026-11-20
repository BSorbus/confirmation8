# Zaświadczenie PDF. Dane świadectwa są za każdym razem ponownie potwierdzane w NETPAR –
# nie da się wygenerować zaświadczenia z danymi, których NETPAR nie potwierdził.
class StatementsController < ApplicationController
  rate_limit to: SEARCH_RATE_LIMIT, within: 1.minute, with: -> { redirect_back_to_form(t(".too_many_requests")) }

  before_action :set_category
  # Zaświadczenie z danymi posiadacza – bez zapisu w pamięci podręcznej; plik pobiera się normalnie (attachment).
  before_action :no_store

  def create
    search = build_search
    certificate = @category.statement? && @category.enabled? && search.valid? && netpar.find_certificate(search, remote_ip: request.remote_ip)
    return redirect_back_to_form(t(".not_confirmed")) unless certificate
    # Adres do kodu QR buduje wyłącznie NETPAR – bez niego (NETPAR bez verification_url) zaświadczenia nie wydajemy.
    raise Netpar::Unavailable, "brak verification_url w odpowiedzi NETPAR" if certificate.verification_url.blank?

    pdf = PdfStatement.new(certificate)
    # Od razu jako plik (attachment), nie podgląd w karcie (inline): przy zapisie z podglądu przeglądarka pobiera adres
    # ponownie metodą GET, bez danych formularza – trasy GET nie ma (dane osobowe nie trafiają do adresu), więc 404
    # i „Plik nie był dostępny w witrynie” (zgłoszenie 2026-11).
    send_data pdf.render, filename: pdf.file_name, type: "application/pdf", disposition: "attachment"
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    redirect_back_to_form(t(".unavailable"))
  end

  private
    def redirect_back_to_form(message)
      redirect_to category_certificates_path(@category || Category.default), alert: message
    end
end
