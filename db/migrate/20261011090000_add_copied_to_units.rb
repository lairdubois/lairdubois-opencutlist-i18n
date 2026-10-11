class AddCopiedToUnits < ActiveRecord::Migration[8.1]
  def up
    # Denormalized : the fr source is a $t() or a {{ var }} alone, copied as is into every language
    add_column :units, :copied, :boolean, null: false, default: false
    Unit.reset_column_information
    Unit.refresh_translatable!
  end

  def down
    remove_column :units, :copied
  end
end
