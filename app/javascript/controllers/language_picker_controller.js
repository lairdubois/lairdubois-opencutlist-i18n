import { Controller } from "@hotwired/stimulus"

// The volunteers' language dropdown : a popover of options (with their progress) filtered by a search
// field, the picked code in a hidden field. Placed by popover_controller, as wide as its button.
export default class extends Controller {
  static targets = ["field", "label", "panel", "search", "group", "empty"]

  // ↓ / ↑ on the closed button opens it
  open(event) {
    event.preventDefault()
    this.panelTarget.showPopover()
  }

  size(event) {
    if (event.newState !== "open") return

    this.panelTarget.style.width = `${this.anchor.getBoundingClientRect().width}px`
  }

  // Opened : a fresh search, the picked option in view
  opened(event) {
    if (event.newState !== "open") return

    this.searchTarget.value = ""
    this.filter()
    this.searchTarget.focus()
    this.options.find((o) => o.getAttribute("aria-selected") === "true")?.scrollIntoView({ block: "nearest" })
  }

  // On the name or the code, case and accents aside
  filter() {
    const q = fold(this.searchTarget.value.trim())
    this.options.forEach((o) => { o.hidden = q !== "" && !fold(`${o.dataset.name} ${o.dataset.code}`).includes(q) })
    this.groupTargets.forEach((g) => { g.hidden = !g.querySelector("[role=option]:not([hidden])") })
    this.emptyTarget.hidden = this.visibleOptions.length > 0
  }

  pick(event) {
    const option = event.currentTarget
    this.fieldTarget.value = option.dataset.code
    this.labelTarget.textContent = `${option.dataset.name} (${option.dataset.code.toUpperCase()})`
    this.labelTarget.classList.remove("text-stone-400")
    this.options.forEach((o) => {
      const on = o === option
      o.setAttribute("aria-selected", on)
      o.querySelector("span").textContent = on ? "✓" : ""
    })
    this.panelTarget.hidePopover()
    this.anchor.focus()
  }

  // ↓ / ↑ from the search field through the shown options (back to the field above the first), Enter in the
  // field picks the only one left
  keydown(event) {
    const items = this.visibleOptions
    const index = items.indexOf(document.activeElement)
    if (event.key === "Enter" && event.target === this.searchTarget) {
      event.preventDefault()
      if (items.length === 1) items[0].click()
      return
    }
    const next = { ArrowDown: index + 1, ArrowUp: index - 1 }[event.key]
    if (next === undefined || !items.length) return

    event.preventDefault()
    if (next < 0) this.searchTarget.focus()
    else items[Math.min(next, items.length - 1)].focus()
  }

  // A hidden field can't be required : no language, no submission
  require(event) {
    if (this.fieldTarget.value !== "") return

    event.preventDefault()
    this.panelTarget.showPopover()
  }

  get anchor() {
    return this.element.querySelector(`[popovertarget="${this.panelTarget.id}"]`)
  }

  get options() {
    return [...this.panelTarget.querySelectorAll("[role=option]")]
  }

  get visibleOptions() {
    return this.options.filter((o) => !o.hidden && !o.closest("[hidden]"))
  }
}

function fold(text) {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase()
}
