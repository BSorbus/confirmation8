require "net/http"

module Netpar
  # Klient API NETPAR do weryfikacji świadectw.
  #
  # Kontrakt API (po stronie NETPAR):
  #   GET  /token                                      Basic Auth → {"token": "…"}
  #   GET  /divisions  {"enabled_in_confirmation": true}
  #        rodzaje włączone do weryfikacji (divisions.enabled_in_confirmation), wszystkie kategorie
  #        → 200 {"divisions": […], "meta": {"total_count": n}}
  #   GET  /confirmation/certificates/search           weryfikacja świadectwa (L, M, R), parametr "category";
  #        NETPAR szuka tylko świadectw rodzajów z enabled_in_confirmation
  #        → 200 {"certificates": […]} – znaleziono, 404 {"error": …} – brak danych, 406 {"error": …} – niekompletne dane
  # Zapytania to GET z treścią JSON, nagłówki "Authorization: Token token=…" i "X-Real-IP".
  class Client
    TOKEN_CACHE_KEY = "netpar/token"
    TOKEN_TTL = 9.minutes
    SEARCH_PATH = "confirmation/certificates/search"
    DIVISION_KEYS = %w[id category number_prefix name english_name].freeze

    def initialize(config: Rails.configuration.x.confirmation[:netpar], cache: Rails.cache, password: config[:password])
      @base_url = config.fetch(:url).chomp("/")
      @user = config.fetch(:user)
      @password = password
      @open_timeout = config.fetch(:open_timeout)
      @read_timeout = config.fetch(:read_timeout)
      @cache = cache
    end

    # Zwraca Certificate albo nil, gdy NETPAR nie potwierdza świadectwa.
    def find_certificate(search, remote_ip:)
      body = search.to_netpar_params.merge(category: search.category.code)
      response = with_token { |token| get(SEARCH_PATH, token:, body:, remote_ip:) }

      case response
      when Net::HTTPOK
        certificates = parse(response, expect: "certificates")
        certificates.first && Certificate.from_api(certificates.first)
      when Net::HTTPNotFound, Net::HTTPNotAcceptable
        parse(response, expect: "error") # upewnia się, że to odpowiedź API, a nie np. strona błędu serwera
        nil
      else
        raise Unavailable, "NETPAR: HTTP #{response.code}"
      end
    rescue KeyError, Date::Error => e
      raise Unavailable, "NETPAR: niepoprawne dane w odpowiedzi (#{e.class})"
    end

    # Rodzaje świadectw włączone do weryfikacji w Confirmation (tablica hashy z co najmniej DIVISION_KEYS).
    def enabled_divisions
      response = with_token { |token| get("divisions", token:, body: { enabled_in_confirmation: true }, remote_ip: nil) }
      raise Unavailable, "NETPAR /divisions: HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)

      rows = parse(response, expect: "divisions")
      raise Unavailable, "NETPAR /divisions: niekompletne dane" unless rows.is_a?(Array) && rows.all? { it.is_a?(Hash) && (DIVISION_KEYS - it.keys).empty? }

      rows
    end

    private
      def with_token
        response = yield token
        return response unless response.is_a?(Net::HTTPUnauthorized)

        @cache.delete(TOKEN_CACHE_KEY)
        yield token
      end

      def token
        @cache.fetch(TOKEN_CACHE_KEY, expires_in: TOKEN_TTL) do
          request = Net::HTTP::Get.new(uri("token"))
          request.basic_auth(@user, @password)
          response = perform(request)
          raise Unavailable, "NETPAR /token: HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)

          parse(response, expect: "token")
        end
      end

      def get(path, token:, body:, remote_ip:)
        request = Net::HTTP::Get.new(uri(path), "Content-Type" => "application/json",
                                                "Authorization" => "Token token=#{token}",
                                                "X-Real-IP" => remote_ip.to_s)
        request.body = body.to_json
        perform(request)
      end

      def perform(request)
        target = request.uri
        Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == "https",
                        open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
          http.request(request)
        end
      rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError => e
        raise Unavailable, "NETPAR: #{e.class}: #{e.message}"
      end

      # Zwraca wartość klucza `expect` z odpowiedzi JSON; każda inna odpowiedź oznacza niedostępność usługi
      # (np. NETPAR bez danego endpointu odpowiada 200 z treścią "null").
      def parse(response, expect:)
        data = JSON.parse(response.body.to_s)
        raise Unavailable, "NETPAR: brak klucza #{expect} w odpowiedzi (HTTP #{response.code})" unless data.is_a?(Hash) && data[expect]

        data[expect]
      rescue JSON::ParserError
        raise Unavailable, "NETPAR: odpowiedź nie jest JSON-em (HTTP #{response.code})"
      end

      def uri(path) = URI("#{@base_url}/#{path}")
  end
end
