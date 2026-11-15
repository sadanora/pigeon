# frozen_string_literal: true

module Pigeon
  class Response
    attr_reader :status_code, :reason_phrase, :content_type, :body

    def self.parse(raw_response)
      head, body = raw_response.split(Pigeon::CRLF * 2, 2)
      status_line, *header_lines = head.split(Pigeon::CRLF)
      _, status_code, reason_phrase = status_line.split(' ', 3)
      headers = header_lines.map do |line|
        name, value = line.split(':', 2)
        [name.downcase, value.strip]
      end
      content_type = headers.find { |name, _value| name == 'content-type' }.last

      new(status_code: Integer(status_code, 10), reason_phrase:, content_type:, body:)
    end

    def initialize(
      status_code:,
      reason_phrase:,
      content_type:,
      body:
    )
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
        HTTP/1.1 #{@status_code} #{@reason_phrase}
        Content-Type: #{@content_type}
        Content-Length: #{@body.bytesize}
        Connection: close

      HTTP
      header + @body
    end
  end
end
