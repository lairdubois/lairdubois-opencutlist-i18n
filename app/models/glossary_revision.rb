# Append-only history of the glossary : a term's changes (language nil) and its entries' (language set).
# changes_made : { field => [old, new] }. origin : the author without a user (the API's robot)
class GlossaryRevision < ApplicationRecord
  KINDS = %w[create update archive restore].freeze

  belongs_to :glossary_term
  belongs_to :language, optional: true
  belongs_to :user, optional: true

  validates :kind, inclusion: { in: KINDS }

  default_scope { order(:created_at, :id) }
end
