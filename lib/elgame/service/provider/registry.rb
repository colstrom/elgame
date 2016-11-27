require 'contracts'
require 'cztop'
require_relative '../provider'

module ElGame
  module Service
    class Provider
      class Registry < Provider
        include ::Contracts::Core
        include ::Contracts::Builtin

        Contract None => Bool
        def registered?
          !tokens.empty?
        end

        Contract RespondTo[:to_s], RespondTo[:to_s] => Maybe[String]
        def register!(service, provider)
          response = ohai service, provider
          return unless response.pop.casecmp('WELCOME').zero?
          tokens.store service.to_s, response.pop
        end

        Contract RespondTo[:to_s] => Maybe[String]
        def deregister!(service)
          return unless token = tokens[service.to_s]
          response = bai token
          return unless response.pop.casecmp('GTFO').zero?
          tokens.delete service.to_s
        end

        Contract None => ArrayOf[String]
        def services
          response = all_the_things
          return [] unless response.pop.casecmp('SERVICES').zero?
          response.to_a
        end

        Contract None => HashOf[String, ArrayOf[String]]
        def providers
          services.map { |service| [service, providers(service)] }.to_h
        end

        Contract RespondTo[:to_s] => ArrayOf[String]
        def providers(service)
          response = who_does service
          return [] unless response.pop.casecmp('PROVIDERS').zero?
          response.to_a
        end

        Contract RespondTo[:to_s] => Maybe[String]
        def provider(service)
          providers(service).sample
        end

        private

        Contract None => HashOf[String, String]
        def tokens
          @tokens ||= {}
        end
      end
    end
  end
end
