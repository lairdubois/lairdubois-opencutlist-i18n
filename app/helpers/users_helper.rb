module UsersHelper
  # A users table header : sorts as the search bar's sort menu does, the search and filters kept
  def users_sort_link(list, column, label)
    sort_header_link(label, column, sort: list.sort_column, dir: list.sort_dir, default_dir: UserList::SORTS.fetch(column),
                     url: ->(sort, dir) { users_path(request.query_parameters.slice("q", "role", "language", "days", "seen").merge(sort: sort, dir: dir)) })
  end

  def users_aria_sort(list, column)
    aria_sort(column, sort: list.sort_column, dir: list.sort_dir)
  end
end
