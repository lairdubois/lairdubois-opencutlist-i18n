module PretranslationsHelper
  # A sortable column's header link : the current column reverses, another starts in its default direction
  def pretranslations_sort_link(column, label)
    current = @sort == column
    dir = current ? (@dir == "asc" ? "desc" : "asc") : default_dir(column)
    link_to pretranslations_path(sort: column, dir: dir), class: "inline-flex items-center gap-1 hover:text-stone-900 #{"text-stone-900" if current}" do
      safe_join([ label, (tag.span(@dir == "desc" ? "↓" : "↑", aria: { hidden: true }) if current) ].compact)
    end
  end

  def pretranslations_aria_sort(column)
    return "none" unless @sort == column
    @dir == "desc" ? "descending" : "ascending"
  end
end
