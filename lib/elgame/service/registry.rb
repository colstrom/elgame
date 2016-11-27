require 'contracts'
require 'cztop'
require 'moneta'
require 'securerandom'
require_relative 'basic'

module ElGame
  module Service
    class Registry < Basic
      include ::Contracts::Core
      include ::Contracts::Builtin

      PROTOCOL = 'Registry/1.1'.freeze

      Contract None => ::CZTop::Message
      def commands
        %w(OHAI BAI WHO-DOES ALL-THE-THINGS)
          .reduce super, :<<
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

      private

      def port
        @port ||= @options.fetch(:port) { 5556 }
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
