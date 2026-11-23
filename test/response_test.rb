# frozen_string_literal: true

require_relative 'test_helper'
require 'pigeon'
require 'stringio'

describe Pigeon::Response do
  let(:crlf) { "\r\n" }

  describe '.read' do
    describe 'with a valid response' do
      it 'reads a Content-Length-framed response from an IO' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5

        HTTP
        body = 'Hello'
        io = StringIO.new(header + body)

        response = Pigeon::Response.read(io)

        assert_equal 'Hello', response.body
      end

      it 'stops reading after the declared number of body bytes' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 15

        HTTP
        body = 'こんにちわ'
        following_data = 'unread data'
        io = StringIO.new(header + body + following_data)

        response = Pigeon::Response.read(io)

        assert_equal 'こんにちわ'.bytes, response.body.bytes
        assert_equal header.bytesize + body.bytesize, io.pos
        assert_equal 'unread data', io.read
      end
    end

    describe 'with invalid headers' do
      it 'rejects a nonnumeric Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: abc

        HTTP
        io = StringIO.new(header + 'Hello')

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Invalid Content-Length', error.message
      end
    end

    describe 'with unsupported message framing' do
      it 'rejects a response without Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Connection: close

        HTTP
        io = StringIO.new(header + 'Hello')

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Content-Length is required by read', error.message
      end

      it 'rejects a response with Transfer-Encoding' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Transfer-Encoding: chunked

        HTTP
        body = <<~HTTP.gsub("\n", crlf)
          5
          Hello
          0

        HTTP
        io = StringIO.new(header + body)

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Transfer-Encoding is not supported by read', error.message
      end
    end

    describe 'with empty input' do
      it 'rejects an empty IO' do
        io = StringIO.new('')

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Empty response', error.message
      end
    end

    describe 'with an incomplete message' do
      it 'rejects a body shorter than the declared Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 6

        HTTP
        io = StringIO.new(header + 'Hello')

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Body is shorter than Content-Length', error.message
      end

      it 'rejects a missing header terminator' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 0
        HTTP
        io = StringIO.new(header)

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Missing header terminator', error.message
      end
    end
  end

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

    it 'serializes without Content-Type' do
      header = <<~HTTP.gsub("\n", crlf)
        HTTP/1.1 200 OK
        Content-Length: 5
        Connection: close

      HTTP
      body = 'Hello'
      expected = header + body

      response = Pigeon::Response.new(
        http_version: 'HTTP/1.1',
        status_code: 200,
        reason_phrase: 'OK',
        content_type: nil,
        body: 'Hello'
      )

      assert_equal expected, response.to_http
    end
  end

  describe '.parse' do
    describe 'with a valid response' do
      it 'extracts Content-Length as an integer' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        response = Pigeon::Response.parse(raw_response)

        assert_equal 5, response.content_length
      end

      it 'accepts a response without Content-Type' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Length: 5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        response = Pigeon::Response.parse(raw_response)

        assert_nil response.content_type
        assert_equal 'Hello', response.body
      end

      it 'does not infer Content-Length from the body when the header is absent' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        response = Pigeon::Response.parse(raw_response)

        assert_nil response.content_length
        assert_equal 'Hello', response.body
      end

      it 'preserves a declared Content-Length of zero' do
        raw_response = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 0
          Connection: close

        HTTP

        response = Pigeon::Response.parse(raw_response)

        assert_equal 0, response.content_length
        assert_equal '', response.body
      end

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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Status Code', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Status Code', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Status Code', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid HTTP version', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid HTTP version', error.message
      end
    end

    describe 'with invalid headers' do
      it 'rejects a nonnumeric Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: abc
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Content-Length', error.message
      end

      it 'rejects a negative Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: -5
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Content-Length', error.message
      end

      it 'rejects an empty Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length:
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Invalid Content-Length', error.message
      end

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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Header line must contain a colon', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Header must have a field name', error.message
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

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Header field name must be a token', error.message
      end
    end

    describe 'with empty input' do
      it 'rejects an empty string' do
        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse('')
        end

        assert_equal 'Empty response', error.message
      end
    end

    describe 'with an incomplete message' do
      it 'rejects a body shorter than the declared Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 6
          Connection: close

        HTTP
        body = 'Hello'
        raw_response = header + body

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Body is shorter than Content-Length', error.message
      end

      it 'rejects a missing header terminator' do
        raw_response = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 0
          Connection: close
        HTTP

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.parse(raw_response)
        end

        assert_equal 'Missing header terminator', error.message
      end
    end
  end
end
