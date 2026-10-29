# Rodzaj świadectwa (tabela `divisions` w NETPAR).
#
# Lista rodzajów włączonych do weryfikacji (divisions.enabled_in_confirmation – zaznaczane w panelu NETPAR)
# jest pobierana z API NETPAR na żywo – raz na żądanie HTTP, bez pamięci podręcznej między żądaniami
# i bez lokalnej kopii. Gdy NETPAR nie odpowiada, zgłaszamy Netpar::Unavailable (strona pokazuje komunikat).
class Division
  FIELDS = %i[id category number_prefix name english_name].freeze

  attr_reader(*FIELDS)

  def self.all
    Current.divisions ||= fetch
  end

  def self.find(id)
    all.find { it.id == id.to_i }
  end

  def self.for_category(code)
    all.select { it.category == code }
  end

  def self.fetch
    Netpar::Client.new.enabled_divisions.map { new(**it.slice(*FIELDS.map(&:to_s)).symbolize_keys) }
  rescue Netpar::Unavailable
    Current.divisions = [] # do końca żądania pusta lista: strona z komunikatem renderuje się bez kolejnych prób
    raise
  end

  def initialize(id:, category:, number_prefix:, name:, english_name:)
    @id, @category, @number_prefix, @name, @english_name = id, category, number_prefix, name, english_name.to_s
  end

  # Nazwa w języku strony; krajowe rodzaje bez nazwy angielskiej pokazujemy po polsku.
  def label(locale = I18n.locale)
    locale.to_s == "en" && english_name.present? ? english_name : name
  end
end
