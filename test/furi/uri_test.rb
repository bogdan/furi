# frozen_string_literal: true

require "test_helper"

class FuriUriTest < Minitest::Test
  def test_rfc3986
    refute Furi.parse("http://goo gl.com").rfc?
    assert Furi.parse("http://googl.com").rfc?
  end
end
