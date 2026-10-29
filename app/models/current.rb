# Dane ważne tylko w obrębie jednego żądania HTTP (czyszczone po każdym żądaniu).
class Current < ActiveSupport::CurrentAttributes
  # Lista rodzajów pobrana z NETPAR w tym żądaniu – formularz, walidacja i wynik korzystają z jednej odpowiedzi.
  attribute :divisions
end
