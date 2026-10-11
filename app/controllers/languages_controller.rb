# Home : the languages the user can work on, with their progress (the @no-translate keys left out)
class LanguagesController < ApplicationController
  def index
    @languages = current_user.editable_languages.to_a
    @stats = Language.stats(@languages)
  end
end
