require 'contracts'
require 'cztop'
require 'moneta'
require 'securerandom'

module ElGame
  module Service
    class Registry
      class Server
        include ::Contracts::Core
        include ::Contracts::Builtin

        Contract KeywordArgs => Server
        def initialize(**options)
          @options = options
          self
        end

        Contract String, String => ::CZTop::Message
        def ohai(service, provider)
          return error if [service, provider].any?(&:empty?)
          service.upcase!
          return (message << 'WELCOME-BACK') if providers(service).member? provider
          providers.store service, providers(service) << provider
          services << service
          token = SecureRandom.uuid
          tokens.store token, [service, provider]
          message << 'WELCOME' << token
        end

        Contract String => ::CZTop::Message
        def bai(token)
          return (message << 'GTFO') unless tokens.key? token

          service, provider = tokens.fetch token
          providers.store service, providers(service) - [provider]
          services.delete(service) if providers(service).empty?
          message << 'GTFO'
        end

        Contract None => ::CZTop::Message
        def all_the_things
          services.reduce(message << 'SERVICES', :<<)
        end

        Contract String => ::CZTop::Message
        def who_does(service)
          providers.fetch(service.upcase, Set.new).reduce(message << 'PROVIDERS', :<<)
        end

        Contract None => Any
        def listen
          loop { handle request }
        end

        private

        Contract None => String
        def protocol
          @protocol ||= 'Registry/1.1'.freeze
        end

        Contract None => ::CZTop::Message
        def message
          ::CZTop::Message.new << protocol
        end

        Contract None => String
        def address
          @address ||= @options.fetch(:address) { 'tcp://0.0.0.0:5556' }
        end

        Contract None => ::CZTop::Socket
        def socket
          @socket ||= ::CZTop::Socket::REP.new "@#{address}"
        end

        Contract ::CZTop::Message => ::CZTop::Socket
        def reply(message)
          socket << message.tap { |m| puts "< #{m}" }
        end

        def error(description)
          message << 'WTF' << description
        end

        Contract ::CZTop::Message => ::CZTop::Socket
        def handle(request)
          reply error 'Unsupported Protocol' unless request.pop.casecmp(protocol).zero?
          request.prepend request.pop.downcase.tr('-', '_')
          reply send(*request.to_a)
        end

        Contract None => ::CZTop::Message
        def request
          socket.receive.tap { |m| puts "> #{m}" }
        end

        Contract None => SetOf[String]
        def services
          @services ||= Set.new
        end

        Contract None => ::Moneta::Proxy
        def providers
          @providers ||= ::Moneta.new :Memory
        end

        Contract RespondTo[:to_s] => SetOf[String]
        def providers(service)
          providers.fetch(service.to_s) { Set.new }
        end

        Contract None => ::Moneta::Proxy
        def tokens
          @tokens ||= ::Moneta.new :Memory
        end

        Contract RespondTo[:to_s] => SetOf[String]
        def tokens(service)
          tokens.fetch(service.to_s) { Set.new }
        end
      end
    end
  end
end
