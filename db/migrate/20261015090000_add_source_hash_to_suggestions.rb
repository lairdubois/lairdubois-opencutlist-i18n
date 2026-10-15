class AddSourceHashToSuggestions < ActiveRecord::Migration[8.1]
  def change
    # The fr text's hash the suggestion was computed on : older rows (nil) count as stale
    add_column :suggestions, :source_hash, :string
  end
end
