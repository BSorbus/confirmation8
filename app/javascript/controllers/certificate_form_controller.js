import { Controller } from "@hotwired/stimulus"

// Formularz wyszukiwania: prefiks numeru zgodny z wybranym rodzajem świadectwa, informacja o dacie wydania, od której
// rodzaj podlega weryfikacji (ustawiana w NETPAR), oraz wyłączanie daty ważności dla świadectw bezterminowych.
// Formularz działa też bez JavaScriptu – to tylko ułatwienia.
export default class extends Controller {
  static targets = ["division", "prefix", "issuedFromHint", "validThru", "noExpiry", "errorSummary"]

  connect() {
    this.updatePrefix()
    this.toggleExpiry()
    if (this.hasErrorSummaryTarget) this.errorSummaryTarget.focus()
  }

  updatePrefix() {
    const option = this.divisionTarget.selectedOptions[0]
    this.prefixTarget.textContent = option?.dataset.prefix || "–"
    if (this.hasIssuedFromHintTarget) {
      const date = option?.dataset.issuedFrom
      this.issuedFromHintTarget.hidden = !date
      this.issuedFromHintTarget.textContent = date ? this.issuedFromHintTarget.dataset.template.replace("%{date}", date) : ""
    }
  }

  toggleExpiry() {
    const noExpiry = this.noExpiryTarget.checked
    this.validThruTarget.disabled = noExpiry
    if (noExpiry) this.validThruTarget.value = ""
  }
}
