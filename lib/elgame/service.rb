#!/usr/bin/env ruby

require 'contracts'
require 'cztop'
require_relative 'service/registry/client'

module ElGame
  class Service
    include ::Contracts::Core
    include ::Contracts::Builtin

    Contract KeywordArgs => Service
    def initialize(**options)
      @options = options
      self
    end

    Contract None => Any
    def listen
      registry.register! provides, socket.last_endpoint
      loop { reply handle request }
    end

    Contract None => ::CZTop::Message
    def send_hugz
      ::CZTop::Message.new << 'Service/1.0' << 'HUGZ'
    end

    Contract None => ::CZTop::Message
    def protocols
      message = ::CZTop::Message.new << 'Service/1.0' << 'PROTOCOLS'

      (['Service/1.0'] + [speaks]).flatten.compact.reduce(message, :<<)
    end

    Contract None => ::CZTop::Message
    def commands
      message = ::CZTop::Message.new << 'Service/1.0' << 'COMMANDS'

      (%w(SEND-HUGZ PROTOCOLS COMMANDS DESCRIBE) + [provides])
        .flatten.compact.map(&:upcase).reduce(message, :<<)
    end

    Contract RespondTo[:to_sym] => ::CZTop::Message
    def describe(command)
      message = ::CZTop::Message.new << 'Service/1.0' << 'DESCRIPTION'

      command = command.downcase.tr('-', '_')
      method = method original(command) || command.to_sym
      [method.arity, method.parameters.map(&:last)]
        .flatten.map(&:to_s).reduce(message, :<<)
    end

    private

    # Contract None => Registry::Client
    def registry
      @registry ||= ::ElGame::Service::Registry::Client.new
    end

    Contract None => String
    def address
      @address ||= @options.fetch(:address) { '0.0.0.0' }
    end

    Contract None => Or[Num, '*']
    def port
      @port ||= @options.fetch(:port) { '*' }
    end

    Contract None => ::CZTop::Socket
    def socket
      @socket ||= ::CZTop::Socket::REP.new "@tcp://#{address}:#{port}"
    end

    Contract None => Maybe[String]
    def speaks
      nil
    end

    Contract RespondTo[:to_s] => Bool
    def speaks?(protocol)
      [speaks, 'Service/1.0'].compact.any? { |p| protocol.to_s.casecmp(p).zero? }
    end

    Contract None => Maybe[String]
    def provides
      nil
    end

    Contract RespondTo[:to_s] => Bool
    def provides?(service)
      (commands.to_a.drop(2) + [provides])
        .flatten
        .compact
        .map { |s| s.tr('-', '_') }
        .any? { |s| service.to_s.casecmp(s).zero? }
    end

    Contract RespondTo[:to_s] => Maybe[Symbol]
    def original(command)
      methods.find do |m|
        m.to_s.start_with? "__contracts_ruby_original_#{command}_"
      end
    end

    Contract CZTop::Message => ::CZTop::Message
    def handle(request)
      return error 'I expected more than that...' if request.size < 2
      return error "I speak #{speaks}" unless speaks? request.pop
      command = request.pop.downcase.tr('-', '_')
      return error "I provide #{provides}" unless provides? command
      send command, *request.to_a
    end

    Contract None => ::CZTop::Message
    def message
      ::CZTop::Message.new << speaks
    end

    Contract ::CZTop::Message => ::CZTop::Socket
    def reply(message)
      socket << message.tap { |m| puts "< #{m}" }
    end

    Contract RespondTo[:to_s] => ::CZTop::Message
    def error(context = '')
      message << 'WTF' << context.to_s
    end

    Contract None => ::CZTop::Message
    def request
      socket.receive.tap { |m| puts "> #{m}" }
    end
  end
end
