# The term a language expects for a glossary term, set by its reviewers : its other forms (plural…), the translations
# to avoid and a note (gender, acceptable synonyms…). All blank : no entry (GlossaryOperations#save_entry removes it).
class GlossaryEntry < ApplicationRecord
  belongs_to :glossary_term
  belongs_to :language

  normalizes :term, with: ->(term) { term.squish.presence }
  normalizes :variants, :avoid, with: ->(list) { GlossaryTerm.join_list(list) }
  normalizes :note, with: ->(note) { note.strip.gsub("\r\n", "\n").presence }

  validates :language_id, uniqueness: { scope: :glossary_term_id }
  validates :term, length: { maximum: 100 }
  validates :note, length: { maximum: 2000 }
  validates :term, presence: true, if: -> { variants.present? }

  # Fields recorded in the revisions, in the form's order
  FIELDS = %w[term variants avoid note].freeze

  # The forms looked for in the translations : the term and its variants (none while the term is unknown)
  def forms
    term ? [term, *GlossaryTerm.split_list(variants)].uniq : []
  end

  def avoided
    GlossaryTerm.split_list(avoid)
  end

  def empty?
    FIELDS.all? { |field| self[field].blank? }
  end
end
