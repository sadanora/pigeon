# frozen_string_literal: true

module Pigeon
  class Request
    attr_reader :method, :target, :http_version, :host

    REQUEST_LINE_COMPONENTS = %w[
      Method
      Request-URI
      HTTP-Version
    ].freeze
    TOKEN_PATTERN = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
    HTTP_VERSION_PATTERN = %r{\AHTTP/[0-9]+\.[0-9]+\z}

    def self.parse(raw_request)
      request_line, *header_lines = raw_request.split(Pigeon::CRLF)
      method, target, http_version = parse_request_line(request_line)
      validate_http_version(http_version)
      headers = parse_headers(header_lines)
      host = fetch_host(headers)

      new(method:, target:, http_version:, host:)
    end

    def self.parse_request_line(request_line)
      parts = request_line.split

      unless parts.size == REQUEST_LINE_COMPONENTS.size
        raise Pigeon::ParseError, "Request line must contain #{REQUEST_LINE_COMPONENTS.join(', ')}"
      end

      parts
    end
    private_class_method :parse_request_line

    def self.parse_headers(header_lines)
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
    private_class_method :parse_headers

    def self.fetch_host(headers)
      host_header = headers.find { |name, _value| name == 'host' }

      raise Pigeon::ParseError, 'Header must contain host' unless host_header

      host_header.last
    end
    private_class_method :fetch_host

    def self.validate_http_version(http_version)
      return if HTTP_VERSION_PATTERN.match?(http_version)

      raise Pigeon::ParseError, 'Invalid HTTP version'
    end
    private_class_method :validate_http_version

    def initialize(method:, target:, http_version: 'HTTP/1.1', host:)
      @method = method
      @target = target
      @http_version = http_version
      @host = host
    end

    # ref: https://www.rfc-editor.org/rfc/rfc2616.html#section-4.1
    # Message Types
    # generic-message = start-line
    #                  *(message-header CRLF)
    #                  CRLF
    #                  [ message-body ]
    #
    # Request-Line = Method SP Request-URI SP HTTP-Version CRLF
    # ref: https://www.rfc-editor.org/rfc/rfc2616.html#section-5.1
    def to_http
      <<~HTTP.gsub("\n", Pigeon::CRLF)
        #{@method} #{@target} #{@http_version}
        Host: #{@host}
        Connection: close

      HTTP
    end
  end
end
