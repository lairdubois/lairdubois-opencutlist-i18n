class CreateGlossary < ActiveRecord::Migration[8.1]
  def change
    # A fr term (and its other forms : plural…) with its definition, created by the admins
    create_table :glossary_terms do |t|
      t.string :term, null: false
      t.text :variants
      t.text :definition
      # Kept as is in every language (product names)
      t.boolean :no_translate, default: false, null: false
      t.datetime :archived_at
      t.timestamps
    end

    # The term expected in a language, set by its reviewers
    create_table :glossary_entries do |t|
      t.references :glossary_term, null: false, foreign_key: true
      t.references :language, null: false, foreign_key: true
      t.string :term
      t.text :variants
      t.text :avoid
      t.text :note
      t.timestamps
    end
    add_index :glossary_entries, [:glossary_term_id, :language_id], unique: true

    # Append-only history of the terms (language nil) and of their entries
    create_table :glossary_revisions do |t|
      t.references :glossary_term, null: false, foreign_key: true
      t.references :language, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false
      t.json :changes_made
      t.datetime :created_at, null: false
    end
  end
end
