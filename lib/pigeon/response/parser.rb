# frozen_string_literal: true

module Pigeon
  module Response::Parser
    extend self

    TOKEN_PATTERN = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
    STATUS_CODE_PATTERN = /\A[0-9]{3}\z/
    CONTENT_LENGTH_PATTERN = /\A[0-9]+\z/
    HTTP_VERSION_PATTERN = %r{\AHTTP/[0-9]+\.[0-9]+\z}

    def parse(raw_response)
      head, body = split_message(raw_response)
      parsed_head = parse_head(head)
      validate_body_length(body, parsed_head)

      Response.new(head: parsed_head, body:)
    end

    # Parses the status line and headers, including the terminating empty line.
    def parse_head(head)
      validate_response_presence(head)
      raise Pigeon::ParseError, 'Missing header terminator' unless head.end_with?(Pigeon::CRLF * 2)

      status_line, *header_lines = head.split(Pigeon::CRLF)
      http_version, status_code, reason_phrase = parse_status_line(status_line)
      headers = parse_headers(header_lines)

      Response::Head.new(
        http_version:,
        status_code:,
        reason_phrase:,
        headers:,
        content_length: parse_content_length(headers)
      )
    end

    private

    def split_message(raw_response)
      head, separator, body = raw_response.partition(Pigeon::CRLF * 2)

      [head + separator, body]
    end

    def validate_response_presence(raw_response)
      raise Pigeon::ParseError, 'Empty response' if raw_response.empty?
    end

    def parse_status_line(status_line)
      http_version, status_code, reason_phrase = status_line.split(' ', 3)
      validate_http_version(http_version)
      validate_status_code(status_code)

      [http_version, Integer(status_code, 10), reason_phrase]
    end

    def validate_http_version(http_version)
      return if HTTP_VERSION_PATTERN.match?(http_version)

      raise Pigeon::ParseError, 'Invalid HTTP version'
    end

    def validate_status_code(status_code)
      return if STATUS_CODE_PATTERN.match?(status_code)

      raise Pigeon::ParseError, 'Invalid Status Code'
    end

    def parse_headers(header_lines)
      header_lines.map do |line|
        name, separator, value = line.partition(':')
        if name.empty?
          raise Pigeon::ParseError, 'Header must have a field name'
        elsif separator.empty?
          raise Pigeon::ParseError, 'Header line must contain a colon'
        elsif !TOKEN_PATTERN.match?(name)
          raise Pigeon::ParseError, 'Header field name must be a token'
        end

        [name.downcase, value.strip]
      end
    end

    def parse_content_length(headers)
      value = headers.find { |name, _value| name == 'content-length' }&.last
      return nil if value.nil?

      validate_content_length(value)

      Integer(value, 10)
    end

    def validate_content_length(value)
      return if CONTENT_LENGTH_PATTERN.match?(value)

      raise Pigeon::ParseError, 'Invalid Content-Length'
    end

    def validate_body_length(body, parsed_head)
      return unless parsed_head.status_code == 200

      content_length = parsed_head.content_length
      return if content_length.nil?
      return if parsed_head.transfer_encoding?
      return if body.bytesize >= content_length

      raise Pigeon::ParseError, 'Body is shorter than Content-Length'
    end
  end
end
