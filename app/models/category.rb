# Kategoria świadectw (zakładka formularza). `code` jak w NETPAR, `slug` w adresie strony.
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
    enabled.find { it.slug == slug.to_s }
  end

  def self.default = enabled.first

  def divisions = Division.for_category(code)

  # Zatwierdzone zaświadczenie PDF ma treść dotyczącą świadectw morskich (ITU RR, IMO STCW).
  # Dla pozostałych kategorii PDF będzie dostępny, gdy urząd zatwierdzi jego treść.
  def statement? = code == "M"

  def to_param = slug
end
