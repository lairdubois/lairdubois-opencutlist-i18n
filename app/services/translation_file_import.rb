require "digest"

# A language's yml (keyed as the repo's fr.yml) compared with the tool's translations : the texts it brings, for the
# admin to pick before anything is written. Keys missing from fr, blank texts, copied keys and texts equal to the fr
# source are only counted ; texts on @no-translate keys are listed, never written.
class TranslationFileImport
  MAX_BYTES = 2.megabytes

  # translation : the tool's, nil when the key isn't translated yet
  Row = Data.define(:unit, :text, :translation) do
    # The translation as shown in the preview : a pick whose stamp no longer matches is stale
    def stamp
      Digest::MD5.hexdigest([translation&.text, translation&.status, translation&.source_hash].join("\0"))[0, 12]
    end
  end

  # added : not translated here, changed : another text here, same : identical (counted),
  # no_translate : on a key out of the translators' work (shown only), skipped : { reason => count } (blank, copied,
  # source), unmatched : keys of the file with no fr key
  Plan = Data.define(:added, :changed, :same, :no_translate, :skipped, :unmatched)

  # Raises Psych::SyntaxError, or ArgumentError when the yml isn't a tree of texts
  def initialize(yaml_text, language)
    @entries = I18nYaml::Reader.new(yaml_text).entries
    @language = language
  end

  def plan
    @plan ||= begin
      units = Baseline.units_by_repo_key
      ours = @language.translations.index_by(&:unit_id)
      plan = Plan.new(added: [], changed: [], same: [], no_translate: [], skipped: Hash.new(0), unmatched: [])
      seen = Set.new
      @entries.each do |entry|
        unit = units[entry.key]
        next plan.unmatched << entry.key unless unit
        # A repo key and the tool's new name for the same unit : the first one wins
        next unless seen.add?(unit.id)

        text = entry.value.to_s.gsub("\r\n", "\n")
        reason = skip_reason(unit, text)
        next plan.skipped[reason] += 1 if reason

        row = Row.new(unit:, text:, translation: ours[unit.id])
        if !unit.translatable? then plan.no_translate << row
        elsif row.translation.nil? then plan.added << row
        elsif row.translation.text == text then plan.same << row
        else plan.changed << row
        end
      end
      plan
    end
  end

  # picks : { unit id => stamp } of the checked rows, written as the user's. Returns [written, stale] : a stale pick
  # (its translation changed since the preview) is left out
  def apply(picks, user)
    rows = (plan.added + plan.changed).index_by { |row| row.unit.id }
    operations = TranslationOperations.new(user)
    written = stale = 0
    ApplicationRecord.transaction do
      picks.each do |unit_id, stamp|
        row = rows[unit_id.to_i]
        next stale += 1 unless row&.stamp == stamp

        operations.import(row.unit, @language, row.text)
        written += 1
      end
    end
    [written, stale]
  end

  private

  def skip_reason(unit, text)
    if text.strip.empty? then :blank
    elsif unit.copied? then :copied
    elsif text == unit.source_text && unit.translatable? then :source
    end
  end
end
