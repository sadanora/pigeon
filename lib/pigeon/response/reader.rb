# frozen_string_literal: true

module Pigeon
  class Response::Reader
    def initialize(io)
      @io = io
    end

    def read
      head = read_head
      parsed_head = Response::Parser.parse_head(head)
      body = read_body(parsed_head)

      Response.new(head: parsed_head, body:)
    end

    private

    # Reads through the empty line, leaving the body unread.
    #
    #   @io = StringIO.new("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nHello")
    #   read_head   # => "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n"
    #   @io.read(5) # => "Hello"
    def read_head
      # `first` stops enumeration once the header group is complete.
      lines = @io.each_line.slice_after { |line| line == Pigeon::CRLF }.first
      head = lines&.join || ''

      raise Pigeon::ParseError, 'Empty response' if head.empty?
      raise Pigeon::ParseError, 'Missing header terminator' unless head.end_with?(Pigeon::CRLF * 2)

      head
    end

    def read_body(parsed_head)
      return '' if parsed_head.bodyless?

      raise Pigeon::ParseError, 'Transfer-Encoding is not supported by read' if parsed_head.transfer_encoding?

      content_length = parsed_head.content_length
      raise Pigeon::ParseError, 'Content-Length is required by read' if content_length.nil?

      body = @io.read(content_length) || ''
      raise Pigeon::ParseError, 'Body is shorter than Content-Length' if body.bytesize < content_length

      body
    end
  end
end
