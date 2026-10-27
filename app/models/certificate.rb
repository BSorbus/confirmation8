# Świadectwo potwierdzone przez API NETPAR.
class Certificate < Data.define(:number, :date_of_issue, :valid_thru, :category, :division, :holder)
  class Division < Data.define(:name, :english_name, :short_name, :number_prefix)
    def label(locale = I18n.locale)
      locale.to_s == "en" && english_name.present? ? english_name : name
    end
  end

  Holder = Data.define(:name, :given_names, :birth_date)

  def self.from_api(data)
    division = data.fetch("division")
    customer = data.fetch("customer")
    new(number: data["number"].to_s.strip,
        date_of_issue: parse_date(data["date_of_issue"]),
        valid_thru: parse_date(data["valid_thru"]),
        category: data["category"],
        division: Division.new(name: division["name"], english_name: division["english_name"],
                               short_name: division["short_name"], number_prefix: division["number_prefix"]),
        holder: Holder.new(name: customer["name"], given_names: customer["given_names"],
                           birth_date: parse_date(customer["birth_date"])))
  end

  def self.parse_date(value)
    value.present? ? Date.iso8601(value.to_s) : nil
  end

  def unlimited? = valid_thru.nil?

  def expired?(today = Date.current) = !unlimited? && valid_thru < today
end
