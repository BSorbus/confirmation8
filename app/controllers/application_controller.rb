class ApplicationController < ActionController::Base
  # Publiczna strona urzędu – bez blokowania starszych przeglądarek (allow_browser).

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Limit wyszukiwań i pobrań PDF z jednego adresu IP (rate_limit w kontrolerach).
  SEARCH_RATE_LIMIT = 50

  around_action :switch_locale

  def default_url_options = { locale: I18n.locale }

  private
    def switch_locale(&)
      I18n.with_locale(params[:locale] || I18n.default_locale, &)
    end

    def set_category
      @category = params[:category] ? Category.find(params[:category]) : Category.default
      raise ActionController::RoutingError, "Nieobsługiwana kategoria" unless @category
    end

    def build_search
      permitted = params.expect(certificate_search: %i[division_id number date_of_issue valid_thru no_expiry name given_names birth_date])
      CertificateSearch.new(permitted.merge(category_slug: @category.slug))
    end

    def netpar = Netpar::Client.new
end
