import { Controller } from "@hotwired/stimulus"

// Picks the language of a chosen file from its name (de.yml, opencutlist-de.yml), as ImportsController does :
// the last run of letters naming a language. None found : back to the blank option.
export default class extends Controller {
  static targets = ["file", "select"]

  pick() {
    const name = this.fileTarget.files[0]?.name || ""
    const codes = new Set([...this.selectTarget.options].map((option) => option.value).filter(Boolean))
    const parts = name.replace(/\.[^.]*$/, "").toLowerCase().split(/[^a-z]+/).reverse()
    this.selectTarget.value = parts.find((part) => codes.has(part)) || ""
  }
}
