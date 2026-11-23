# frozen_string_literal: true

require 'socket'
require_relative '../lib/pigeon'

request = Pigeon::Request.new(
  method: 'GET',
  target: '/',
  host: 'localhost:8080'
)

socket = TCPSocket.new('127.0.0.1', 8080)

begin
  socket.write(request.to_http)

  response = Pigeon::Response.read(socket)
  puts "Status: #{response.status_code} #{response.reason_phrase}"
  puts "Content-Type: #{response.content_type}"
  puts response.body
ensure
  socket.close
end
