# frozen_string_literal: true

module Pigeon
  class Response
    attr_reader :http_version, :status_code, :reason_phrase, :content_type, :content_length, :body

    TOKEN_PATTERN = /\A[!#$%&'*+\-.^_`|~0-9A-Za-z]+\z/
    STATUS_CODE_PATTERN = /\A[0-9]{3}\z/
    CONTENT_LENGTH_PATTERN = /\A[0-9]+\z/
    HTTP_VERSION_PATTERN = %r{\AHTTP/[0-9]+\.[0-9]+\z}

    def self.read(io)
      head = read_head(io)
      _status_line, *header_lines = head.split(Pigeon::CRLF)
      headers = parse_headers(header_lines)
      body = read_body(io, headers)

      parse(head + body)
    end

    # Reads through the empty line, leaving the body unread.
    #
    #   io = StringIO.new("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
    #   read_head(io) # => "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
    #   io.read(5)    # => "Hello"
    def self.read_head(io)
      # `first` stops enumeration once the header group is complete.
      lines = io.each_line.slice_after { |line| line == Pigeon::CRLF }.first
      head = lines&.join || ''

      validate_response_presence(head)
      raise Pigeon::ParseError, 'Missing header terminator' unless head.end_with?(Pigeon::CRLF * 2)

      head
    end
    private_class_method :read_head

    def self.read_body(io, headers)
      if headers.any? { |name, _value| name == 'transfer-encoding' }
        raise Pigeon::ParseError, 'Transfer-Encoding is not supported by read'
      end

      content_length = parse_content_length(headers)
      raise Pigeon::ParseError, 'Content-Length is required by read' if content_length.nil?

      body = io.read(content_length) || ''
      raise Pigeon::ParseError, 'Body is shorter than Content-Length' if body.bytesize < content_length

      body
    end
    private_class_method :read_body

    def self.parse(raw_response)
      validate_response_presence(raw_response)

      head, body = split_message(raw_response)
      status_line, *header_lines = head.split(Pigeon::CRLF)
      http_version, status_code, reason_phrase = parse_status_line(status_line)
      headers = parse_headers(header_lines)
      content_type = headers.find { |name, _value| name == 'content-type' }&.last
      content_length = parse_content_length(headers)
      validate_body_length(body, content_length, status_code:, headers:)

      new(
        http_version:,
        status_code:,
        reason_phrase:,
        content_type:,
        content_length:,
        body:
      )
    end

    def self.split_message(raw_response)
      head, separator, body = raw_response.partition(Pigeon::CRLF * 2)

      raise Pigeon::ParseError, 'Missing header terminator' if separator.empty?

      [head, body]
    end
    private_class_method :split_message

    def self.validate_response_presence(raw_response)
      raise Pigeon::ParseError, 'Empty response' if raw_response.empty?
    end
    private_class_method :validate_response_presence

    def self.parse_status_line(status_line)
      http_version, status_code, reason_phrase = status_line.split(' ', 3)
      validate_http_version(http_version)
      validate_status_code(status_code)

      [http_version, Integer(status_code, 10), reason_phrase]
    end
    private_class_method :parse_status_line

    def self.validate_http_version(http_version)
      return if HTTP_VERSION_PATTERN.match?(http_version)

      raise Pigeon::ParseError, 'Invalid HTTP version'
    end
    private_class_method :validate_http_version

    def self.validate_status_code(status_code)
      return if STATUS_CODE_PATTERN.match?(status_code)

      raise Pigeon::ParseError, 'Invalid Status Code'
    end
    private_class_method :validate_status_code

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

    def self.parse_content_length(headers)
      value = headers.find { |name, _value| name == 'content-length' }&.last
      return nil if value.nil?

      validate_content_length(value)

      Integer(value, 10)
    end
    private_class_method :parse_content_length

    def self.validate_content_length(value)
      return if CONTENT_LENGTH_PATTERN.match?(value)

      raise Pigeon::ParseError, 'Invalid Content-Length'
    end
    private_class_method :validate_content_length

    def self.validate_body_length(body, content_length, status_code:, headers:)
      return unless status_code == 200
      return if content_length.nil?
      return if headers.any? { |name, _| name == 'transfer-encoding' }
      return if body.bytesize >= content_length

      raise Pigeon::ParseError, 'Body is shorter than Content-Length'
    end
    private_class_method :validate_body_length

    def initialize(
      http_version: 'HTTP/1.1',
      status_code:,
      reason_phrase:,
      content_type:,
      content_length: nil,
      body:
    )
      @http_version = http_version
      @status_code = status_code
      @reason_phrase = reason_phrase
      @content_type = content_type
      @content_length = content_length
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
      headers = [
        "#{@http_version} #{@status_code} #{@reason_phrase}",
        ("Content-Type: #{@content_type}" unless @content_type.nil?),
        "Content-Length: #{@body.bytesize}",
        'Connection: close'
      ].compact

      headers.join(Pigeon::CRLF) + (Pigeon::CRLF * 2) + @body
    end
  end
end
