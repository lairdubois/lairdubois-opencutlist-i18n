# The YAML comment written above a branch (a mapping key) in every language file. Branches have no unit :
# the note is tied to the dotted path, moved along by UnitOperations#rename_branch.
class BranchNote < ApplicationRecord
  validates :path, presence: true, uniqueness: true, format: { with: Unit::KEY_FORMAT }
  validates :note, presence: true

  # { path => note }
  def self.to_map
    pluck(:path, :note).to_h
  end
end
