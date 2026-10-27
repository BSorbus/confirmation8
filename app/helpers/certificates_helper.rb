module CertificatesHelper
  # Atrybuty dostępności pola: powiązanie z podpowiedzią i komunikatem błędu.
  def field_aria(search, attribute, hint: false)
    ids = []
    ids << "#{attribute}_hint" if hint
    ids << "#{attribute}_error" if search.errors.include?(attribute)
    { invalid: search.errors.include?(attribute) || nil, describedby: ids.join(" ").presence }
  end

  def field_error(search, attribute)
    return unless search.errors.include?(attribute)

    tag.span search.errors.full_messages_for(attribute).first, id: "#{attribute}_error", class: "field-error"
  end

  def division_options(category, selected)
    options = category.divisions.map { [ it.label, it.id, { "data-prefix" => it.number_prefix } ] }
    options_for_select(options, selected)
  end

  def validity_badge(certificate)
    if certificate.unlimited?
      tag.span t("certificates.result.unlimited"), class: "validity validity--unlimited"
    elsif certificate.expired?
      tag.span t("certificates.result.expired", date: display_date(certificate.valid_thru)), class: "validity validity--expired"
    else
      tag.span t("certificates.result.valid_until", date: display_date(certificate.valid_thru)), class: "validity validity--valid"
    end
  end
end
