import { Controller } from "@hotwired/stimulus"

// Przełącznik trybu jasny/ciemny w nagłówku. Tryb to atrybut data-bs-theme na <html>
// (ustawiany już w <head>, przed narysowaniem strony). Wybór zapamiętujemy w przeglądarce.
export default class extends Controller {
  connect() {
    this.sync()
  }

  toggle() {
    const theme = this.current === "dark" ? "light" : "dark"
    document.documentElement.setAttribute("data-bs-theme", theme)
    try { localStorage.setItem("theme", theme) } catch (e) {}
    this.sync()
  }

  get current() {
    return document.documentElement.getAttribute("data-bs-theme")
  }

  // Przycisk przełączający: aria-pressed="true" = tryb ciemny włączony.
  sync() {
    this.element.setAttribute("aria-pressed", this.current === "dark" ? "true" : "false")
  }
}
