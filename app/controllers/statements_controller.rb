# Zaświadczenie PDF. Dane świadectwa są za każdym razem ponownie potwierdzane w NETPAR –
# nie da się wygenerować zaświadczenia z danymi, których NETPAR nie potwierdził.
class StatementsController < ApplicationController
  rate_limit to: 10, within: 1.minute, with: -> { redirect_back_to_form(t(".too_many_requests")) }

  before_action :set_category

  def create
    search = build_search
    certificate = search.valid? && @category.statement? && netpar.find_certificate(search, remote_ip: request.remote_ip)
    return redirect_back_to_form(t(".not_confirmed")) unless certificate

    pdf = PdfStatement.new(certificate, search_url: Rails.configuration.x.confirmation[:search_url])
    send_data pdf.render, filename: pdf.file_name, type: "application/pdf", disposition: "inline"
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    redirect_back_to_form(t(".unavailable"))
  end

  private
    def redirect_back_to_form(message)
      redirect_to category_certificates_path(@category || Category.default), alert: message
    end
end
