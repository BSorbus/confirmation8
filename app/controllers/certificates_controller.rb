class CertificatesController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: :create, with: -> { set_category; render_outcome(:too_many_requests, :too_many_requests) }

  before_action :set_category

  def new
    @search = if params[:number].present? || params[:name].present?
      CertificateSearch.from_link(params, @category)
    else
      CertificateSearch.new(category_slug: @category.slug)
    end
  end

  def create
    @search = build_search

    if @search.invalid?
      render_outcome(:invalid, :unprocessable_content)
    elsif (@certificate = netpar.find_certificate(@search, remote_ip: request.remote_ip))
      render_outcome(:found, :ok)
    else
      render_outcome(:not_found, :ok)
    end
  rescue Netpar::Unavailable => e
    Rails.logger.error("[NETPAR] #{e.message}")
    render_outcome(:unavailable, :service_unavailable)
  end

  private
    def render_outcome(outcome, status)
      @outcome = outcome
      @search ||= CertificateSearch.new(category_slug: @category.slug)
      respond_to do |format|
        format.turbo_stream { render :create, status: }
        format.html { render :new, status: }
      end
    end
end
