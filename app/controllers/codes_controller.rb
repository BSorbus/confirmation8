# Kod QR karty plastikowej i zaświadczenia: /qrc/<kod> – od razu wynik weryfikacji (bez klikania „Sprawdź”), na stronie
# formularza: pola wypełnione danymi świadectwa, po prawej wynik i przycisk zaświadczenia PDF (jak po wyszukaniu).
# Kod świadectwa (losowy, nadaje NETPAR) ma posiadacz karty / zaświadczenia; dane – aktualne z NETPAR (search_by_code).
# Adres neutralny – nie zdradza, czego dotyczy kod.
class CodesController < CertificatesController
  skip_before_action :set_category, :require_enabled_category
  rate_limit to: SEARCH_RATE_LIMIT, within: 1.minute, only: :show, with: -> { render_too_many_requests }

  def show
    case (result = netpar.find_by_code(params[:code], remote_ip: request.remote_ip))
    when Certificate
      @category = Category.for_code(result.category)
      return render_code_outcome(:not_found) unless @category&.enabled? # kategoria wyłączona na tym serwerze

      @certificate = result
      @search = CertificateSearch.from_link(link_params(result), @category)
      render_code_outcome(:found)
    when :type_not_verifiable
      render_code_outcome(:type_not_verifiable)
    else
      render_code_outcome(:not_found)
    end
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    @category = Category.default
    render_outcome(:unavailable, :service_unavailable)
  end

  private
    def render_code_outcome(outcome)
      @category ||= Category.default
      @search = CertificateSearch.new(category_slug: @category.slug) unless outcome == :found
      @outcome = outcome
      render "certificates/new", status: :ok
    end

    # Dane świadectwa w postaci parametrów linku (jak w kodzie QR zaświadczenia) – wypełniają formularz i ukryte pola PDF.
    def link_params(certificate)
      prefix = certificate.division.number_prefix.to_s
      { number_prefix: prefix,
        number: certificate.number.delete_prefix(prefix),
        date_of_issue: certificate.date_of_issue.to_s,
        valid_thru: certificate.valid_thru.to_s,
        name: certificate.holder.name,
        given_names: certificate.holder.given_names,
        birth_date: certificate.holder.birth_date.to_s
      }
    end
end
