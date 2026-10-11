import { Controller } from "@hotwired/stimulus"

// Copies the `text` value to the clipboard ; the `done` icon replaces the `icon` one for a moment,
// and a toast shows the `message` value (one toast for the page, created on demand).
export default class extends Controller {
  static targets = ["icon", "done"]
  static values = { text: String, message: String }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      return
    }
    this.iconTarget.hidden = true
    this.doneTarget.hidden = false
    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      this.iconTarget.hidden = false
      this.doneTarget.hidden = true
    }, 1500)
    if (this.hasMessageValue) toast(this.messageValue)
  }
}

let toastTimer

function toast(message) {
  let el = document.getElementById("clipboard-toast")
  if (!el) {
    el = document.createElement("div")
    el.id = "clipboard-toast"
    el.setAttribute("role", "status")
    el.className = "pointer-events-none fixed bottom-4 left-1/2 z-50 -translate-x-1/2 rounded bg-stone-800 px-3 py-1.5 text-sm text-white shadow-lg opacity-0 transition-opacity duration-200"
    document.body.append(el)
  }
  el.textContent = message
  // Next frame : the opacity transition needs the element rendered first
  requestAnimationFrame(() => el.classList.replace("opacity-0", "opacity-100"))
  clearTimeout(toastTimer)
  toastTimer = setTimeout(() => el.classList.replace("opacity-100", "opacity-0"), 1500)
}
