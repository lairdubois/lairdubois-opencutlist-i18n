# Renders every language as <code>.yml, in the repo's key order
class YamlExport
  # { "fr.yml" => "...", ... }
  def files
    Language.all.to_h { |language| ["#{language.code}.yml", file(language)] }
  end

  # One language's yml : every key for fr ; elsewhere the translated ones (outdated and not approved included),
  # the copied ones as their source. Missing keys fall back to en in OCL
  def file(language)
    entries = if language.source?
                units.map { |u| I18nYaml::Entry.new(key: u.key, value: u.source_text, note: u.note) }
    else
                texts = language.translations.where(unit: units).pluck(:unit_id, :text).to_h
                # A copied source (a $t() or a {{ var }} alone) is the same in every language, whatever was translated
                units.filter_map do |u|
                  value = u.copied ? u.source_text : texts[u.id]
                  I18nYaml::Entry.new(key: u.key, value: value, note: u.note) if value
                end
    end
    I18nYaml::Writer.write(entries, branch_notes: branch_notes)
  end

  private

  def units
    @units ||= Unit.active.to_a
  end

  def branch_notes
    @branch_notes ||= BranchNote.to_map
  end
end
