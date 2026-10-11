class AddNoTranslate < ActiveRecord::Migration[8.1]
  def change
    # Denormalized from the @no-translate / @translate directives of the unit's and its branches' notes
    add_column :units, :translatable, :boolean, null: false, default: true

    # YAML comments written above a branch (a mapping key) : branches have no unit
    create_table :branch_notes do |t|
      t.string :path, null: false
      t.text :note, null: false
      t.timestamps
    end
    add_index :branch_notes, :path, unique: true

    # { path => note } of the fr.yml, nil in baselines recorded before branch notes were synced
    add_column :baselines, :branch_notes, :json
  end
end
