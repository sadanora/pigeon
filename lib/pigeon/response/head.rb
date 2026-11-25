# frozen_string_literal: true

module Pigeon
  class Response::Head
    attr_reader :http_version, :status_code, :reason_phrase, :headers, :content_length

    BODY_FORBIDDEN_STATUS_CODES = [204, 304].freeze

    def initialize(http_version: 'HTTP/1.1', status_code:, reason_phrase:, headers: [], content_length: nil)
      @http_version = http_version
      @status_code = status_code
      @reason_phrase = reason_phrase
      @headers = headers
      @content_length = content_length
    end

    def content_type
      @headers.find { |name, _value| name == 'content-type' }&.last
    end

    def bodyless?
      BODY_FORBIDDEN_STATUS_CODES.include?(@status_code)
    end

    def transfer_encoding?
      @headers.any? { |name, _value| name == 'transfer-encoding' }
    end
  end
end
