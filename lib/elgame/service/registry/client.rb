require 'contracts'
require 'cztop'

module ElGame
  module Service
    class Registry
      class Client
        include ::Contracts::Core
        include ::Contracts::Builtin

        Contract KeywordArgs => Client
        def initialize(**options)
          @options = options
          self
        end

        Contract None => Bool
        def registered?
          !tokens.empty?
        end

        Contract RespondTo[:to_s], RespondTo[:to_s] => Maybe[String]
        def register!(service, provider)
          request ohai service.to_s, provider.to_s
          response, token = p(reply).to_a
          tokens.store(service.to_s, token) if response.casecmp('WELCOME').zero?
        end

        Contract RespondTo[:to_s] => Maybe[String]
        def deregister!(service)
          return unless token = tokens[service.to_s]
          request bai token
          response = p(reply).pop
          tokens.delete(service.to_s) if response.casecmp('GTFO').zero?
        end

        Contract None => ArrayOf[String]
        def services
          request all_the_things
          response, *services = p(reply).to_a
          return [] unless response.casecmp('SERVICES').zero?
          services
        end

        Contract None => HashOf[String, ArrayOf[String]]
        def providers
          services.map { |service| [service, providers(service)] }.to_h
        end

        Contract RespondTo[:to_s] => ArrayOf[String]
        def providers(service)
          request who_does service.to_s
          response, *providers = p(reply).to_a
          response.casecmp('PROVIDERS').zero? ? providers : []
        end

        Contract RespondTo[:to_s] => Maybe[String]
        def provider(service)
          providers(service).sample
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

        Contract RespondTo[:to_s], RespondTo[:to_s] => ::CZTop::Message
        def ohai(service, provider)
          message << 'OHAI' << service.to_s << provider.to_s
        end

        Contract RespondTo[:to_s] => ::CZTop::Message
        def bai(token)
          message << 'BAI' << token.to_s
        end

        Contract RespondTo[:to_s] => ::CZTop::Message
        def who_does(service)
          message << 'WHO-DOES' << service.to_s
        end

        Contract None => ::CZTop::Message
        def all_the_things
          message << 'ALL-THE-THINGS'
        end

        Contract None => HashOf[String, String]
        def tokens
          @tokens ||= {}
        end

        Contract None => String
        def address
          @address ||= @options.fetch(:address) { 'tcp://127.0.0.1:5556' }
        end

        Contract None => ::CZTop::Socket
        def socket
          @socket ||= ::CZTop::Socket::REQ.new ">#{address}"
        end

        Contract ::CZTop::Message => ::CZTop::Socket
        def request(message)
          socket << message.tap { |m| puts "> #{m}"}
        end

        Contract None => Maybe[::CZTop::Message]
        def reply
          socket.receive.tap do |message|
            if message.pop.casecmp(protocol).zero?
              puts "< #{message}"
            else
              puts "! #{message}"
              return nil # NOTE: Returns from method, not block.
            end
          end
        end
      end
    end
  end
end
