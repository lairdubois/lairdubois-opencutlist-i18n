# Renders every language as <code>.yml, in the repo's key order
class YamlExport
  # { "fr.yml" => "...", ... }
  def files
    units = Unit.active.to_a
    branch_notes = BranchNote.to_map
    Language.all.to_h do |language|
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
      ["#{language.code}.yml", I18nYaml::Writer.write(entries, branch_notes: branch_notes)]
    end
  end

  def write(dir)
    files.map { |name, content| File.join(dir, name).tap { |path| File.write(path, content) } }
  end
end
