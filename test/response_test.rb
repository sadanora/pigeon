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
      status_code: 200,
      reason_phrase: 'OK',
      content_type: 'text/plain',
      body: 'Hello'
    )

    assert_equal expected, response.to_http
  end

  def test_parse_response
    header = <<~HTTP.gsub("\n", CRLF)
      HTTP/1.1 200 OK
      Content-Type: text/plain
      Content-Length: 5
      Connection: close

    HTTP
    body = 'Hello'
    raw_response = header + body

    response = Pigeon::Response.parse(raw_response)
    assert_equal 200, response.status_code
    assert_equal 'OK', response.reason_phrase
    assert_equal 'text/plain', response.content_type
    assert_equal 'Hello', response.body
  end

  def test_parse_with_multiword_reason_phrase
    header = <<~HTTP.gsub("\n", CRLF)
      HTTP/1.1 404 Not Found
      Content-Type: text/plain
      Content-Length: 9
      Connection: close

    HTTP
    body = 'Not Found'
    response = Pigeon::Response.parse(header + body)

    assert_equal 404, response.status_code
    assert_equal 'Not Found', response.reason_phrase
  end

  def test_parse_preserves_multiline_body
    header = <<~HTTP.gsub("\n", CRLF)
      HTTP/1.1 200 OK
      Content-Type: text/plain
      Content-Length: 12
      Connection: close

    HTTP
    body = "Hello\r\nWorld"
    response = Pigeon::Response.parse(header + body)

    assert_equal "Hello\r\nWorld", response.body
  end
end
