import { Controller } from "@hotwired/stimulus"

// A file input hidden inside its label : the label shows the chosen file's name only (the placeholder when none)
export default class extends Controller {
  static targets = ["input", "name"]

  connect() {
    this.placeholder = this.nameTarget.textContent
    this.show()
  }

  show() {
    const file = this.inputTarget.files[0]
    this.nameTarget.textContent = file ? file.name : this.placeholder
    this.nameTarget.title = file ? file.name : ""
  }
}
