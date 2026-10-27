# Dane z formularza wyszukiwania świadectwa.
class CertificateSearch
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks

  DATE_FIELDS = %i[date_of_issue valid_thru birth_date].freeze

  attribute :category_slug, :string
  attribute :division_id, :integer
  attribute :number, :string
  attribute :date_of_issue, :string
  attribute :valid_thru, :string
  attribute :no_expiry, :boolean, default: false
  attribute :name, :string
  attribute :given_names, :string
  attribute :birth_date, :string

  validates :category, presence: true
  validates :division_id, inclusion: { in: ->(search) { search.category&.divisions&.map(&:id) || [] } }
  validates :number, presence: true
  validate :number_format
  validates :date_of_issue, :birth_date, presence: true
  validates :valid_thru, presence: true, unless: :no_expiry
  validate :dates_format
  validates :name, :given_names, presence: true, length: { maximum: 100 }

  before_validation :normalize

  # Wypełnienie formularza z linku w kodzie QR starych i nowych zaświadczeń:
  # ?number_prefix=GG-&number=05998&date_of_issue=…&valid_thru=…&name=…&given_names=…&birth_date=…
  def self.from_link(params, category)
    division = category.divisions.find { it.number_prefix == params[:number_prefix] } || category.divisions.first
    new(category_slug: category.slug, division_id: division.id, number: params[:number],
        date_of_issue: params[:date_of_issue], valid_thru: params[:valid_thru],
        no_expiry: params[:name].present? && params[:valid_thru].blank?,
        name: params[:name], given_names: params[:given_names], birth_date: params[:birth_date])
  end

  def category = Category.find(category_slug)

  def division = Division.find(division_id)

  def number_prefix = division&.number_prefix

  # Parametry w formacie oczekiwanym przez API NETPAR.
  def to_netpar_params
    { number_prefix: number_prefix, number: number, date_of_issue: date_of_issue,
      valid_thru: no_expiry ? "" : valid_thru, name: name, given_names: given_names, birth_date: birth_date }
  end

  private
    def normalize
      self.number = number.to_s.gsub(/\s/, "")
      # NETPAR porównuje nazwiska bez wielkości liter i znaków narodowych, ale wewnętrzne spacje muszą się zgadzać.
      self.name = name.to_s.squish
      self.given_names = given_names.to_s.squish
      DATE_FIELDS.each { send("#{it}=", send(it).to_s.strip) }
      self.valid_thru = "" if no_expiry
    end

    def number_format
      return if number.blank? || category.nil?

      length = category.number_length
      unless number.match?(/\A\d+\z/) && length.cover?(number.length)
        key = length.min == length.max ? :number_exact_digits : :number_digits_range
        errors.add(:number, key, min: length.min, max: length.max)
      end
    end

    def dates_format
      DATE_FIELDS.each do |field|
        value = send(field)
        next if value.blank?

        Date.iso8601(value)
      rescue Date::Error
        errors.add(field, :invalid_date)
      end
    end
end
