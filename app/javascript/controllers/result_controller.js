import { Controller } from "@hotwired/stimulus"

// Po pojawieniu się wyniku przenosi fokus na jego nagłówek – czytnik ekranu odczyta wynik,
// a na telefonie strona przewinie się do niego.
export default class extends Controller {
  static targets = ["heading"]

  connect() {
    if (document.activeElement && this.element.contains(document.activeElement)) return
    this.headingTarget.focus()
  }
}
