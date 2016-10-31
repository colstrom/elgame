#!/usr/bin/env ruby

require 'cztop'
require 'nanomsg'

abort "Usage: #{$PROGRAM_NAME} <nanomsg-bind-address> <zeromq-connect-address>" unless ARGV.size == 2

nano = NanoMsg::RepSocket.new
nano.bind ARGV.first

zero = CZTop::Socket::REQ.new ARGV.last

STDERR.puts "Forwarding nanomsg requests on #{ARGV.first} to zeromq server at #{ARGV.last}"

loop do
  request = nano.recv.split
  puts "REQ #{request}"
  zero << request

  response = zero.receive.to_a.join(' ')
  puts "REP #{response}"
  nano.send response
end
