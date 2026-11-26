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

      it 'reads the body when the reason phrase contains 204' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 404 Error 204
          Content-Type: text/plain
          Content-Length: 5

        HTTP
        io = StringIO.new("#{header}Hello")

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

      it 'stops at the header terminator for a 204 response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 204 No Content

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io)

        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'stops at the header terminator for a 204 response with headers' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 204 No Content
          Date: Tue, 24 Nov 2026 00:00:00 GMT

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io)

        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'stops at the header terminator for a 304 response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 304 Not Modified
          Date: Wed, 25 Nov 2026 00:00:00 GMT

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io)

        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'does not use Content-Length as the body length of a 304 response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 304 Not Modified
          Date: Wed, 25 Nov 2026 00:00:00 GMT
          Content-Length: 5

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io)

        assert_equal 5, response.head.content_length
        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'leaves the following response unread after a 100 response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 100 Continue

        HTTP
        following_header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5

        HTTP
        following_response = "#{following_header}Hello"
        io = StringIO.new(header + following_response)

        response = Pigeon::Response.read(io)

        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_response, io.read
      end

      it 'stops at the header terminator for a 199 response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 199 Informational

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io)

        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'does not read a body for a HEAD response with Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io, request_method: 'HEAD')

        assert_equal 5, response.head.content_length
        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'does not require Content-Length for a HEAD response' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain

        HTTP
        following_data = 'unread data'
        io = StringIO.new(header + following_data)

        response = Pigeon::Response.read(io, request_method: 'HEAD')

        assert_nil response.head.content_length
        assert_equal '', response.body
        assert_equal header.bytesize, io.pos
        assert_equal following_data, io.read
      end

      it 'reads the body when the request method is GET' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: 5

        HTTP
        body = 'Hello'
        following_data = 'unread data'
        io = StringIO.new(header + body + following_data)

        response = Pigeon::Response.read(io, request_method: 'GET')

        assert_equal 'Hello', response.body
        assert_equal header.bytesize + body.bytesize, io.pos
        assert_equal following_data, io.read
      end
    end

    describe 'with invalid headers' do
      it 'rejects a nonnumeric Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Content-Length: abc

        HTTP
        io = StringIO.new("#{header}Hello")

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Invalid Content-Length', error.message
      end
    end

    describe 'with unsupported message framing' do
      it 'rejects a 200 response without headers' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK

        HTTP
        io = StringIO.new("#{header}Hello")

        error = assert_raises(Pigeon::ParseError) do
          Pigeon::Response.read(io)
        end

        assert_equal 'Content-Length is required by read', error.message
      end

      it 'rejects a response without Content-Length' do
        header = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          Content-Type: text/plain
          Connection: close

        HTTP
        io = StringIO.new("#{header}Hello")

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
        io = StringIO.new("#{header}Hello")

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

      head = Pigeon::Response::Head.new(
        status_code: 200,
        reason_phrase: 'OK',
        headers: [['content-type', 'text/plain']]
      )
      response = Pigeon::Response.new(head:, body: 'Hello')

      assert_equal expected, response.to_http
    end

    it 'omits the body for HEAD while preserving the GET Content-Length' do
      expected = <<~HTTP.gsub("\n", crlf)
        HTTP/1.1 200 OK
        Content-Type: text/plain
        Content-Length: 5
        Connection: close

      HTTP
      head = Pigeon::Response::Head.new(
        status_code: 200,
        reason_phrase: 'OK',
        headers: [['content-type', 'text/plain']]
      )
      response = Pigeon::Response.new(head:, body: 'Hello')

      assert_equal expected, response.to_http(request_method: 'HEAD')
      assert_equal 'Hello', response.body
    end

    it 'includes the body when the request method is GET' do
      header = <<~HTTP.gsub("\n", crlf)
        HTTP/1.1 200 OK
        Content-Type: text/plain
        Content-Length: 5
        Connection: close

      HTTP
      body = 'Hello'
      expected = header + body
      head = Pigeon::Response::Head.new(
        status_code: 200,
        reason_phrase: 'OK',
        headers: [['content-type', 'text/plain']]
      )
      response = Pigeon::Response.new(head:, body:)

      assert_equal expected, response.to_http(request_method: 'GET')
    end

    describe 'with a status code that forbids a body' do
      it 'omits the body and Content-Length for a 100 response' do
        expected = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 100 Continue
          Connection: close

        HTTP
        head = Pigeon::Response::Head.new(status_code: 100, reason_phrase: 'Continue')
        response = Pigeon::Response.new(head:, body: 'Hello')

        assert_equal expected, response.to_http
      end

      it 'omits the body and Content-Length for a 199 response' do
        expected = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 199 Informational
          Connection: close

        HTTP
        head = Pigeon::Response::Head.new(status_code: 199, reason_phrase: 'Informational')
        response = Pigeon::Response.new(head:, body: 'Hello')

        assert_equal expected, response.to_http
      end

      it 'omits the body and Content-Length for a 204 response' do
        expected = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 204 No Content
          Connection: close

        HTTP
        head = Pigeon::Response::Head.new(status_code: 204, reason_phrase: 'No Content')
        response = Pigeon::Response.new(head:, body: 'Hello')

        assert_equal expected, response.to_http
        assert_equal 'Hello', response.body
      end

      it 'omits the body and Content-Length for a 304 response' do
        expected = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 304 Not Modified
          Connection: close

        HTTP
        head = Pigeon::Response::Head.new(status_code: 304, reason_phrase: 'Not Modified')
        response = Pigeon::Response.new(head:, body: 'Hello')

        assert_equal expected, response.to_http
      end
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

      head = Pigeon::Response::Head.new(
        http_version: 'HTTP/1.0',
        status_code: 200,
        reason_phrase: 'OK',
        headers: [['content-type', 'text/plain']]
      )
      response = Pigeon::Response.new(head:, body: 'Hello')

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

      head = Pigeon::Response::Head.new(
        http_version: 'HTTP/1.1',
        status_code: 200,
        reason_phrase: 'OK'
      )
      response = Pigeon::Response.new(head:, body: 'Hello')

      assert_equal expected, response.to_http
    end
  end

  describe '.parse' do
    describe 'with a valid response' do
      it 'preserves repeated response headers in their received order' do
        raw_response = <<~HTTP.gsub("\n", crlf)
          HTTP/1.1 200 OK
          X-Note: first
          x-note: second

        HTTP

        response = Pigeon::Response.parse(raw_response)

        assert_equal [%w[x-note first], %w[x-note second]], response.head.headers
      end

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

        assert_equal 5, response.head.content_length
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

        assert_nil response.head.content_type
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

        assert_nil response.head.content_length
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

        assert_equal 0, response.head.content_length
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
        assert_equal 200, response.head.status_code
        assert_equal 'OK', response.head.reason_phrase
        assert_equal 'text/plain', response.head.content_type
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

        assert_equal 404, response.head.status_code
        assert_equal 'Not Found', response.head.reason_phrase
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

        assert_equal 'HTTP/1.0', response.head.http_version
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
