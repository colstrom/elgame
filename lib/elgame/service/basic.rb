require 'contracts'
require 'cztop'

module ElGame
  module Service
    class Basic
      include ::Contracts::Core
      include ::Contracts::Builtin

      SERVICE_PROTOCOL = 'Service/1.0'.freeze

      Contract KeywordArgs => Basic
      def initialize(**options)
        @options = options
        self
      end

      Contract None => ::CZTop::Message
      def send_hugz
        service_message << 'HUGZ'
      end

      Contract None => ::CZTop::Message
      def protocols
        [
          'PROTOCOLS',
          SERVICE_PROTOCOL,
          (self.class.const_get :PROTOCOL if self.class.const_defined? :PROTOCOL)
        ]
          .compact
          .reduce service_message, :<<
      end

      Contract None => ::CZTop::Message
      def services
        ['SERVICES', *protocols.to_a.drop(2)]
          .map { |service| service.split('/').first }
          .reduce service_message, :<<
      end

      Contract None => ::CZTop::Message
      def commands
        %w(COMMANDS SEND-HUGZ PROTOCOLS COMMANDS DESCRIBE)
          .reduce service_message, :<<
      end

      Contract RespondTo[:to_s] => ::CZTop::Message
      def describe(command)
        command = command.to_s.downcase.tr('-', '_')
        method = method original(command) || command.to_sym
        ['DESCRIPTION', method.arity, method.paraameters.map(&:last)]
          .flatten
          .map(&:to_s)
          .reduce service_message, :<<
      end

      Contract None => Any
      def listen
        loop { reply handle request }
      end

      private

      Contract None => ::CZTop::Message
      def service_message
        ::CZTop::Message.new << SERVICE_PROTOCOL
      end

      Contract RespondTo[:to_s] => Maybe[Symbol]
      def original(command)
        methods.find do |m|
          m.to_s.start_with? "__contracts_ruby_original_#{command}_"
        end
      end

      Contract None => String
      def preferred_protocol
        protocols.to_a.last
      end

      Contract None => String
      def address
        @address ||= @options.fetch(:address) { '0.0.0.0' }
      end

      Contract None => Or[Num, '*']
      def port
        @port ||= @options.fetch(:port) { '*' }
      end

      Contract None => String
      def endpoint
        @endpoint ||= @options.fetch(:endpoint) { "@tcp://#{address}:#{port}" }
      end

      Contract None => ::CZTop::Socket
      def socket
        @socket ||= ::CZTop::Socket::REP.new endpoint
      end

      Contract Args[RespondTo[:to_s]] => ::CZTop::Message
      def message(*frames)
        frames.map(&:to_s).reduce ::CZTop::Message.new << preferred_protocol, :<<
      end

      Contract RespondTo[:to_s] => ::CZTop::Message
      def error(context = '')
        message 'WTF', context
      end

      Contract ::CZTop::Message => ::CZTop::Socket
      def reply(message)
        socket << message
      end

      Contract None => ::CZTop::Message
      def request
        socket.receive
      end

      Contract RespondTo[:to_s] => Bool
      def speaks?(protocol)
        protocols
          .to_a
          .drop(2)
          .any? { |p| protocol.to_s.casecmp(p).zero? }
      end

      Contract RespondTo[:to_s] => Bool
      def provides?(service)
        services
          .to_a
          .drop(2)
          .any? { |s| service.to_s.casecmp(s).zero? }
      end

      Contract RespondTo[:to_s] => Bool
      def handles?(command)
        commands
          .to_a
          .drop(2)
          .map { |c| c.tr('-', '_') }
          .any? { |c| command.to_s.casecmp(c).zero? }
      end

      Contract ::CZTop::Message => ::CZTop::Message
      def handle(request)
        return error 'I expected more than that...' if request.size < 2
        protocol = request.pop
        return error "I do not speak #{protocol}" unless speaks? protocol
        command = request.pop.downcase.tr('-', '_')
        return error "I do not handle #{command}" unless handles? command
        public_send command, *request.to_a
      rescue ArgumentError => exception
        return error exception.message
      end
    end
  end
end
