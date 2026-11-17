# Łatka na błąd ttfunk 1.8.0 (wymaganego przez Prawn 2.5.0): przy osadzaniu podzbioru czcionki w PDF biblioteka
# przelicza tabelę maxp i zaniża limity – np. przy „ą” (glif złożony z „a” i ogonka) deklaruje brak glifów złożonych
# i 66 B instrukcji zamiast 188 B. Adobe Acrobat odrzuca wtedy podzbiór („Nie można wydzielić osadzonej czcionki
# …+DejaVuSans”) i błędnie pokazuje polskie litery w zaświadczeniu PDF (zgłoszenie 2026-11, świadectwo GS-40748).
# Starsze wersje (stare confirmation: ttfunk 1.5.1, NETPAR: 1.4.0) kopiowały maxp z pełnej czcionki – wracamy do tego:
# limity pełnej czcionki są górnym ograniczeniem dla każdego jej podzbioru. Zmienia się tylko liczba glifów.
# Tylko dla ttfunk 1.8.0 – po aktualizacji test/pdfs/pdf_statement_test.rb przypomni, by sprawdzić, czy łatka
# jest jeszcze potrzebna.
require "ttfunk"

TTFUNK_MAXP_PATCHED_VERSION = "1.8.0"

if Gem.loaded_specs["ttfunk"]&.version.to_s == TTFUNK_MAXP_PATCHED_VERSION
  module TTFunkMaxpFromFullFont
    def encode(maxp, new2old_glyph)
      return super unless maxp.version == 0x10000 # wersja 0.5 (czcionki CFF) – tylko liczba glifów, bez limitów

      full = maxp.file.contents.string.byteslice(maxp.offset, maxp.length)
      [ maxp.version, new2old_glyph.length ].pack("Nn") + full.byteslice(6, 26)
    end
  end

  TTFunk::Table::Maxp.singleton_class.prepend(TTFunkMaxpFromFullFont)
end
