module GlossaryHelper
  # The glossary terms of a fr text, as i18n-text's glossary value : [{ forms, title }], found again in the view by
  # lib/i18n_text.js. The tooltip tells the term expected in the language (none : the fr source's editor), then the
  # definition and the language's note. via : a text in that language (the en reference), its terms found through
  # their forms there, the fr term told first ; terms sharing their forms there share one tooltip
  def glossary_json(glossary, source, language = nil, via: nil)
    glossary.terms_in(source, via: via).group_by { |term| glossary.forms_for(term, via) }.map do |forms, terms|
      titles = terms.map do |term|
        entry = glossary.entry(term, language) if language
        lines = [(t("glossary.tooltip.source", term: term.term) if via && !term.no_translate), glossary_tooltip(term, entry, language)]
        lines << t("glossary.tooltip.avoid", avoid: entry.avoid) if entry&.avoid
        (lines + [term.definition, entry&.note]).compact.join("\n")
      end
      { forms: forms, title: titles.join("\n\n") }
    end.to_json
  end

  # Where a dragged column would go (column_order_controller's data-drop) : a line on that side of the chip or header
  DROP_MARK = "data-[drop=before]:shadow-[inset_2px_0_0_var(--color-stone-800)] data-[drop=after]:shadow-[inset_-2px_0_0_var(--color-stone-800)]".freeze

  # A column chip or header dragged to reorder the columns (column_order_controller), within its group
  def column_drag_attributes(language, group)
    tag.attributes(draggable: "true", title: t("glossary.search_bar.column_drag", name: language.name),
                   data: { column_order_target: "item", column_order_code: language.code, column_order_group: group,
                           action: "dragstart->column-order#start dragover->column-order#over dragleave->column-order#leave " \
                                   "drop->column-order#drop dragend->column-order#end" })
  end

  # The table's marks : terms to avoid (a barred circle, red) and a note (a speech bubble)
  def glossary_avoid_icon
    tag.svg(safe_join([tag.circle(cx: 12, cy: 12, r: 9), tag.path(d: "M5.6 5.6l12.8 12.8")]), viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": 2.5, "stroke-linecap": "round", class: "h-3 w-3 shrink-0 text-red-700",
            role: "img", aria: { label: t("glossary.table.avoid") })
  end

  def glossary_note_icon
    tag.svg(tag.path(d: "M4 5h16v11H9l-5 4z", "stroke-linejoin": "round"), viewBox: "0 0 24 24", fill: "none",
            stroke: "currentColor", "stroke-width": 2.5, class: "h-3 w-3 shrink-0 text-stone-500",
            role: "img", aria: { label: t("glossary.table.note") })
  end

  private

  def glossary_tooltip(term, entry, language)
    if term.no_translate then t("glossary.tooltip.keep", term: term.term)
    elsif language.nil? then t("glossary.tooltip.term", term: term.term)
    elsif entry&.term then t("glossary.tooltip.expected", language: language.code.upcase, term: entry.forms.join(", "))
    else t("glossary.tooltip.missing", language: language.code.upcase)
    end
  end
end
