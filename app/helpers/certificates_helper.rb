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

  # Pole daty ze sztywnym formatem RRRR-MM-DD (jak w poprzednich aplikacjach). Bazowo zwykłe pole tekstowe z maską
  # `pattern` – działa bez JavaScriptu; kontroler Stimulus "date-field" dodaje maskę wpisywania i natywny kalendarz.
  def iso_date_field(f, search, attribute, required: false, disabled: false, field_data: {})
    text = f.text_field attribute, class: "form-control form-control-sm", inputmode: "numeric", autocomplete: "off",
      maxlength: 10, pattern: '\d{4}-\d{2}-\d{2}', placeholder: t("certificates.form.date_format"),
      required: required, disabled: disabled, aria: field_aria(search, attribute),
      data: { "date-field-target": "text", action: "input->date-field#mask" }.merge(field_data)
    picker = tag.span class: "date-field__picker" do
      button = tag.button(calendar_icon, type: "button", class: "date-field__button", hidden: true,
        aria: { label: t("certificates.form.pick_date") },
        data: { "date-field-target": "button", action: "date-field#open" })
      native = tag.input(type: "date", class: "date-field__native", tabindex: -1, "aria-hidden": true,
        data: { "date-field-target": "native", action: "change->date-field#sync" })
      safe_join([ button, native ])
    end
    tag.div safe_join([ text, picker ]), class: "date-field", data: { controller: "date-field" }
  end

  def calendar_icon
    <<~SVG.html_safe
      <svg aria-hidden="true" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>
    SVG
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
