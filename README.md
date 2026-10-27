# confirmation8

Weryfikacja świadectw operatorów urządzeń radiowych UKE (następca aplikacji `confirmation`).
Użytkownik wybiera kategorię (morskie, lotnicze, radioamatorskie), wpisuje dane ze świadectwa,
a aplikacja potwierdza je w rejestrze NETPAR i – dla świadectw morskich – wydaje zaświadczenie PDF z kodem QR.

Ruby 4.0, Rails 8.1, Hotwire (Turbo, Stimulus), Bootstrap 5.3, Prawn. Bez bazy danych.

## Uruchomienie (development)

```sh
cd confirmation8             # rvm sam przełącza na Ruby 4.0.7 (plik .ruby-version)
bundle install
bin/rails server             # http://localhost:3000
```

Na maszynie deweloperskiej z Ubuntu 18.04 (glibc 2.27) gemy z rozszerzeniami w C kompilują się ze źródeł –
ustawia to lokalna konfiguracja Bundlera (`.bundle/config`: `BUNDLE_FORCE_RUBY_PLATFORM: "true"`), która nie trafia do repozytorium.

Wymaga lokalnego NETPAR na `http://localhost:3001/api/v1` (inny adres: `NETPAR_URL`).

## Sekrety (credentials)

Dane dostępu przeniesione ze starego `config/secrets.yml` są w zaszyfrowanych plikach
`config/credentials/development.yml.enc` i `config/credentials/production.yml.enc`:

```yaml
secret_key_base: …          # tylko production; nowy, inny niż w starej aplikacji
netpar:
  url: https://…/api/v1
  user: confirmation
  password: …
search_url: https://…/certificates/new
```

Edycja: `bin/rails credentials:edit --environment production`. Klucze `config/credentials/*.key`
nie są w repozytorium – trzeba je przechowywać bezpiecznie i skopiować na serwer przy wdrożeniu.
Bez tych danych aplikacja nie wystartuje (komunikat „Brak ustawień: …”). Każdą wartość można nadpisać zmienną środowiskową (`NETPAR_URL`, `NETPAR_USER`, `NETPAR_PASSWORD`,
`CONFIRMATION_SEARCH_URL`) – patrz `config/initializers/confirmation.rb`.

## Testy i kontrola jakości

```sh
bin/rails test     # testy (NETPAR zastąpiony przez WebMock)
bin/rubocop        # styl kodu
bin/brakeman       # bezpieczeństwo
```

## Konfiguracja

| Plik / zmienna | Znaczenie |
|---|---|
| `config/confirmation.yml` | ustawienia niezależne od serwera: limity czasu NETPAR, kategorie, Matomo |
| `CONFIRMATION_CATEGORIES` | widoczne kategorie, domyślnie `M,L,R` |
| `MATOMO_ENABLED` | statystyki Matomo w produkcji (domyślnie `true`) |
| `config/divisions.yml` | rodzaje świadectw – dosłowna kopia tabeli `divisions` z NETPAR |

## Współpraca z NETPAR

Kontrakt API opisuje `app/clients/netpar/client.rb`. Świadectwa morskie (M) korzystają z istniejącego
endpointu `certificates/mor_search_by_multi_params`. Lotnicze (L) i radioamatorskie (R) wymagają w NETPAR
endpointu `certificates/search_by_multi_params` z parametrem `category` – do czasu jego wdrożenia
wyszukiwanie w tych kategoriach kończy się komunikatem „Weryfikacja chwilowo niedostępna”
(kategorie można ukryć: `CONFIRMATION_CATEGORIES=M`).

## Zgodność z poprzednią wersją

- Adresy `/certificates` i `/certificates/new?number_prefix=…&number=…` (kody QR na wydanych zaświadczeniach) działają
  i wypełniają formularz morski.
- Zaświadczenie PDF (`app/pdfs/pdf_statement.rb`) jest przeniesione 1:1 – teksty, układ i czcionki bez zmian.
  Dane do PDF pochodzą wyłącznie z odpowiedzi NETPAR (ponowne potwierdzenie przy każdym pobraniu).
- Deklaracja dostępności (`app/views/pages/declaration.*.html.erb`) – treść bez zmian.
