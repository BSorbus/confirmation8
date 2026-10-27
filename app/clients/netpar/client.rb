require "net/http"

module Netpar
  # Usługa NETPAR nie odpowiedziała poprawnie (brak połączenia, błąd serwera, nieoczekiwana odpowiedź).
  class Unavailable < StandardError; end

  # Klient API NETPAR do weryfikacji świadectw.
  #
  # Kontrakt API (nie zmieniamy go – jest po stronie NETPAR):
  #   GET  /token                                         Basic Auth → {"token": "…"}
  #   GET  /certificates/mor_search_by_multi_params       świadectwa morskie (M)
  #   GET  /certificates/search_by_multi_params           pozostałe kategorie (L, R), parametr "category"
  # Zapytania wyszukiwania to GET z treścią JSON, nagłówki "Authorization: Token token=…" i "X-Real-IP".
  # Odpowiedzi: 200 {"certificates": […]} – znaleziono, 404 {"error": …} – brak danych,
  # 406 {"error": …} – niekompletne dane.
  class Client
    TOKEN_CACHE_KEY = "netpar/token"
    TOKEN_TTL = 9.minutes
    SEARCH_PATHS = {
      "M" => "certificates/mor_search_by_multi_params",
      "L" => "certificates/search_by_multi_params",
      "R" => "certificates/search_by_multi_params"
    }.freeze

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
      code = search.category.code
      body = search.to_netpar_params
      body = body.merge(category: code) unless code == "M"

      response = with_token { |token| get(SEARCH_PATHS.fetch(code), token:, body:, remote_ip:) }

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
