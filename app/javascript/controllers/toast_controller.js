import { Controller } from "@hotwired/stimulus"

// A flash message shown as a toast : slides in from the `hidden` classes, leaves after `delay` ms
// (0 : stays until closed), the countdown restarting once the pointer leaves it.
export default class extends Controller {
  static values = { delay: Number }
  static classes = ["hidden"]

  connect() {
    // Two frames : the hidden state must be painted for the transition to run
    requestAnimationFrame(() => requestAnimationFrame(() => this.element.classList.remove(...this.hiddenClasses)))
    this.resume()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  pause() {
    clearTimeout(this.timer)
  }

  resume() {
    clearTimeout(this.timer)
    if (this.delayValue > 0) this.timer = setTimeout(() => this.dismiss(), this.delayValue)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    this.element.classList.add(...this.hiddenClasses)
  }
}
