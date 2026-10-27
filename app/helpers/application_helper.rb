module ApplicationHelper
  # Data w formacie dd.mm.rrrr (jak na świadectwach).
  def display_date(date)
    date&.strftime("%d.%m.%Y")
  end

  # Ta sama strona w innym języku (formularz zachowuje dane z linku QR, jeśli jest to zwykłe wyświetlenie).
  def same_page_path(locale)
    if @category
      query = request&.get? ? request.query_parameters.except("locale") : {}
      category_certificates_path(@category, query.merge(locale:))
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
