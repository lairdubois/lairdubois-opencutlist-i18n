import { Controller } from "@hotwired/stimulus"

// Shows / hides a panel from a button living elsewhere (e.g. in a turbo-frame re-rendered on save) :
// a reconnected button picks up the panel's state. Several panels are told apart by name :
// data-disclosure-name on the panel, data-disclosure-panel-param on its buttons (none = the unnamed one).
export default class extends Controller {
  static targets = ["button", "panel"]

  toggle({ params: { panel: name } }) {
    const panel = this.panel(name)
    if (!panel) return

    panel.hidden = !panel.hidden
    this.buttonTargets.forEach((b) => this.sync(b))
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
