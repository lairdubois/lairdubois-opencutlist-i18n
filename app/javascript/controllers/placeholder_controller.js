import { Controller } from "@hotwired/stimulus"

// Sets a field's placeholder from the checked radio's data-placeholder (e.g. the kind of a comment)
export default class extends Controller {
  static targets = ["field"]

  set({ target }) {
    if (target.checked && target.dataset.placeholder) this.fieldTarget.placeholder = target.dataset.placeholder
  }
}
