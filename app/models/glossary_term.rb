# A fr term of the glossary, its other forms (plural…) and its definition (in English : read by every language's
# translators), created by the admins ; its entries give the term expected in each language (GlossaryEntry).
# no_translate : kept as is everywhere (product names). Archived instead of deleted : its history stays ; an archived
# one may then be deleted for good by an admin (GlossaryOperations#delete_term).
class GlossaryTerm < ApplicationRecord
  has_many :entries, class_name: "GlossaryEntry", dependent: :destroy
  has_many :revisions, class_name: "GlossaryRevision", dependent: :destroy

  normalizes :term, with: ->(term) { term.squish }
  normalizes :variants, with: ->(variants) { GlossaryTerm.join_list(variants) }
  normalizes :definition, with: ->(definition) { definition.strip.gsub("\r\n", "\n").presence }

  validates :term, presence: true, length: { maximum: 100 }
  validates :definition, length: { maximum: 2000 }
  validate :term_not_taken, unless: :archived?

  scope :active, -> { where(archived_at: nil) }

  # Fields recorded in the revisions, in the form's order
  FIELDS = %w[term variants definition no_translate].freeze

  # A list typed as "chants, Chants" or one per line → ["chants", "Chants"]
  def self.split_list(text)
    text.to_s.split(/[,\n]/).map(&:squish).compact_blank.uniq
  end

  def self.join_list(text)
    split_list(text).join(", ").presence
  end

  # { folded form => term } over the active terms : a term found by any of its forms, case and accents aside
  def self.form_index
    active.each_with_object({}) { |term, index| term.forms.each { |form| index[SqliteFold.fold(form)] ||= term } }
  end

  # The forms looked for in the fr texts : the term and its variants
  def forms
    [term, *self.class.split_list(variants)].uniq
  end

  def archived?
    archived_at.present?
  end

  private

  # A form (term or variant) belongs to one active term only, case and accents aside
  def term_not_taken
    return if term.blank?

    owners = {}
    GlossaryTerm.active.where.not(id: id).find_each do |other|
      other.forms.each { |form| owners[SqliteFold.fold(form)] ||= other.term }
    end
    forms.each do |form|
      owner = owners[SqliteFold.fold(form)] or next
      errors.add(:base, :form_taken, form: form, owner: owner)
    end
  end
end
