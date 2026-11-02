class CertificatesController < ApplicationController
  rate_limit to: SEARCH_RATE_LIMIT, within: 1.minute, only: :create, with: -> { render_too_many_requests }

  before_action :require_divisions, :set_category, :require_enabled_category

  def new
    if params[:number].present? || params[:name].present?
      @search = CertificateSearch.from_link(params, @category)
      @category = @search.category # zakładka i lista rodzajów wg prefiksu z linku w kodzie QR (QR nie niesie kategorii)
    else
      @search = CertificateSearch.new(category_slug: @category.slug)
    end
  end

  def create
    @search = build_search

    return render_outcome(:invalid, :unprocessable_content) if @search.invalid?

    case (result = netpar.find_certificate(@search, remote_ip: request.remote_ip))
    when Certificate
      @certificate = result
      render_outcome(:found, :ok)
    when :type_not_verifiable # dane zgodne, ale rodzaj wyłączony z weryfikacji internetowej (NETPAR 403)
      render_outcome(:type_not_verifiable, :ok)
    else
      render_outcome(:not_found, :ok)
    end
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    render_outcome(:unavailable, :service_unavailable)
  end

  private
    # Rodzaje i kategorie (zakładki) pochodzą z NETPAR – bez nich pokazujemy komunikat o niedostępności.
    def require_divisions
      render_unavailable unless netpar_available?
    end

    def require_enabled_category
      raise ActionController::RoutingError, "Kategoria niewłączona w NETPAR" unless @category.enabled?
    end

    def netpar_available?
      Division.all
      true
    rescue Netpar::Unavailable => e
      Rails.logger.error("[NETPAR] #{e.message}")
      false
    end

    # Formularz bez zakładek i listy rodzajów, z komunikatem o niedostępności.
    def render_unavailable
      @category = Category.find(params[:category]) || Category::ALL.first
      render_outcome(:unavailable, :service_unavailable)
    end

    def render_too_many_requests
      return render_unavailable unless netpar_available?

      set_category
      render_outcome(:too_many_requests, :too_many_requests)
    end

    def render_outcome(outcome, status)
      @outcome = outcome
      @search ||= CertificateSearch.new(category_slug: @category.slug)
      respond_to do |format|
        format.turbo_stream { render :create, status: }
        format.html { render :new, status: }
      end
    end
end
