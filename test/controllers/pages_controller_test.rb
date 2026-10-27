require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  %w[pl en].each do |locale|
    test "deklaracja dostępności (#{locale}): poprawny HTML i unikalne identyfikatory" do
      get "/#{locale}/declaration"
      assert_response :success

      doc = Nokogiri::HTML5.parse(response.body, max_errors: 50)
      assert_empty doc.errors.map(&:to_s), "błędy HTML w deklaracji #{locale}"

      ids = doc.css("[id]").map { it["id"] }
      assert_equal ids.uniq, ids, "zdublowane id: #{ids.tally.select { |_, n| n > 1 }.keys}"
      assert_select "a#a11y-url[href='https://confirmation.uke.gov.pl']"
    end
  end
end
