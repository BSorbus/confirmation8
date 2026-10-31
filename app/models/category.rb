# Kategoria świadectw (zakładka formularza). `code` jak w NETPAR, `slug` w adresie strony.
# Zakładki (kategorie) włącza config/confirmation.yml (`categories`); rodzaje w zakładce ustala NETPAR
# (divisions.enabled_in_confirmation) – patrz Division.
class Category < Data.define(:slug, :code, :number_length)
  ALL = [
    new(slug: "maritime",     code: "M", number_length: 5..5),
    new(slug: "aeronautical", code: "L", number_length: 2..5),
    new(slug: "amateur",      code: "R", number_length: 2..5)
  ].freeze

  def self.enabled
    codes = Rails.configuration.x.confirmation[:categories]
    ALL.select { codes.include?(it.code) }
  end

  def self.find(slug)
    ALL.find { it.slug == slug.to_s }
  end

  def self.default = enabled.first

  def enabled? = Category.enabled.include?(self)

  def divisions = Division.for_category(code)

  # Zaświadczenie PDF – dla kategorii, które mają treści w config/statements.yml.
  def statement? = statement_texts.present?

  def statement_texts = Rails.configuration.x.statements[:categories][code.to_sym]

  # Adres kontaktowy kategorii (ten sam co w stopce zaświadczenia).
  def contact_email = statement_texts&.dig(:email)

  def to_param = slug
end
