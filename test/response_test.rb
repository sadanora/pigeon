# frozen_string_literal: true

require_relative 'test_helper'
require 'pigeon'

class ResponseTest < Minitest::Test
  CRLF = "\r\n"

  def test_to_http
    header = <<~HTTP.gsub("\n", CRLF)
      HTTP/1.1 200 OK
      Content-Type: text/plain
      Content-Length: 5
      Connection: close

    HTTP
    body = 'Hello'
    expected = header + body

    response = Pigeon::Response.new(
      content_type: 'text/plain',
      body: 'Hello'
    )

    assert_equal expected, response.to_http
  end
end
