class AddPretranslateNoTranslateToLanguages < ActiveRecord::Migration[8.1]
  def change
    # Pre-translation also covers the @no-translate keys of this language (an admin's temporary choice)
    add_column :languages, :pretranslate_no_translate, :boolean, default: false, null: false
  end
end
