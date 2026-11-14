# frozen_string_literal: true

require 'socket'
require_relative '../lib/pigeon'

server = TCPServer.new('127.0.0.1', 8080)
puts 'Waiting on 127.0.0.1:8080...'

client = server.accept
begin
  while (line = client.gets)
    print line
    break if line == "\r\n"
  end

  response = Pigeon::Response.new(
    content_type: 'text/plain',
    body: 'Hello'
  )
  client.write(response.to_http)
ensure
  client.close
  server.close
end
