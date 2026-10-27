require "test_helper"

class RemoveRailsHstsTest < ActiveSupport::TestCase
  # Ten sam układ co w produkcji: RemoveRailsHsts obejmuje ActionDispatch::SSL (force_ssl).
  def stack
    app = ->(_env) { [ 200, { "content-type" => "text/plain", "set-cookie" => "a=1; path=/" }, [ "ok" ] ] }
    RemoveRailsHsts.new(ActionDispatch::SSL.new(app))
  end

  test "usuwa nagłówek HSTS dodany przez Rails, zostawia resztę force_ssl" do
    status, headers, = stack.call(Rack::MockRequest.env_for("https://example.test/pl"))

    assert_equal 200, status
    assert_nil headers["strict-transport-security"]
    assert_match(/secure/i, Array(headers["set-cookie"]).join("\n")) # ciasteczka nadal oznaczone jako Secure
  end

  test "przekierowanie z HTTP na HTTPS nadal działa" do
    status, headers, = stack.call(Rack::MockRequest.env_for("http://example.test/pl"))

    assert_equal 301, status
    assert_equal "https://example.test/pl", headers["location"]
  end
end
