# frozen_string_literal: true

module Pigeon
  class Response
    attr_reader :http_version, :status_code, :reason_phrase, :content_type, :body

    STATUS_CODE_PATTERN = /\A[0-9]{3}\z/
    HTTP_VERSION_PATTERN = /\AHTTP\/[0-9]+\.[0-9]+\z/

    def self.parse(raw_response)
      head, body = raw_response.split(Pigeon::CRLF * 2, 2)
      status_line, *header_lines = head.split(Pigeon::CRLF)
      http_version, status_code, reason_phrase = parse_status_line(status_line)
      headers = parse_headers(header_lines)
      content_type = headers.find { |name, _value| name == 'content-type' }.last

      new(http_version:, status_code:, reason_phrase:, content_type:, body:)
    end

    def self.parse_status_line(status_line)
      http_version, status_code, reason_phrase = status_line.split(' ', 3)
      validate_http_version(http_version)
      validate_status_code(status_code)

      [http_version, Integer(status_code, 10), reason_phrase]
    end
    private_class_method :parse_status_line

    def self.parse_headers(header_lines)
      header_lines.map do |line|
        name, value = line.split(':', 2)
        [name.downcase, value.strip]
      end
    end
    private_class_method :parse_headers

    def self.validate_http_version(http_version)
      unless HTTP_VERSION_PATTERN.match?(http_version)
        raise Pigeon::ParseError, "Invalid HTTP version"
      end
    end
    private_class_method :validate_http_version

    def self.validate_status_code(status_code)
      unless STATUS_CODE_PATTERN.match?(status_code)
        raise Pigeon::ParseError, "Invalid Status Code"
      end
    end
    private_class_method :validate_status_code

    def initialize(
      http_version: 'HTTP/1.1',
      status_code:,
      reason_phrase:,
      content_type:,
      body:
    )
      @http_version = http_version
      @status_code = status_code
      @reason_phrase = reason_phrase
      @content_type = content_type
      @body = body
    end

    # ref: https://www.rfc-editor.org/info/rfc2616/#section-6
    # After receiving and interpreting a request message, a server responds with an HTTP response message.
    # Response      = Status-Line               ; Section 6.1
    #                 *(( general-header        ; Section 4.5
    #                   | response-header       ; Section 6.2
    #                   | entity-header ) CRLF) ; Section 7.1
    #                 CRLF
    #                 [ message-body ]          ; Section 7.2
    def to_http
      header = <<~HTTP.gsub("\n", Pigeon::CRLF)
        #{@http_version} #{@status_code} #{@reason_phrase}
        Content-Type: #{@content_type}
        Content-Length: #{@body.bytesize}
        Connection: close

      HTTP
      header + @body
    end
  end
end
