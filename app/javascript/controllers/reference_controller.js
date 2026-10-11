import { Controller } from "@hotwired/stimulus"

// The translator's main reference (fr source or en translation) : the rows hold both, the ref-en class on this
// element shows the en one. Switched in place, so the scroll, the loaded pages and the unsaved edits stay ;
// the choice is saved on the user in the background.
export default class extends Controller {
  static targets = ["button"]
  static values = { url: String }

  choose({ params: { code } }) {
    this.element.classList.toggle("ref-en", code === "en")
    this.buttonTargets.forEach((button) => button.setAttribute("aria-pressed", button.dataset.referenceCodeParam === code))
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: new URLSearchParams({ reference_language: code })
    })
  }
}
