# frozen_string_literal: true

require_relative 'test_helper'
require 'pigeon'

describe Pigeon::Request do
  let(:crlf) { "\r\n" }

  describe '#to_http' do
    it 'serializes a GET request' do
      request = Pigeon::Request.new(
        method: 'GET',
        target: '/',
        host: 'localhost:8080'
      )

      expected = <<~HTTP.gsub("\n", crlf)
        GET / HTTP/1.1
        Host: localhost:8080
        Connection: close

      HTTP

      assert_equal expected, request.to_http
    end

    it 'preserves the HTTP version' do
      request = Pigeon::Request.new(
        method: 'GET',
        target: '/',
        http_version: 'HTTP/1.0',
        host: 'localhost:8080'
      )

      expected = <<~HTTP.gsub("\n", crlf)
        GET / HTTP/1.0
        Host: localhost:8080
        Connection: close

      HTTP

      assert_equal expected, request.to_http
    end
  end

  describe '.parse' do
    describe 'with a valid request' do
      it 'extracts the method, target, and host' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          Host: localhost:8080
          Connection: close

        HTTP

        request = Pigeon::Request.parse(raw_request)

        assert_equal 'GET', request.method
        assert_equal '/', request.target
        assert_equal 'localhost:8080', request.host
      end

      it 'accepts mixed-case Host header names' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          hOsT: localhost:8080
          Connection: close

        HTTP

        request = Pigeon::Request.parse(raw_request)

        assert_equal 'localhost:8080', request.host
      end

      it 'finds Host after Connection' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET /hello HTTP/1.1
          Connection: close
          Host: localhost:8080

        HTTP

        request = Pigeon::Request.parse(raw_request)

        assert_equal 'GET', request.method
        assert_equal 'localhost:8080', request.host
        assert_equal '/hello', request.target
      end

      it 'preserves the HTTP version' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.0
          Host: localhost:8080

        HTTP

        request = Pigeon::Request.parse(raw_request)

        assert_equal 'HTTP/1.0', request.http_version
      end
    end

    describe 'with an invalid request line' do
      it 'rejects extra components' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1 extra
          Host: localhost:8080

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects missing components' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET /
          Host: localhost:8080

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects invalid HTTP version' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / INVALID
          HOST: localhost:8080

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects an HTTP version without a minor number' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1
          Host: localhost:8080

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end
    end

    describe 'with invalid headers' do
      it 'rejects field names containing spaces' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          Host: localhost:8080
          Invalid Header: value

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects empty field names' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          Host: localhost:8080
          : value

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects header lines without a colon' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          Host: localhost:8080
          Invalid-Header

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end

      it 'rejects a missing Host header' do
        raw_request = <<~HTTP.gsub("\n", crlf)
          GET / HTTP/1.1
          Connection: close

        HTTP

        assert_raises(Pigeon::ParseError) do
          Pigeon::Request.parse(raw_request)
        end
      end
    end
  end
end
