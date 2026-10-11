import { Controller } from "@hotwired/stimulus"

// A section folded from its header button. The state is kept in a cookie (section_<name>) for the
// server to render the section as it was left (ApplicationHelper#section_open?) : no flash on load.
export default class extends Controller {
  static targets = ["button", "panel"]
  static values = { name: String }

  toggle() {
    const open = this.panelTarget.hidden
    this.panelTarget.hidden = !open
    this.buttonTarget.setAttribute("aria-expanded", open)
    document.cookie = `section_${this.nameValue}=${open ? "open" : "closed"}; path=/; max-age=31536000; SameSite=Lax`
  }
}
