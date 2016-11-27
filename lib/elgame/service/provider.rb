require 'contracts'
require 'cztop'

module ElGame
  module Service
    class Provider
      include ::Contracts::Core
      include ::Contracts::Builtin

      SERVICE_COMMANDS = %w(PROTOCOLS COMMANDS DESCRIBE SEND-HUGZ)

      Command = Struct.new :arity, :parameters

      Contract KeywordArgs[endpoint: String] => Provider
      def initialize(**options)
        @options = options
        self
      end

      def protocols
        @protocols ||= protocols!
      end

      def commands
        @commands ||= commands!
      end

      Contract RespondTo[:to_s] => Maybe[Command]
      def describe(command)
        descriptions[command.to_s.capitalize] ||= describe! command
      end

      Contract None => Bool
      def available?
        socket.writable? && healthy?
      end

      private

      Contract None => HashOf[String, Command]
      def descriptions
        @descriptions ||= {}
      end

      def message(*frames)
        frames.map(&:to_s).reduce ::CZTop::Message.new, :<<
      end

      Contract None => ArrayOf[String]
      def protocols!
        return unless response = request('Service/1.0', 'PROTOCOLS')
        return [] unless response.pop.casecmp('Service/1.0').zero?
        return [] unless response.pop.casecmp('PROTOCOLS').zero?
        response.to_a
      end

      # Contract None => ArrayOf[String]
      def commands!
        return unless response = request('Service/1.0', 'COMMANDS')
        return [] unless response.pop.casecmp('Service/1.0').zero?
        return [] unless response.pop.casecmp('COMMANDS').zero?
        response.to_a
      end

      Contract RespondTo[:to_s] => Command
      def describe!(command)
        return unless response = request('Service/1.0', 'DESCRIBE', command)
        return unless response.pop.casecmp('Service/1.0').zero?
        return unless response.pop.casecmp('DESCRIPTION').zero?
        Command.new response.pop, response.to_a
      end

      Contract None => Maybe[Bool]
      def healthy?
        return unless response = request('Service/1.0', 'SEND-HUGZ')
        return unless response.pop.casecmp('Service/1.0').zero?
        response.pop.casecmp('HUGZ').zero?
      end

      # Contract None => ::CZTop::Message
      def reply
        socket.receive
      end

      # Contract Args[RespondTo[:to_s]] => ::CZTop::Message
      def request(*args)
        socket << message(*args)
        reply
      end

      def endpoint
        @options.fetch(:endpoint)
      end

      # Contract None => ::CZTop::Socket
      def socket
        @socket ||= ::CZTop::Socket::REQ.new ">#{endpoint}"
      end

      def respond_to_missing?(symbol, include_all = false)
        commands.any? { |c| c.casecmp(symbol.to_s).zero? } || super
      end

      def method_missing(symbol, *args, **options)
        return super unless respond_to_missing? symbol

        protocol = options.fetch(:protocol) { "#{symbol}/1.0" }
        socket << (message protocol, symbol, *args)
        response = reply
        response if response.pop.casecmp(protocol).zero?
      end
    end
  end
end
