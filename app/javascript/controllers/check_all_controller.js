import { Controller } from "@hotwired/stimulus"

// A group's "all" checkbox over its rows' checkboxes : checks or unchecks them all, and shows whether all,
// some (indeterminate) or none are checked. The rows call refresh on change.
export default class extends Controller {
  static targets = ["all", "row", "count"]

  connect() {
    this.refresh()
  }

  toggle() {
    this.rowTargets.forEach((row) => { row.checked = this.allTarget.checked })
    this.refresh()
  }

  refresh() {
    const checked = this.rowTargets.filter((row) => row.checked).length
    this.allTarget.checked = checked > 0 && checked === this.rowTargets.length
    this.allTarget.indeterminate = checked > 0 && checked < this.rowTargets.length
    if (this.hasCountTarget) this.countTarget.textContent = checked
  }
}
