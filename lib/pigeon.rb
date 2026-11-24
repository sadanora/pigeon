# frozen_string_literal: true

module Pigeon
  CRLF = "\r\n"
end

require_relative 'pigeon/parse_error'
require_relative 'pigeon/request'
require_relative 'pigeon/response'
require_relative 'pigeon/response/head'
require_relative 'pigeon/response/parser'
require_relative 'pigeon/response/reader'
