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

  def test_parse_get_request
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Host: localhost:8080
      Connection: close

    HTTP

    request = Pigeon::Request.parse(raw_request)

    assert_equal 'GET', request.method
    assert_equal '/', request.target
    assert_equal 'localhost:8080', request.host
  end

  def test_parse_with_mixed_case_host_header
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      hOsT: localhost:8080
      Connection: close

    HTTP

    request = Pigeon::Request.parse(raw_request)

    assert_equal 'localhost:8080', request.host
  end

  def test_parse_with_host_after_connection
     raw_request = <<~HTTP.gsub("\n", CRLF)
      GET /hello HTTP/1.1
      Connection: close
      Host: localhost:8080

    HTTP

    request = Pigeon::Request.parse(raw_request)

    assert_equal 'GET', request.method
    assert_equal 'localhost:8080', request.host
    assert_equal '/hello', request.target
 end
end
