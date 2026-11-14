# frozen_string_literal: true

require 'socket'

server = TCPServer.new('127.0.0.1', 8080)
puts 'Waiting on 127.0.0.1:8080...'

client = server.accept

begin
  while (line = client.gets)
    print line
    break if line == "\r\n"
  end
ensure
  client.close
  server.close
end
