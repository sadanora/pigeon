# frozen_string_literal: true

require_relative 'test_helper'
require 'pigeon'

describe Pigeon::Response do
  let(:crlf) { "\r\n" }

  describe '#to_http' do
    it 'serializes a response' do
      header = <<~HTTP.gsub("\n", crlf)
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

    it 'serializes the specified HTTP version' do
      header = <<~HTTP.gsub("\n", crlf)
        HTTP/1.0 200 OK
        Content-Type: text/plain
        Content-Length: 5
        Connection: close

      HTTP
      body = 'Hello'
      expected = header + body

      response = Pigeon::Response.new(
        http_version: 'HTTP/1.0',
        status_code: 200,
        reason_phrase: 'OK',
        content_type: 'text/plain',
        body: 'Hello'
      )

      assert_equal expected, response.to_http
    end
  end

  describe '.parse' do
    describe 'with a valid response' do
      it 'extracts the status, content type, and body' do
        header = <<~HTTP.gsub("\n", crlf)
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

      it 'preserves multiword reason phrases' do
        header = <<~HTTP.gsub("\n", crlf)
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

      it 'preserves CRLF within the body' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 12
          Connection: close

        HTTP
        body = "Hello\r\nWorld"
        response = Pigeon::Response.parse(header + body)

        assert_equal "Hello\r\nWorld", response.body
      end

      it 'preserves the HTTP version' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.0 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        response = Pigeon::Response.parse(raw_response)

        assert_equal 'HTTP/1.0', response.http_version
      end
    end

    describe 'with an invalid status line' do
      it 'rejects a status code with fewer than three digits' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 20 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects a status code with more than three digits' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 2000 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects a nonnumeric status code' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 abc OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects an invalid HTTP version' do
        header = <<~HTTP.gsub("\n", crlf)
          INVALID 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects an HTTP version without a minor number' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end
    end

    describe 'with invalid headers' do
      it 'rejects header lines without a colon' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close
          Invalid-Header

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects empty field names' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close
          : value

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end

      it 'rejects field names containing spaces' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close
          Invalid Header: value

        HTTP
        body = 'Hello'
        raw_response = header + body

        assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end
      end
    end
  end
end
