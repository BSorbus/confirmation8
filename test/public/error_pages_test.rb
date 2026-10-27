require "test_helper"

# Statyczne strony błędów z public/ (serwowane także wtedy, gdy aplikacja nie działa).
class ErrorPagesTest < ActiveSupport::TestCase
  %w[400 404 422 500].each do |code|
    test "strona błędu #{code}: poprawny HTML, PL i EN, link do strony głównej" do
      doc = Nokogiri::HTML5.parse(File.read(Rails.root.join("public/#{code}.html")), max_errors: 50)

      assert_empty doc.errors.map(&:to_s)
      assert_equal "pl", doc.at_css("html")["lang"]
      assert doc.at_css("section[lang=en]"), "brak wersji angielskiej"
      assert doc.at_css("a[href='/pl']") && doc.at_css("a[href='/en']"), "brak linków do strony głównej"
      assert_no_match(/Rails|Ruby/i, doc.text, "strona nie powinna zdradzać technologii")
    end
  end
end
