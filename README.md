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

Dane dostępu przeniesione ze starego `config/secrets.yml` są w zaszyfrowanych plikach: lokalnie
`config/credentials/development.yml.enc`, dla serwerów `config/deploy/<serwer>/production.yml.enc` (poza gitem,
każdy serwer z własnym kluczem `config/deploy/<serwer>/production.key`):

```yaml
secret_key_base: …          # tylko production; nowy, inny niż w starej aplikacji
netpar:
  url: https://…/api/v1
  user: confirmation
  password: …
matomo:
  enabled: false            # opcjonalnie, np. serwer testowy bez statystyk
categories: [M, L]          # opcjonalnie – zakładki na tym serwerze (bez wpisu: M, L, R)
```

Edycja lokalnie: `bin/rails credentials:edit --environment development`; credentials serwera –
`bin/rails encrypted:edit config/deploy/<serwer>/production.yml.enc --key config/deploy/<serwer>/production.key`.
Klucze nie są w repozytorium – trzeba je przechowywać bezpiecznie; na serwer trafiają przez `mina <serwer> credentials:push`.
Bez tych danych aplikacja nie wystartuje (komunikat „Brak ustawień: …”). Każdą wartość można nadpisać zmienną środowiskową (`NETPAR_URL`, `NETPAR_USER`, `NETPAR_PASSWORD`, `MATOMO_ENABLED`, `CONFIRMATION_CATEGORIES`) – patrz `config/initializers/confirmation.rb`.

Adres w kodzie QR na zaświadczeniu buduje NETPAR (pole `verification_url` w odpowiedzi API weryfikacji – krótki adres
`<confirmation>/qrc/<kod świadectwa>`, ten sam co na karcie plastikowej); serwer confirmation NETPAR bierze z
`confirmation_search_url` w swoim `config/secrets.yml` (domyślnie `https://confirmation.uke.gov.pl/certificates/new`). Dawny klucz `search_url` w credentials nie jest już używany.

## Wdrożenie (mina)

`config/deploy.rb` (adresy serwerów) i `config/deploy/<serwer>/` (credentials przygotowane dla danego serwera)
są tylko lokalnie – w `.gitignore`. Opis zadań na początku `config/deploy.rb`; podgląd poleceń bez wykonywania:
`bundle exec mina test2 deploy --simulate`. Credentials serwerów: `config/deploy/test2/` (serwer testowy),
`config/deploy/prod2/` (produkcja, serwer 10.100.2.65).

Każdy serwer ma własne credentials i klucz w `shared/config/credentials/` – w wydaniu `config/credentials` to
dowiązanie do tego katalogu. Zmiana na serwerze:
`cd /webapps/confirmation8/current && EDITOR=nano bin/rails credentials:edit --environment production`,
potem `touch tmp/restart.txt`. Z komputera lokalnego: `mina <serwer> credentials:show_remote` (co serwer ma ustawione, bez haseł), `credentials:edit_remote`
(edycja na serwerze z kopią zapasową, sprawdzeniem startu aplikacji i restartem; potem lokalna kopia z serwera),
`credentials:show_local` / `credentials:edit_local` (lokalna kopia) i `credentials:push` (wysłanie lokalnej kopii z kluczem na serwer – zawsze, poprzednie pliki zostają jako `.bak-<czas>`; sprawdzenie startu i restart) – opis w `config/deploy.rb`.

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
| `categories` w credentials (lub `CONFIRMATION_CATEGORIES`) | kategorie (zakładki) pokazywane na danym serwerze, np. `categories: [M, L]` (zmienna: `M,L`); domyślnie wszystkie – `M,L,R` z `config/confirmation.yml` |
| `matomo.enabled` w credentials (lub `MATOMO_ENABLED`) | statystyki Matomo w produkcji (domyślnie włączone; na serwerze testowym `false`) |

## Współpraca z NETPAR

Kontrakt API opisuje `app/clients/netpar/client.rb`:

- `GET /divisions` z `enabled_in_confirmation: true` – rodzaje świadectw, które urząd zaznaczył w panelu NETPAR
  jako „Dozwolony dla weryfikacji w Confirmation” (`divisions.enabled_in_confirmation`). Lista jest pobierana
  na żywo przy każdym wyświetleniu strony – bez pamięci podręcznej i bez lokalnej kopii.
- Zakładki formularza: confirmation8 decyduje, które kategorie (M, L, R) pokazuje (`categories` /
  `CONFIRMATION_CATEGORIES`), a NETPAR – które rodzaje są w nich dostępne. Gdy w NETPAR żaden rodzaj
  danej kategorii nie jest zaznaczony, zakładka jest widoczna z pustą listą rodzajów.
- `GET /certificates/search` – weryfikacja po danych z formularza, we wszystkich kategoriach (parametr `category`).
- `GET /certificates/search_by_code` – weryfikacja po kodzie świadectwa (parametr `code`) – strona `/qrc/<kod>`, na którą
  prowadzi kod QR karty plastikowej i zaświadczenia; od razu wynik, bez klikania „Sprawdź”.
- Obie odpowiedzi w tym samym formacie. Odmowa weryfikacji – 403 z polem `reason`: `type_not_verifiable` (rodzaj
  niewłączony do weryfikacji) albo `issued_before_limit` (świadectwo wydane przed dniem `verifiable_from`, od którego rodzaj
  podlega weryfikacji – „Weryfikacja świadectw wydanych od” przy rodzaju w panelu NETPAR, `divisions.confirmation_issued_from`).
  Tę datę zwraca też `/divisions` (`confirmation_issued_from`): formularz pokazuje ją pod datą wydania i od razu zgłasza
  wcześniejszą datę jako błąd pola, bez zapytania do NETPAR.

Gdy NETPAR nie odpowiada, strona pokazuje komunikat „Weryfikacja chwilowo niedostępna”.

## Zgodność z poprzednią wersją

- Adresy `/certificates` i `/certificates/new?number_prefix=…&number=…` (długie kody QR na zaświadczeniach wydanych
  przed kodem świadectwa) działają i wypełniają formularz. Nowe zaświadczenia mają krótki kod `/qrc/<kod>`.
- Zaświadczenie PDF (`app/pdfs/pdf_statement.rb`) jest przeniesione 1:1 – teksty, układ i czcionki bez zmian.
  Dane do PDF pochodzą wyłącznie z odpowiedzi NETPAR (ponowne potwierdzenie przy każdym pobraniu).
- Deklaracja dostępności (`app/views/pages/declaration.*.html.erb`) – treść bez zmian.
