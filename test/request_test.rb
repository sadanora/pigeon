# frozen_string_literal: true

require_relative 'test_helper'
require 'pigeon'

class RequestTest < Minitest::Test
  CRLF = "\r\n"

  def test_to_http
    request = Pigeon::Request.new(
      method: 'GET',
      target: '/',
      host: 'localhost:8080'
    )

    expected = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Host: localhost:8080
      Connection: close

    HTTP

    assert_equal expected, request.to_http
  end
end
