#!/usr/bin/env ruby

require 'contracts'
require 'cztop'
require 'pry'

# Client to communicate with the game server
class Client
  include ::Contracts::Core
  include ::Contracts::Builtin
  PROTOCOL = 'GameProtocol/1.0'.freeze

  Contract KeywordArgs => Client
  def initialize(**options)
    @options = options
    self
  end

  Contract None => String
  def role
    @options.fetch(:role) { 'actors' }
  end

  Contract None => Maybe[String]
  def join!
    _, response, token = request :join, role
    token if response == 'WELCOME'
  end

  Contract None => Maybe[String]
  def token
    @token ||= join!
  end

  def attack!(direction)
    request :attack, token, direction
  end

  def shoot!(direction)
    request :shoot, token, direction
  end

  def feel(direction)
    request :feel, token, direction
  end

  def spotlight(direction)
    request :spotlight, token, direction
  end

  def move!(direction, distance = 1)
    request :move, token, direction, distance
  end

  def list(role)
    request :list, role
  end

  Contract Args[RespondTo[:to_s]] => ArrayOf[String]
  def request(*message)
    socket << [PROTOCOL, *message.map(&:to_s)]
    response
  end

  private

  Contract None => String
  def address
    @address ||= @options.fetch(:address) { '127.0.0.1' }
  end

  Contract None => Num
  def port
    @port ||= @options.fetch(:port) { 5555 }.to_i
  end

  Contract None => ::CZTop::Socket
  def socket
    @socket ||= ::CZTop::Socket::REQ.new ">tcp://#{address}:#{port}"
  end

  Contract None => ArrayOf[String]
  def response
    socket.receive.to_a
  end
end

client = Client.new

pry
