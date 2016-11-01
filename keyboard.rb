#!/usr/bin/env ruby

require 'remedy'
require 'pry'
require_relative 'client'

class KeyboardClient < Client
  DIRECTIONS = %i(forward backward left right)

  def listen
    STDERR.puts 'Reading from Keyboard...'
    keyboard.loop { |key| handle key }
  end

  private

  def move!(direction = __callee__)
    request :move, token, direction
  end

  alias forward move!
  alias backward move!
  alias left move!
  alias right move!

  def up
    forward
  end

  def down
    backward
  end

  def handle(key)
    puts "#{key.glyph} (#{key.name})"
    send key.name if respond_to?(key.name, true)
  end

  def keyboard
    @keyboard ||= Remedy::Interaction.new
  end
end

KeyboardClient.new.listen
