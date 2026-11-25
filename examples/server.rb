# frozen_string_literal: true

require 'socket'
require_relative '../lib/pigeon'

server = TCPServer.new('127.0.0.1', 8080)
puts 'Waiting on 127.0.0.1:8080...'

socket = server.accept
raw_request = +''
begin
  while (line = socket.gets)
    raw_request << line
    break if line == "\r\n"
  end

  begin
    request = Pigeon::Request.parse(raw_request)
    puts "Method: #{request.method}"
    puts "Target: #{request.target}"
    puts "Host: #{request.host}"

    head = Pigeon::Response::Head.new(
      status_code: 200,
      reason_phrase: 'OK',
      headers: [['content-type', 'text/plain']]
    )
    response = Pigeon::Response.new(head:, body: 'Hello')
  rescue Pigeon::ParseError => e
    warn e.message

    head = Pigeon::Response::Head.new(
      status_code: 400,
      reason_phrase: 'Bad Request',
      headers: [['content-type', 'text/plain']]
    )
    response = Pigeon::Response.new(head:, body: 'Bad Request')
  end

  socket.write(response.to_http(request_method: request&.method))
  puts 'Response sent. Press Enter to close the connection.'
  $stdin.gets
ensure
  socket.close
  server.close
end
