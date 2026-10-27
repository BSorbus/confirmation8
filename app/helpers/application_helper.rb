module ApplicationHelper
  # Data w formacie dd.mm.rrrr (jak na świadectwach).
  def display_date(date)
    date&.strftime("%d.%m.%Y")
  end

  # Parametry linku z kodu QR, które przenosimy przy zmianie języka (tylko te – nie przekazujemy dowolnych).
  LINK_PARAMS = %w[number_prefix number date_of_issue valid_thru name given_names birth_date].freeze

  # Ta sama strona w innym języku (formularz zachowuje dane z linku QR, jeśli jest to zwykłe wyświetlenie).
  def same_page_path(locale)
    if @category
      query = request&.get? ? request.query_parameters.slice(*LINK_PARAMS).symbolize_keys : {}
      category_certificates_path(@category, locale:, **query)
    elsif controller_name == "pages"
      declaration_path(locale:)
    else
      root_path(locale:)
    end
  end

  def other_locale_links
    I18n.available_locales.map do |locale|
      current = locale == I18n.locale
      link_to locale.to_s.upcase, same_page_path(locale),
              lang: locale, hreflang: locale, class: [ "lang-switch__link", ("is-current" if current) ],
              aria: { current: (current ? "true" : nil), label: t("layouts.header.language.#{locale}") }
    end.join.html_safe
  end
end
