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

  def test_parse_rejects_request_line_with_extra_parts
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1 extra
      Host: localhost:8080

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end

  def test_parse_rejects_incomplete_request_line
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET /
      Host: localhost:8080

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end

  def test_parse_rejects_header_name_with_space
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Host: localhost:8080
      Invalid Header: value

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end

  def test_parse_rejects_header_with_empty_name
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Host: localhost:8080
      : value

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end

  def test_parse_rejects_header_without_colon
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Host: localhost:8080
      Invalid-Header

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end

  def test_parse_rejects_missing_host
    raw_request = <<~HTTP.gsub("\n", CRLF)
      GET / HTTP/1.1
      Connection: close

    HTTP

    assert_raises(Pigeon::ParseError) do
      Pigeon::Request.parse(raw_request)
    end
  end
end
