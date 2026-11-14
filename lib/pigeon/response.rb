# frozen_string_literal: true

module Pigeon
  class Response
    def initialize(content_type:, body:)
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
        HTTP/1.1 200 OK
        Content-Type: #{@content_type}
        Content-Length: #{@body.bytesize}
        Connection: close

      HTTP
      header + @body
    end
  end
end
