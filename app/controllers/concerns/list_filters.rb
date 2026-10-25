# Search bar params shared by the translator's list and the keys list :
#   q          text search, in the texts only, trimmed, case and accents aside ; between double quotes ("Word ") the
#              exact text inside them : spaces, case and accents included
#   status[]   translation statuses, combined with OR (none = every status)
#   questions  "1" : with an open question, combined with AND
#   issues     "1" : with an open ticket (Issue) in the language (any language on the keys list), combined with AND
#   admin_notes "1" : with an open admin note (Comment#admin_only), combined with AND ; admins only
#   warnings   "1" : with a TranslationChecks warning, combined with AND
#   notranslate the keys out of the translators' work, instead of the others on the translator's list (admins only),
#              among them on the keys list ; combined with AND. One of NOTRANSLATE : "1" all of them, "directive"
#              the @no-translate ones, "copied" the copied ones (Unit::COPIED_SOURCE)
#   days       one of PERIODS : changed (a revision) in the last n days, combined with AND
#   key        substring of the key
#   prefix     branch : the key itself or anything under it
#   user       user id : keys with a revision by them (Revision.by_user)
#   at         indexes or index ranges in the flattened tree, comma separated and combined with OR (#120, #120-180,
#              #120-, #-180, #145,168,200-210). A single index (#120) is exclusive : it drops every other param above
#   sort       order of the list, where offered (translator's list) : "index" (the default) or "updated"
#              (last revision) ; not a filter, kept by a single index
#   dir        "asc" or "desc", the sort's own direction by default
module ListFilters
  extend ActiveSupport::Concern

  STATUSES = %w[outdated not_translated not_approved approved].freeze
  FIELDS = %w[key prefix user at].freeze
  # Offered periods of the days filter, in days
  PERIODS = %w[1 7 30 90].freeze
  # Values of the notranslate filter : all the keys out of the translators' work, or one kind of them
  NOTRANSLATE = %w[1 directive copied].freeze
  # Most indexes and ranges read from the at param
  MAX_INDEX_RANGES = 50
  # Each sort, with its default direction
  SORTS = { "index" => "asc", "updated" => "desc" }.freeze

  # The params above, read from a request's params or from a remembered list url
  class Query
    NAMES = ["q", "status", "questions", "issues", "admin_notes", "warnings", "notranslate", "days", *FIELDS, "sort", "dir"].freeze

    def self.from_url(url)
      new(Rack::Utils.parse_nested_query(URI(url.to_s).query.to_s))
    end

    def initialize(params)
      @values = NAMES.to_h { |name| [name, params[name]] }
      @values = @values.slice("at", "sort", "dir") if single_index?
    end

    def [](name)
      @values[name.to_s].presence
    end

    # ?at=120 : a single key, alone in the list (not a range nor a list)
    def single_index?
      self[:at].is_a?(String) && !self[:at].match?(/[-,]/)
    end

    # The searched text (q) : trimmed, or the text between its double quotes as is ("word " keeps the space)
    def text
      q = self[:q].to_s.strip
      q = q[1...-1] if exact?
      q.presence
    end

    # Between double quotes : the exact text, case and accents included (else both aside, SqliteFold)
    def exact?
      q = self[:q].to_s.strip
      q.length > 2 && q.start_with?('"') && q.end_with?('"')
    end

    def statuses
      @statuses ||= STATUSES & Array(self[:status])
    end

    def questions?
      self[:questions] == "1"
    end

    def issues?
      self[:issues] == "1"
    end

    def admin_notes?
      self[:admin_notes] == "1"
    end

    def warnings?
      self[:warnings] == "1"
    end

    # The picked notranslate value (NOTRANSLATE), nil when none
    def notranslate
      self[:notranslate] if NOTRANSLATE.include?(self[:notranslate])
    end

    def notranslate?
      notranslate.present?
    end

    # Whether a unit out of the translators' work matches the picked notranslate value
    def notranslate_match?(unit)
      case notranslate
      when "directive" then !unit.translatable && !unit.copied
      when "copied" then unit.copied
      else !unit.translatable
      end
    end

    # The picked period, in days (nil when none)
    def days
      self[:days].to_i if PERIODS.include?(self[:days])
    end

    # The picked sort, nil when none (by index)
    def sort
      self[:sort] if SORTS.key?(self[:sort])
    end

    def sort_dir
      %w[asc desc].include?(self[:dir]) ? self[:dir] : SORTS.fetch(sort || "index")
    end

    # Narrowed by a status, the questions, issues, admin notes, warnings or notranslate flag, a period (the search fields aside)
    def filtered?
      statuses.any? || questions? || issues? || admin_notes? || warnings? || notranslate? || days.present?
    end

    def searched?
      text.present? || FIELDS.any? { |name| self[name].present? }
    end

    def any?
      filtered? || searched?
    end

    # As link params
    def to_params
      { q: self[:q], status: statuses.presence, questions: ("1" if questions?), issues: ("1" if issues?),
        admin_notes: ("1" if admin_notes?), warnings: ("1" if warnings?),
        notranslate: notranslate, days: days&.to_s }
        .merge(FIELDS.to_h { |name| [name.to_sym, self[name]] }, sort: sort, dir: (sort_dir if sort)).compact
    end

    # The ?user= one, nil when unknown
    def user
      return @user if defined?(@user)

      @user = self[:user] && User.find_by(id: self[:user])
    end

    # Index ranges in the flattened tree, as [[from, to], …] (nil = open end), OR-ed : ?at=120 is the key #120 alone,
    # ?at=120-180 a range, ?at=120- from #120 on, ?at=-180 up to #180, ?at=145,168,200-210 any of them.
    # Unreadable parts are left out (none = no index filter)
    def index_ranges
      return [] unless self[:at].is_a?(String)

      self[:at].delete("#").split(",").first(MAX_INDEX_RANGES).filter_map do |part|
        from, to = part.split("-", 2).map { |n| n.strip.presence&.to_i }
        next if from.nil? && to.nil?

        part.include?("-") ? [from, to] : [from, from]
      end
    end
  end

  included do
    helper_method :list_params, :list_text, :list_exact?, :statuses, :questions?, :issues?, :admin_notes?, :warnings?, :notranslate?, :list_notranslate, :list_days, :list_sort, :list_sort_dir
    before_action :exclusive_index
  end

  private

  def list_query
    @list_query ||= Query.new(params)
  end

  delegate :single_index?, :statuses, :questions?, :issues?, :admin_notes?, :warnings?, :notranslate?, :filtered?, :searched?, :index_ranges, to: :list_query, private: true

  def list_text
    list_query.text
  end

  def list_exact?
    list_query.exact?
  end

  def list_days
    list_query.days
  end

  def list_notranslate
    list_query.notranslate
  end

  def list_sort
    list_query.sort
  end

  def list_sort_dir
    list_query.sort_dir
  end

  # The search bar reads the params themselves
  def exclusive_index
    return unless single_index?

    [:q, :status, :questions, :issues, :admin_notes, :warnings, :notranslate, :days, *(FIELDS - ["at"])].each { |name| params.delete(name) }
  end

  # The current list, as link params
  def list_params
    list_query.to_params
  end
end
