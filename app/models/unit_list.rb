# The keys list : the active units in tree order, narrowed by a ListFilters::Query. Shown by
# UnitsController#index, and walked by a key page's previous / next.
class UnitList
  # The AND-ed filters, each one through its <name>_match?
  FILTERS = %i[status questions issues admin_notes warnings notranslate days].freeze

  attr_reader :query, :units, :indexes, :stats

  def initialize(query, languages:)
    @query = query
    @languages = languages
    @units = Unit.active.reorder(:position, :id).to_a
    # 1-based index of each key in the flattened tree, same as on the translator's page
    @indexes = @units.each.with_index(1).to_h { |unit, i| [unit.id, i] }
    @stats = self.class.stats
  end

  # Per unit id : [translations count, to review count (outdated or contested), not reviewed count, reviewed count]
  def self.stats
    up_to_date = "NOT #{Translation.to_review_sql}"
    Translation.joins(:unit).merge(Unit.active).group(:unit_id)
               .pluck(:unit_id, Arel.sql("COUNT(*)"), Arel.sql("SUM(#{Translation.to_review_sql})"),
                      Arel.sql("SUM(translations.status = #{Translation.statuses[:translated].to_i} AND #{up_to_date})"),
                      Arel.sql("SUM(translations.status = #{Translation.statuses[:approved].to_i} AND #{up_to_date})"))
               .to_h { |id, n, outdated, not_approved, approved| [id, [n, outdated.to_i, not_approved.to_i, approved.to_i]] }
  end

  # Branches whose keys are all out of the translators' work, among every key (not only the listed ones) :
  # { path => :copied (all of them copied) or :directive (@no-translate, some maybe copied) }
  def notranslate_branches
    @notranslate_branches ||= begin
      translated = Set.new
      directive = Set.new
      all = Set.new
      units.each do |unit|
        parts = unit.key.split(".")
        paths = (1...parts.size).map { |n| parts.first(n).join(".") }
        all.merge(paths)
        translated.merge(paths) if unit.translatable
        directive.merge(paths) unless unit.translatable || unit.copied
      end
      (all - translated).to_h { |path| [path, directive.include?(path) ? :directive : :copied] }
    end
  end

  # Units matching the search text and fields (key, branch, user, index range but a single index),
  # whatever the filters
  def searched
    @searched ||= begin
      units = @units
      if (key = query[:key]&.downcase)
        units = units.select { |u| u.key.downcase.include?(key) }
      end
      if (prefix = query[:prefix])
        units = units.select { |u| u.key == prefix || u.key.start_with?("#{prefix}.") }
      end
      if query[:user]
        ids = query.user ? Revision.unscope(:order).by_user(query.user).distinct.pluck(:unit_id).to_set : Set.new
        units = units.select { |u| ids.include?(u.id) }
      end
      if (q = query.text)
        if query.exact?
          units = units.select { |u| u.source_text.include?(q) }
        else
          q = SqliteFold.fold(q)
          units = units.select { |u| SqliteFold.fold(u.source_text).include?(q) }
        end
      end
      query.single_index? ? units : filter_by_index(units)
    end
  end

  # The listed units
  def listed
    @listed ||= (query.single_index? ? filter_by_index(searched) : searched).select { |u| match?(u) }
  end

  # Each status's matches with the other filters (shown in the filters menu), the questions', issues', admin notes',
  # warnings', notranslate's and periods' ones, and the search alone (for the empty list hint). A single index drops the
  # other filters when applied (ListFilters) and they drop it : the counts leave it out.
  def counts
    ListFilters::STATUSES.to_h { |key| [key, searched.count { |u| status?(key, u) && match?(u, except: :status) }] }
                         .merge("questions" => searched.count { |u| question_ids.include?(u.id) && match?(u, except: :questions) },
                                "issues" => searched.count { |u| issue_ids.include?(u.id) && match?(u, except: :issues) },
                                "admin_notes" => searched.count { |u| admin_note_ids.include?(u.id) && match?(u, except: :admin_notes) },
                                "warnings" => searched.count { |u| warning_ids.include?(u.id) && match?(u, except: :warnings) },
                                **notranslate_counts)
                         .merge(ListFilters::PERIODS.to_h { |days| ["days_#{days}", searched.count { |u| revised_ids(days.to_i).include?(u.id) && match?(u, except: :days) }] })
                         .merge(searched: searched.size)
  end

  # Listed units around a unit of the tree (listed or not) : [previous, next]
  def neighbours(unit)
    index = indexes.fetch(unit.id)
    [listed.reverse_each.find { |u| indexes[u.id] < index }, listed.find { |u| indexes[u.id] > index }]
  end

  private

  # Matches every filter, but the one left out
  def match?(unit, except: nil)
    (FILTERS - [except]).all? { |name| send(:"#{name}_match?", unit) }
  end

  def notranslate_match?(unit)
    !query.notranslate? || query.notranslate_match?(unit)
  end

  # Each notranslate value's matches with the other filters : "notranslate" (all), "notranslate_directive", "notranslate_copied"
  def notranslate_counts
    others = searched.select { |u| !u.translatable && match?(u, except: :notranslate) }
    { "notranslate" => others.size, "notranslate_directive" => others.count { |u| !u.copied }, "notranslate_copied" => others.count(&:copied) }
  end

  def days_match?(unit)
    !query.days || revised_ids(query.days).include?(unit.id)
  end

  def questions_match?(unit)
    !query.questions? || question_ids.include?(unit.id)
  end

  def issues_match?(unit)
    !query.issues? || issue_ids.include?(unit.id)
  end

  def admin_notes_match?(unit)
    !query.admin_notes? || admin_note_ids.include?(unit.id)
  end

  def warnings_match?(unit)
    !query.warnings? || warning_ids.include?(unit.id)
  end

  # Statuses apply across every target language : "not_translated" = missing in at least one of them,
  # but "approved" = reviewed and up to date in all of them. A copied unit has none (its translations are left out).
  def status?(key, unit)
    return false if unit.copied

    translated, outdated, not_approved, approved = stats.fetch(unit.id, [0, 0, 0, 0])
    case key
    when "not_translated" then translated < @languages
    when "outdated" then outdated > 0
    when "not_approved" then not_approved > 0
    when "approved" then approved == @languages
    end
  end

  # Checked statuses, OR-ed (none = every unit)
  def status_match?(unit)
    query.statuses.empty? || query.statuses.any? { |key| status?(key, unit) }
  end

  def filter_by_index(units)
    ranges = query.index_ranges
    return units if ranges.empty?

    units.select { |u| (i = indexes[u.id]) && ranges.any? { |from, to| i >= (from || 1) && (to.nil? || i <= to) } }
  end

  def question_ids
    @question_ids ||= Comment.open_questions.distinct.pluck(:unit_id).to_set
  end

  # In any language
  def admin_note_ids
    @admin_note_ids ||= Comment.open_admin_notes.distinct.pluck(:unit_id).to_set
  end

  # An open ticket in any language
  def issue_ids
    @issue_ids ||= Issue.still_open.where.not(unit_id: nil).distinct.pluck(:unit_id).to_set
  end

  # Changed in the last days : any revision (in any language, of the fr source, of the key or its note)
  def revised_ids(days)
    (@revised_ids ||= {})[days] ||= Revision.unscope(:order).where(created_at: days.days.ago..).distinct.pluck(:unit_id).to_set
  end

  # In any target language or in the fr source
  def warning_ids
    @warning_ids ||= TranslationChecks.unit_ids
  end
end
