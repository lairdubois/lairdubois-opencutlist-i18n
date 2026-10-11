import { Controller } from "@hotwired/stimulus"

// A display preference remembered per browser : a class on <html> (show-ws : whitespace marks in the
// i18n-text views ; hide-keys : the translator's rows show their key on hover only). The button is pressed
// while the preference is on ; `inverse` : the class marks it off, so it is on by default and nothing flashes.
export default class extends Controller {
  static values = { class: String, key: String, inverse: Boolean }

  connect() {
    let stored = null
    try { stored = localStorage.getItem(this.keyValue) } catch {}
    this.apply(stored === null ? this.inverseValue : stored === "1")
  }

  toggle() {
    const on = document.documentElement.classList.contains(this.classValue) !== this.inverseValue
    try { localStorage.setItem(this.keyValue, on ? "0" : "1") } catch {}
    this.apply(!on)
  }

  apply(on) {
    document.documentElement.classList.toggle(this.classValue, on !== this.inverseValue)
    this.element.setAttribute("aria-pressed", on)
  }
}
