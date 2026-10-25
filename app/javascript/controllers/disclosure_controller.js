import { Controller } from "@hotwired/stimulus"

// Shows / hides a panel from a button living elsewhere (e.g. in a turbo-frame re-rendered on save) :
// a reconnected button picks up the panel's state. Several panels are told apart by name :
// data-disclosure-name on the panel, data-disclosure-panel-param on its buttons (none = the unnamed one).
// A field marked data-disclosure-focus gets the focus when its panel opens.
export default class extends Controller {
  static targets = ["button", "panel"]

  toggle({ params: { panel: name } }) {
    const panel = this.panel(name)
    if (panel) this.show(panel, panel.hidden)
  }

  // Shows the panel, whatever its state (e.g. a "reply" link unfolding the replies and focusing their field)
  open({ params: { panel: name } }) {
    const panel = this.panel(name)
    if (panel) this.show(panel, true)
  }

  show(panel, shown) {
    panel.hidden = !shown
    this.buttonTargets.forEach((b) => this.sync(b))
    if (shown) panel.querySelector("[data-disclosure-focus]")?.focus()
  }

  buttonTargetConnected(button) {
    this.sync(button)
  }

  panel(name) {
    return this.panelTargets.find((p) => (p.dataset.disclosureName || "") === (name || ""))
  }

  sync(button) {
    const panel = this.panel(button.dataset.disclosurePanelParam)
    if (panel) button.setAttribute("aria-expanded", !panel.hidden)
  }
}
