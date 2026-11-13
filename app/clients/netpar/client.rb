require "net/http"

module Netpar
  # Klient API NETPAR do weryfikacji świadectw.
  #
  # Kontrakt API (po stronie NETPAR):
  #   GET  /token                                      Basic Auth → {"token": "…"}
  #   GET  /divisions  {"enabled_in_confirmation": true}
  #        rodzaje włączone do weryfikacji (divisions.enabled_in_confirmation), wszystkie kategorie
  #        → 200 {"divisions": […], "meta": {"total_count": n}}
  #   GET  /certificates/search                       weryfikacja po danych z formularza (L, M, R), parametr "category";
  #        porównanie z bieżącym świadectwem i historią zmian
  #   GET  /certificates/search_by_code  {"code": …}   weryfikacja po kodzie świadectwa (QR karty i zaświadczenia: /qrc/<kod>);
  #        dane aktualne
  #   Obie: → 200 {"certificates": […], "meta": …} (z "verification_url" – adres do kodu QR zaświadczenia),
  #         403 {"error": …, "reason": …} – odmowa weryfikacji: "type_not_verifiable" – rodzaj wyłączony z weryfikacji,
  #           "issued_before_limit" – świadectwo wydane przed dniem "verifiable_from" (RRRR-MM-DD), od którego rodzaj podlega
  #           weryfikacji; bez reason (starszy NETPAR) – jak type_not_verifiable;
  #         404 {"error": …} – brak danych, 406 {"error": …} – niekompletne dane
  # Zapytania to GET z treścią JSON, nagłówki "Authorization: Token token=…" i "X-Real-IP".
  class Client
    TOKEN_CACHE_KEY = "netpar/token"
    TOKEN_TTL = 9.minutes
    SEARCH_PATH = "certificates/search"
    SEARCH_BY_CODE_PATH = "certificates/search_by_code"
    # Kod świadectwa: 16 znaków bez I, L, O, U (nadaje NETPAR) – inne odrzucamy bez pytania NETPAR.
    CODE_FORMAT = /\A[0-9A-HJKMNP-TV-Z]{16}\z/
    DIVISION_KEYS = %w[id category number_prefix name english_name].freeze

    def initialize(config: Rails.configuration.x.confirmation[:netpar], cache: Rails.cache, password: config[:password])
      @base_url = config.fetch(:url).chomp("/")
      @user = config.fetch(:user)
      @password = password
      @open_timeout = config.fetch(:open_timeout)
      @read_timeout = config.fetch(:read_timeout)
      @cache = cache
    end

    # Weryfikacja po danych z formularza: Certificate, :type_not_verifiable, Netpar::IssuedBeforeLimit albo nil (brak danych).
    def find_certificate(search, remote_ip:)
      body = search.to_netpar_params.merge(category: search.category.code)
      certificate_from(with_token { |token| get(SEARCH_PATH, token:, body:, remote_ip:) })
    end

    # Weryfikacja po kodzie świadectwa (QR: /qrc/<kod>) – jak find_certificate; kod o złym formacie – nil bez zapytania do NETPAR.
    def find_by_code(code, remote_ip:)
      code = code.to_s.strip.upcase
      return nil unless code.match?(CODE_FORMAT)

      certificate_from(with_token { |token| get(SEARCH_BY_CODE_PATH, token:, body: { code: }, remote_ip:) })
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
      # Odpowiedź search / search_by_code (ten sam format).
      def certificate_from(response)
        case response
        when Net::HTTPOK
          certificates = parse(response, expect: "certificates")
          certificates.first && Certificate.from_api(certificates.first)
        when Net::HTTPForbidden
          refusal_from(response)
        when Net::HTTPNotFound, Net::HTTPNotAcceptable
          parse(response, expect: "error") # upewnia się, że to odpowiedź API, a nie np. strona błędu serwera
          nil
        else
          raise Unavailable, "NETPAR: HTTP #{response.code}"
        end
      rescue KeyError, Date::Error => e
        raise Unavailable, "NETPAR: niepoprawne dane w odpowiedzi (#{e.class})"
      end

      # 403 – odmowa weryfikacji; rodzaj odmowy w polu reason.
      def refusal_from(response)
        parse(response, expect: "error") # upewnia się, że to odpowiedź API
        data = JSON.parse(response.body)
        return :type_not_verifiable unless data["reason"] == "issued_before_limit"

        IssuedBeforeLimit.new(verifiable_from: Date.iso8601(data.fetch("verifiable_from")))
      end

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
