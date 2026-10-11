# SQLite's LIKE folds the case of ASCII letters only ("Ø" LIKE "ø" is false) : text searches compare
# fold(column) LIKE fold(pattern) instead, fold being SqliteFold.fold (case and accents aside)
module SqliteFold
  # Lowercase, without combining marks ("É" → "e" ; "Ø", which has none, → "ø")
  def self.fold(text)
    text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
  end

  private

  def configure_connection
    super
    @raw_connection.create_function("fold", 1) do |func, text|
      func.result = text.is_a?(String) ? SqliteFold.fold(text.dup.force_encoding(Encoding::UTF_8)) : text
    end
  end
end

ActiveSupport.on_load(:active_record_sqlite3adapter) { prepend SqliteFold }
