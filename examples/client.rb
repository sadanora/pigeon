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
  print socket.read
ensure
  socket.close
end
