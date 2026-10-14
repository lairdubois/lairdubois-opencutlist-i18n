# Someone without an account offering to translate a language (volunteers#new, from the login page). Nothing is
# created until an admin accepts it (accept!) : the user, their membership and, for a new one, the language.
# Spam : a hidden honeypot field and a signed form timestamp (FormToken), a rate limit per IP in the controller,
# a closed language list, one pending request per address and language, and a cap on the pending ones
class VolunteerRequest < ApplicationRecord
  # ISO 639-1 codes offered for a new language : { "de" => { "name" => "Deutsch", "rtl" => false } }
  LANGUAGES = YAML.load_file(Rails.root.join("config/iso_languages.yml")).freeze
  # Beyond that many pending requests, new ones are dropped (a flood the admins should look at first)
  PENDING_MAX = 100

  # Signed timestamp of the form's rendering : a submission sooner than MIN_DELAY (a bot) or older than
  # MAX_AGE is dropped
  module FormToken
    MIN_DELAY = 3.seconds
    MAX_AGE = 1.day

    def self.generate
      verifier.generate(Time.current.to_i, expires_in: MAX_AGE)
    end

    def self.valid?(token)
      issued_at = verifier.verified(token.to_s)
      issued_at.is_a?(Integer) && Time.at(issued_at) <= MIN_DELAY.ago
    end

    def self.verifier
      Rails.application.message_verifier(:volunteer_form)
    end
  end

  belongs_to :user, optional: true
  belongs_to :handled_by, class_name: "User", optional: true

  enum :status, { pending: 0, accepted: 1, rejected: 2 }

  normalizes :email, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.squish }
  validates :name, presence: true, length: { maximum: 80 }, format: { without: %r{https?:|www\.|[<>@/]}i }
  validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :language_code, inclusion: { in: ->(_) { codes } }

  # The source language aside : existing target languages and the ISO list
  def self.codes
    (Language.targets.pluck(:code) + LANGUAGES.keys).uniq - [Language::SOURCE_CODE]
  end

  # Already asked and still pending : not stored twice
  def duplicate?
    VolunteerRequest.pending.exists?(email: email, language_code: language_code)
  end

  def language
    Language.find_by(code: language_code)
  end

  def language_name
    language&.name || LANGUAGES.dig(language_code, "name") || language_code
  end

  def existing_user
    User.find_by(email: email)
  end

  # Creates what's missing (language, user, membership) and returns the user. An existing user keeps their name,
  # an admin gets no membership (they have every language)
  def accept!(admin)
    transaction do
      language = self.language || Language.create!(code: language_code, name: language_name,
                                                   rtl: LANGUAGES.dig(language_code, "rtl") || false,
                                                   position: Language.unscoped.maximum(:position).to_i + 1)
      user = User.create_with(name: name, locale: (locale if I18n.available_locales.map(&:to_s).include?(locale)))
                 .find_or_create_by!(email: email)
      user.memberships.find_or_create_by!(language: language) unless user.admin?
      update!(status: :accepted, user: user, handled_by: admin, handled_at: Time.current)
      user
    end
  end

  # Told by e-mail (VolunteerMailer) when e-mails are enabled
  def recipients
    User.enabled.where(admin: true)
  end

  def reject!(admin)
    update!(status: :rejected, handled_by: admin, handled_at: Time.current)
  end
end
