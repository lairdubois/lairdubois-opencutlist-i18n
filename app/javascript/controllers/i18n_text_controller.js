import { Controller } from "@hotwired/stimulus"
import { createI18nView, replaceText, insertText, focusEnd, focusSibling, missingInvariants } from "lib/i18n_text"

// Shows an OCL string in CodeMirror : invariants highlighted, whitespace revealed on demand.
// On a form with a `field` textarea : an editor, the textarea kept hidden and in sync. With a `source`
// value (translator's editor), the source's {{ variables }}, $t() and tags are locked and the missing ones
// offered as chips ; without (fr source editor), nothing is locked. Mod-Enter submits, Shift-Mod-Enter
// through the `review` button, hidden while the text is blank (a blank save removes the translation) ;
// both then move the focus to the page's next editor.
// `autofocus` : focused on load, the cursor at the end.
// Inside a list's data-search-text wrapper (translator's list), the searched text is highlighted
// (data-search-exact : case and accents included).
// On any other element : a read-only view of the `text` value, invariants missing from `source` (if
// given) flagged.
export default class extends Controller {
  static targets = ["field", "chips", "review"]
  static values = { text: String, source: String, refs: Object, autofocus: Boolean }

  connect() {
    // A Turbo cache snapshot keeps the previous view's DOM : start clean
    this.element.querySelectorAll(".cm-editor").forEach((el) => el.remove())
    this.hasFieldTarget ? this.connectEditor() : this.connectReadOnly()
  }

  disconnect() {
    this.view?.destroy()
    if (this.hasFieldTarget) {
      this.fieldTarget.hidden = false
      this.fieldTarget.removeEventListener("input", this.pull)
    } else {
      this.element.textContent = this.textValue
    }
  }

  get search() {
    return this.element.closest("[data-search-text]")?.dataset.searchText || ""
  }

  get searchExact() {
    return this.element.closest("[data-search-text]")?.dataset.searchExact === "true"
  }

  connectReadOnly() {
    this.element.textContent = ""
    this.view = createI18nView({
      parent: this.element,
      text: this.textValue,
      source: this.hasSourceValue ? this.sourceValue : null,
      refs: this.refsValue,
      dir: this.element.dir || "ltr",
      search: this.search,
      searchExact: this.searchExact,
    })
  }

  connectEditor() {
    const field = this.fieldTarget
    this.view = createI18nView({
      parent: this.element,
      text: field.value,
      source: this.hasSourceValue ? this.sourceValue : null,
      refs: this.refsValue,
      editable: true,
      search: this.search,
      searchExact: this.searchExact,
      lang: field.lang,
      dir: field.dir,
      // Takes the textarea's place (and classes) in the row's grid
      className: field.className,
      // Announced for dirty-form : setting the value doesn't fire `input`
      onChange: (text) => { field.value = text; this.renderChips(); this.toggleReview(); this.dispatch("change") },
      onSubmit: ({ review } = {}) => this.submit(review),
    })
    field.after(this.view.dom)
    field.hidden = true
    // Suggestion buttons fill the textarea and fire `input`
    this.pull = () => replaceText(this.view, field.value)
    field.addEventListener("input", this.pull)
    this.renderChips()
    this.toggleReview()
    if (this.autofocusValue) focusEnd(this.view)
  }

  // Without a review button (not a reviewer, or a blank text), Shift-Mod-Enter is a plain save.
  // The focus moves on once the submission is under way : not when dirty-form refuses a clean form (its
  // listener, added at its connect, runs before this one). The saved row's re-rendered editor doesn't take it back.
  submit(review) {
    const moveOn = (event) => { if (!event.defaultPrevented) focusSibling(this.view, 1) }
    this.element.addEventListener("submit", moveOn, { once: true })
    this.element.requestSubmit(review && this.hasReviewTarget && !this.reviewTarget.hidden ? this.reviewTarget : undefined)
    this.element.removeEventListener("submit", moveOn)
  }

  toggleReview() {
    if (this.hasReviewTarget) this.reviewTarget.hidden = this.fieldTarget.value.trim() === ""
  }

  renderChips() {
    if (!this.hasChipsTarget || !this.hasSourceValue) return
    const missing = missingInvariants(this.sourceValue, this.view.state.doc.toString())
    this.chipsTarget.replaceChildren(...missing.map((token) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "tok-chip"
      button.textContent = token
      button.addEventListener("click", () => insertText(this.view, token))
      return button
    }))
    this.chipsTarget.hidden = missing.length === 0
  }
}
