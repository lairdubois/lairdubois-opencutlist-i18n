module SearchHelper
  # The text, the matches of the list's search (ListFilters::Query#text) in <mark class="search-hit"> : exact, or case
  # and accents aside as SqliteFold
  def highlight_search(text, search = list_text, exact: list_exact?)
    return text if text.blank? || search.blank?

    # The folded text, and the index in text of each folded character's source
    folded = +""
    origins = []
    text.each_char.with_index do |char, i|
      f = exact ? char : SqliteFold.fold(char)
      folded << f
      origins.concat([i] * f.length)
    end
    pattern = exact ? search : SqliteFold.fold(search)
    parts = []
    last = 0
    start = 0
    while (at = folded.index(pattern, start))
      from = origins[at]
      to = origins[at + pattern.length - 1] + 1
      parts << text[last...from] << tag.mark(text[from...to], class: "search-hit")
      last = to
      start = at + pattern.length
    end
    parts.empty? ? text : safe_join([*parts, text[last..]])
  end
end
