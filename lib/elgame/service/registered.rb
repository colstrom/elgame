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

      # Contract None => Registry::Client
      def registry
        @registry ||= Provider::Registry.new endpoint: 'tcp://127.0.0.1:5556'
      end

      def method_missing(symbol, *args)
        return super unless respond_to_missing? symbol

        Provider.new(endpoint: registry.provider(symbol)).send symbol, *args
      end

      def respond_to_missing?(symbol, _ = false)
        registry.provider(symbol) || super
      end
    end
  end
end
