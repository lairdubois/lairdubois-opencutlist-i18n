# What admins (the fr terms) and reviewers (their language's entries) do to the glossary, each change recorded as a
# GlossaryRevision. Each method returns the record, with its errors when invalid.
class GlossaryOperations
  # origin : the author's name when it isn't a user (the API's robot)
  def initialize(user, origin: nil)
    @user = user
    @origin = origin
  end

  # A new fr term, its languages filled afterwards (save_entry)
  def create_term(attributes)
    term = GlossaryTerm.new(attributes)
    return term unless term.valid?

    GlossaryTerm.transaction do
      changes = term.changes.slice(*GlossaryTerm::FIELDS)
      term.save!
      record(term, nil, "create", changes)
    end
    term
  end

  def update_term(term, attributes)
    term.assign_attributes(attributes)
    changes = term.changes.slice(*GlossaryTerm::FIELDS)
    return term if changes.empty? || !term.valid?

    GlossaryTerm.transaction do
      term.save!
      record(term, nil, "update", changes)
    end
    term
  end

  def archive_term(term)
    GlossaryTerm.transaction do
      term.update!(archived_at: Time.current)
      record(term, nil, "archive", {})
    end
    term
  end

  # Refused when an active term took its spelling meanwhile
  def restore_term(term)
    term.archived_at = nil
    return term unless term.valid?

    GlossaryTerm.transaction do
      term.save!
      record(term, nil, "restore", {})
    end
    term
  end

  # An archived term deleted for good (admins) : its entries and revisions with it, no trace left
  def delete_term(term)
    raise ArgumentError, "not archived" unless term.archived?

    term.destroy!
  end

  # Every field blank removes the entry
  def save_entry(term, language, attributes)
    entry = term.entries.find_or_initialize_by(language: language)
    entry.assign_attributes(attributes)
    changes = entry.changes.slice(*GlossaryEntry::FIELDS)
    return entry if changes.empty? || !(entry.empty? || entry.valid?)

    GlossaryEntry.transaction do
      entry.empty? ? entry.destroy! : entry.save!
      record(term, language, "update", changes)
    end
    entry
  end

  private

  def record(term, language, kind, changes)
    term.revisions.create!(language: language, user: @user, origin: @origin, kind: kind, changes_made: changes)
  end
end
