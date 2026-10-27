import { Controller } from "@hotwired/stimulus"

// Formularz wyszukiwania: prefiks numeru zgodny z wybranym rodzajem świadectwa
// oraz wyłączanie daty ważności dla świadectw bezterminowych.
// Formularz działa też bez JavaScriptu – to tylko ułatwienia.
export default class extends Controller {
  static targets = ["division", "prefix", "validThru", "noExpiry", "errorSummary"]

  connect() {
    this.updatePrefix()
    this.toggleExpiry()
    if (this.hasErrorSummaryTarget) this.errorSummaryTarget.focus()
  }

  updatePrefix() {
    const option = this.divisionTarget.selectedOptions[0]
    this.prefixTarget.textContent = option?.dataset.prefix || "–"
  }

  toggleExpiry() {
    const noExpiry = this.noExpiryTarget.checked
    this.validThruTarget.disabled = noExpiry
    if (noExpiry) this.validThruTarget.value = ""
  }
}
