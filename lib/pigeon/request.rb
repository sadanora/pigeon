# frozen_string_literal: true

module Pigeon
  class Request
    attr_reader :method, :target, :host

    def self.parse(raw_request)
      request_line, *header_lines = raw_request.split(Pigeon::CRLF)
      method, target, = request_line.split
      headers = header_lines.map do |line|
        name, value = line.split(':', 2)
        [name.downcase, value.strip]
      end
      host = headers.find { |name, _value| name == 'host' }.last

      new(method:, target:, host:)
    end

    def initialize(method:, target:, host:)
      @method = method
      @target = target
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
        #{@method} #{@target} HTTP/1.1
        Host: #{@host}
        Connection: close

      HTTP
    end
  end
end
