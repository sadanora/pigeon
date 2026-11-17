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
end
