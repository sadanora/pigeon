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

  request = Pigeon::Request.parse(raw_request)
  puts "Method: #{request.method}"
  puts "Target: #{request.target}"
  puts "Host: #{request.host}"

  response = Pigeon::Response.new(
    status_code: 200,
    reason_phrase: 'OK',
    content_type: 'text/plain',
    body: 'Hello'
  )
  socket.write(response.to_http)
ensure
  socket.close
  server.close
end
