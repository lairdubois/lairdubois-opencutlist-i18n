# The badge / tag rule, formerly written in Pretranslator::SYSTEM, as the glossary's first two terms
class SeedGlossaryBadgeAndTag < ActiveRecord::Migration[8.1]
  class Term < ActiveRecord::Base
    self.table_name = "glossary_terms"
  end

  TERMS = [
    { term: "badge", variants: "badges",
      definition: "OpenCutList keyword of a part, several per part. Not the SketchUp tag: never give them the same word." },
    { term: "balise", variants: "balises",
      definition: "SketchUp tag (formerly \"layer\"), one per entity: the name SketchUp gives it in the language. Not the OpenCutList badge: never give them the same word." }
  ].freeze

  def up
    TERMS.each { |attributes| Term.create!(attributes) unless Term.exists?(term: attributes[:term]) }
  end

  def down
    Term.where(term: TERMS.map { |t| t[:term] }).find_each do |term|
      execute("DELETE FROM glossary_revisions WHERE glossary_term_id = #{term.id.to_i}")
      execute("DELETE FROM glossary_entries WHERE glossary_term_id = #{term.id.to_i}")
      term.delete
    end
  end
end
