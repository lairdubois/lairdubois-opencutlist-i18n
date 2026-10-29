import { Controller } from "@hotwired/stimulus"

// The glossary's columns reordered by dragging one of them (GlossaryHelper#column_drag_attributes) : a "Columns" chip
// of the search bar or a table header, within its group. Dropped, the group's order replaces the search bar's cols[]
// (a header dragged while none is checked checks them all) and the form is submitted : the table comes back in that
// order, saved as the user's (GlossaryController#set_columns). data-drop marks the side it would go
export default class extends Controller {
  static targets = ["form", "item"]

  start(event) {
    this.dragged = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", this.dragged.dataset.columnOrderCode)
  }

  over(event) {
    const item = event.currentTarget
    if (!this.dragged || item.dataset.columnOrderGroup !== this.dragged.dataset.columnOrderGroup) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    const rect = item.getBoundingClientRect()
    this.mark(item, item === this.dragged ? null : event.clientX < rect.left + rect.width / 2 ? "before" : "after")
  }

  leave(event) {
    if (!event.currentTarget.contains(event.relatedTarget)) delete event.currentTarget.dataset.drop
  }

  drop(event) {
    const item = event.currentTarget
    const side = item.dataset.drop
    if (!this.dragged || !side) return

    event.preventDefault()
    const order = this.group(item).map((i) => i.dataset.columnOrderCode)
    const code = this.dragged.dataset.columnOrderCode
    const codes = order.filter((c) => c !== code)
    codes.splice(codes.indexOf(item.dataset.columnOrderCode) + (side === "after" ? 1 : 0), 0, code)
    this.end()
    if (codes.join() !== order.join()) this.apply(codes)
  }

  end() {
    this.mark(null)
    this.dragged = null
  }

  apply(codes) {
    const form = this.formTarget
    form.querySelectorAll("input[name='cols[]']").forEach((input) => input.remove())
    for (const value of codes) form.append(Object.assign(document.createElement("input"), { type: "hidden", name: "cols[]", value }))
    form.requestSubmit()
  }

  group(item) {
    return this.itemTargets.filter((i) => i.dataset.columnOrderGroup === item.dataset.columnOrderGroup)
  }

  mark(item, side) {
    this.itemTargets.forEach((i) => i !== item && delete i.dataset.drop)
    if (!item) return

    if (side) {
      item.dataset.drop = side
    } else {
      delete item.dataset.drop
    }
  }
}
