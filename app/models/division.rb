# Rodzaj świadectwa – dane z config/divisions.yml (kopia tabeli `divisions` z NETPAR).
class Division
  attr_reader :id, :category, :number_prefix, :name, :english_name

  def self.all
    @all ||= YAML.load_file(Rails.root.join("config/divisions.yml")).map { new(**it.symbolize_keys) }.freeze
  end

  def self.find(id)
    all.find { it.id == id.to_i }
  end

  def self.for_category(code)
    all.select { it.category == code }
  end

  def initialize(id:, category:, number_prefix:, name:, english_name:)
    @id, @category, @number_prefix, @name, @english_name = id, category, number_prefix, name, english_name
  end

  # Nazwa w języku strony; krajowe rodzaje bez nazwy angielskiej pokazujemy po polsku.
  def label(locale = I18n.locale)
    locale.to_s == "en" && english_name.present? ? english_name : name
  end
end
