#!/usr/bin/env ruby

require 'contracts'
require 'cztop'
require_relative 'basic'
require_relative 'provider'
require_relative 'provider/registry'

module ElGame
  module Service
    class Registered < Basic
      include ::Contracts::Core
      include ::Contracts::Builtin

      Contract None => Any
      def listen
        services.to_a.drop(2).each do |service|
          registry.register! service, socket.last_endpoint
        end

        super
      end

      private

      def registries
        @registries ||= @options
                          .fetch(:registries) { ['tcp://127.0.0.1:5556'] }
                          .map { |r| Provider::Registry.new endpoint: r }
      end

      # Contract None => Registry::Client
      def registry
        registries.first
      end

      def provider(service)
        providers = registries.map { |r| r.provider service }.compact
        Provider.new endpoint: providers.first unless providers.empty?
      end

      def invoke(service, command = service, *args)
        if provider = provider(service)
          provider.public_send command, *args
        elsif block_given?
          yield
        end
      end

      def method_missing(symbol, *args)
        return super unless respond_to_missing? symbol
        invoke symbol, *args
      end

      def respond_to_missing?(symbol, _ = false)
        provider(symbol) || super
      end
    end
  end
end
