# frozen_string_literal: true

module Pigeon
  class Response
    attr_reader :head, :body

    def initialize(head:, body:)
      @head = head
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
        "#{@head.http_version} #{@head.status_code} #{@head.reason_phrase}",
        ("Content-Type: #{@head.content_type}" unless @head.content_type.nil?),
        "Content-Length: #{@body.bytesize}",
        'Connection: close'
      ].compact

      headers.join(Pigeon::CRLF) + (Pigeon::CRLF * 2) + @body
    end

    def self.read(io)
      Reader.new(io).read
    end

    def self.parse(raw_response)
      Parser.parse(raw_response)
    end
  end
end
