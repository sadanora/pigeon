# frozen_string_literal: true

require_relative '../test_helper'
require 'pigeon'

describe Pigeon::Response::Parser do
  let(:crlf) { "\r\n" }

  describe '.parse_head' do
    it 'returns the parsed status and headers without a body' do
      head = <<~HTTP.gsub("\n", crlf)
        HTTP/1.1 200 OK
        Content-Type: text/plain
        Content-Length: 5

      HTTP
      parsed_head = Pigeon::Response::Parser.parse_head(head)

      assert_equal 'HTTP/1.1', parsed_head.http_version
      assert_equal 200, parsed_head.status_code
      assert_equal 'OK', parsed_head.reason_phrase
      assert_equal [['content-type', 'text/plain'], ['content-length', '5']], parsed_head.headers
      assert_equal 'text/plain', parsed_head.content_type
      assert_equal 5, parsed_head.content_length
    end

    it 'preserves repeated header fields in their received order' do
      head = <<~HTTP.gsub("\n", crlf)
        HTTP/1.1 200 OK
        X-Note: first
        x-note: second

      HTTP

      parsed_head = Pigeon::Response::Parser.parse_head(head)

      assert_equal [%w[x-note first], %w[x-note second]], parsed_head.headers
    end
  end
end
