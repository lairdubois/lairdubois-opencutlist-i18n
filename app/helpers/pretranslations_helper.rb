module PretranslationsHelper
  def pretranslations_sort_link(column, label)
    sort_header_link(label, column, sort: @sort, dir: @dir, default_dir: default_dir(column),
                     url: ->(sort, dir) { pretranslations_path(sort: sort, dir: dir) })
  end

  def pretranslations_aria_sort(column)
    aria_sort(column, sort: @sort, dir: @dir)
  end
end
