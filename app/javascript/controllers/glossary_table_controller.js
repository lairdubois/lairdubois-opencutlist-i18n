import { Controller } from "@hotwired/stimulus"

// The glossary's table : marks the cell shown in the side panel (aria-current), empties the panel on close, and
// puts a new term's row (appended to the grid by a stream) in its alphabetical place (data-sort : the folded term).
// Fits the table's box to the window : the page then scrolls only when the side panel is taller. The arrow keys move
// the cell shown, Enter opens its form, Esc in the panel goes back to the table
export default class extends Controller {
  static targets = ["panel", "placeholder", "row", "region", "current"]

  connect() {
    this.fit = this.fit.bind(this)
    this.observer = new ResizeObserver(this.fit)
    this.observer.observe(document.body)
    window.addEventListener("resize", this.fit)
    this.fit()
  }

  disconnect() {
    this.observer.disconnect()
    window.removeEventListener("resize", this.fit)
  }

  // Everything above the box (header, banner, toolbar, the narrow window's buttons) and below it (legend, main's
  // padding) measured from the page's top, wherever it is scrolled
  fit() {
    if (!this.hasRegionTarget) return

    const region = this.regionTarget
    const rect = region.getBoundingClientRect()
    const column = region.parentElement.getBoundingClientRect()
    const main = this.element.closest("main")
    const below = column.bottom - rect.bottom + (main ? parseFloat(getComputedStyle(main).paddingBottom) : 0)
    const max = `calc(100dvh - ${Math.ceil(rect.top + window.scrollY + below)}px)`
    if (region.style.maxHeight !== max) region.style.maxHeight = max
  }

  select(event) {
    this.mark(event.currentTarget)
  }

  clear() {
    this.mark(null)
  }

  close() {
    this.mark(null)
    this.panelTarget.removeAttribute("src")
    this.panelTarget.replaceChildren(this.placeholderTarget.content.cloneNode(true))
  }

  // A row rendered by a stream (a new term's) : appended last, it moves before the first row sorting after it
  rowTargetConnected(row) {
    if (row.nextElementSibling) return

    const next = this.rowTargets.find((r) => r !== row && r.dataset.sort > row.dataset.sort)
    if (next) next.before(row)
  }

  // A cell rendered shown by a stream (a new term's, the next column to fill) : marked, then scrolled into the box,
  // once its row is in place (the next frame)
  currentTargetConnected(cell) {
    this.mark(cell)
    requestAnimationFrame(() => {
      if (cell.isConnected) this.reveal(cell)
    })
  }

  // An arrow key opens the next cell that way (focused, its panel loaded like a click) : from a cell (the focused one)
  // or the box (the first cell when none is shown), or from the cell shown with nothing focused (Safari doesn't
  // focus a clicked link). Up and down keep the column (data-glossary-cell : its code), skipping the rows without it
  // (kept as is) ; nothing past the edges
  move(event) {
    const step = { ArrowUp: -1, ArrowDown: 1, ArrowLeft: -1, ArrowRight: 1 }[event.key]
    const { from, inside } = (step && this.keyOrigin(event)) || {}
    if (!from && !inside) return

    event.preventDefault()
    let to
    if (!from) {
      to = this.regionTarget.querySelector("[data-glossary-cell]")
    } else if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
      const cells = [...from.parentElement.querySelectorAll(":scope > [data-glossary-cell]")]
      to = cells[cells.indexOf(from) + step]
    } else {
      const rows = this.rowTargets
      const code = CSS.escape(from.dataset.glossaryCell)
      for (let i = rows.indexOf(from.parentElement) + step; !to && i >= 0 && i < rows.length; i += step) {
        to = rows[i].querySelector(`:scope > [data-glossary-cell="${code}"]`)
      }
    }
    if (!to) return

    to.focus({ preventScroll: true })
    this.reveal(to)
    to.click()
  }

  // Enter on a cell (the focused one, or the one shown with nothing focused) opens its form in the panel, through the
  // panel's edit link (none : not the user's to edit), once the panel shows that cell ; then focuses its first field
  async edit(event) {
    const { from } = this.keyOrigin(event) || {}
    if (!from) return

    event.preventDefault()
    const panel = this.panelTarget
    if (panel.src !== from.href) {
      const loaded = this.frameLoad()
      from.click()
      await loaded
    } else if (panel.hasAttribute("busy")) {
      await this.frameLoad()
    }

    const link = panel.querySelector("[data-glossary-edit]")
    if (link) {
      const loaded = this.frameLoad()
      link.click()
      await loaded
    }
    panel.querySelector("form :is(input:not([type=hidden]), textarea)")?.focus()
  }

  // Esc in the panel : back to the cell shown (focused), its form left as the cancel link does (the cell's own view
  // reloaded ; a new term's form closed) ; the box focused when none is shown
  back(event) {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    if (!this.hasRegionTarget || !this.panelTarget.contains(event.target)) return

    event.preventDefault()
    const cell = this.regionTarget.querySelector("[data-glossary-cell][aria-current]")
    const editing = this.panelTarget.querySelector("form :is(input[type=text], textarea)")
    if (editing && cell) {
      if (this.panelTarget.src === cell.href) this.panelTarget.reload()
      else this.panelTarget.src = cell.href
    } else if (editing) {
      this.close()
    }

    if (cell) {
      cell.focus({ preventScroll: true })
      this.reveal(cell)
    } else {
      this.regionTarget.focus({ preventScroll: true })
    }
  }

  // The cell a key acts from : the focused one in the box, else the one shown when the focus is in the box or nowhere.
  // Nothing with a modifier, nor from elsewhere (the panel's fields, the search bar)
  keyOrigin(event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || !this.hasRegionTarget) return null

    const inside = this.regionTarget.contains(event.target)
    if (!inside && event.target !== document.body) return null

    const from = (inside && event.target.closest("[data-glossary-cell]")) ||
                 this.regionTarget.querySelector("[data-glossary-cell][aria-current]")
    return { from, inside }
  }

  frameLoad() {
    return new Promise((resolve) => this.panelTarget.addEventListener("turbo:frame-load", resolve, { once: true }))
  }

  // Scrolls a cell into the box, clear of the sticky header row and fr column (the grid's first cell : their corner)
  reveal(cell) {
    const corner = this.regionTarget.querySelector("#glossary_grid > :first-child")
    const stuck = cell === cell.parentElement.querySelector(":scope > [data-glossary-cell]")
    this.regionTarget.style.scrollPaddingTop = `${corner?.offsetHeight ?? 0}px`
    this.regionTarget.style.scrollPaddingLeft = `${stuck ? 0 : corner?.offsetWidth ?? 0}px`
    cell.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  mark(cell) {
    this.element.querySelectorAll("[data-glossary-cell][aria-current]").forEach((c) => c.removeAttribute("aria-current"))
    cell?.setAttribute("aria-current", "true")
  }
}
