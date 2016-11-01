#!/usr/bin/env ruby
# coding: utf-8

require 'contracts'
require 'cztop'
require 'moneta'
require 'securerandom'
require 'pry'

class Server
  include ::Contracts::Core
  include ::Contracts::Builtin

  PROTOCOL = 'GameProtocol/1.0'.freeze
  COMMANDS = %w(COMMANDS JOIN LIST JACK-IN MOVE FEEL ATTACK).freeze
  ROLES = %w(ACTORS OBSERVERS).freeze
  ORIENTATIONS = %w(NORTH EAST SOUTH WEST).freeze
  DIRECTIONS = %w(FORWARD BACKWARD LEFT RIGHT).freeze
  OFFSET = {
    'FORWARD' => 0,
    'LEFT' => -1,
    'RIGHT' => 1,
    'BACKWARD' => -2
  }
  ARROW = {
    'NORTH' => '⬆️',
    'SOUTH' => '⬇️',
    'EAST' => '➡️',
    'WEST' => '⬅️'
  }
  MOVES = {
    'NORTH' => [-1, 0],
    'SOUTH' => [1, 0],
    'WEST' => [0, -1],
    'EAST' => [0, 1]
  }
  INTANGIBLE = %w(VOID OBSERVER).freeze

  Orientation = Enum[*ORIENTATIONS]
  Direction = Enum[*DIRECTIONS]

  Contract KeywordArgs => Server
  def initialize(**options)
    @options = options
    self
  end

  def handle(request)
    protocol, command, *payload = request.to_a
    return unacceptable! unless acceptable? protocol
    return unrecognized! unless recognized? command
    public_send command.downcase.tr('-', '_'), *payload
  rescue ArgumentError => error
    reject error.message
  rescue NoMethodError => error
    reject 'Not Implemented'
  end

  Contract None => Any
  def listen
    loop do
      handle request
      display
    end
  end

  Contract None => Any
  def jack_in
    binding.pry
    respond 'DONE'
  end

  Contract None => Any
  def commands
    respond_with('COMMANDS', *COMMANDS)
  end

  Contract String => Any
  def list(role)
    return unrecognized_role! unless ROLES.include? role.upcase
    respond_with('LIST', *state.fetch(role.downcase))
  end

  Contract String => Any
  def join(role)
    return unrecognized_role! unless ROLES.include? role.upcase

    token = add_to role, SecureRandom.uuid
    spawn! token
    respond_with 'WELCOME', token
  end

  Contract String, String => Any
  def attack(token, direction)
    return invald_token! unless valid? token
    return invalid_direction unless valid_direction? direction

    x, y = MOVES[relative_direction orientation(token), direction.upcase]
    px, py = position token
    tx = px + x
    ty = py + y

    return respond_with(edge == 'WALL' ? 'HIT' : 'MISS') if outside_world?(tx, ty)

    case (world[tx] || [])[ty] || []
    when ->(space) { space.empty? }
      respond_with 'MISS'
    when ->(space) { space.all? { |entity| INTANGIBLE.include? role(entity) } }
      respond_with 'MISS'
    else
      respond_with 'HIT'
    end
  end

  Contract String, String, RespondTo[:to_i] => Any
  def move(token, direction, distance = 1)
    distance = distance.to_i
    return invalid_token! unless valid? token
    return invalid_direction! unless valid_direction? direction
    return inconceivable! if distance < 1

    case role token
    when 'ACTOR'
      return slow_the_fuck_down! if distance > 1
    when 'OBSERVER'
      return slow_the_fuck_down! if distance > 2
    end

    x, y = MOVES[relative_direction orientation(token), direction.upcase]
    px, py = position token
    if reposition! token, (px + (x * distance)), (py + (y * distance))
      respond_with 'OK'
    else
      reject 'You cannot move there'
    end
  end

  def feel(token, direction = 'FORWARD')
    return invalid_token! unless valid? token
    return invalid_direction! unless valid_direction? direction

    x, y = MOVES[relative_direction orientation(token), direction.upcase]
    px, py = position token
    fx = px + x
    fy = py + y
    if outside_world? fx, fy
      respond_with 'FEELS-LIKE', edge
    else
      respond_with('FEELS-LIKE', *world[fx][fy].map { |t| role t }.uniq)
    end
  end

  # Dear Future Self: I'm sorry.
  def display
    world.each do |x|
      plane = x.map do |xy|
        token = xy.sort { |t| role t }.first

        if token
          if role(token) == 'ACTOR'
            ARROW.fetch orientation token
          else
            role(token).each_char.first
          end
        else
          ' '
        end
      end.join(' . ')
      STDERR.puts plane
    end
    STDERR.puts
  end

  private

  ### Socket Handling

  Contract None => String
  def address
    @address ||= @options.fetch(:address) { '0.0.0.0' }
  end

  Contract None => Num
  def port
    @port ||= @options.fetch(:port) { 5555 }.to_i
  end

  Contract None => ::CZTop::Socket
  def socket
    @socket ||= ::CZTop::Socket::REP.new "@tcp://#{address}:#{port}"
  end

  Contract None => ArrayOf[String]
  def request
    socket.receive.to_a
  end

  Contract Args[RespondTo[:to_s]] => Any
  def respond(*messages)
    socket << [PROTOCOL, *messages.map(&:to_s)]
  end

  alias respond_with respond

  ### World State

  Contract None => String
  def edge
    @edge ||= %w(WALL VOID).sample
  end

  Contract None => ::Moneta::Proxy
  def state
    @state ||= Moneta.new :Memory
  end

  Contract None => Num
  def width
    @width ||= @options.fetch(:width) { 10 }
  end

  Contract None => Num
  def height
    @height ||= @options.fetch(:height) { 15 }
  end

  Contract None => ArrayOf[ArrayOf[ArrayOf[String]]]
  def world
    @world ||= width.times.map { height.times.map { [] } }
  end

  Contract String, String => String
  def add_to(role, token)
    token.tap do
      state.store role, state.fetch(role, []).push(token)
    end
  end

  Contract String => Maybe[String]
  def role(token)
    role = ROLES.find { |role| state.fetch(role.downcase, []).include? token }
    role.chomp('S') if role
  end

  Contract String => [Num, Num]
  def position(token)
    state.fetch("#{role token}/#{token}/position") do
      spawn! token
      position token
    end
  end

  Contract String, Num, Num => Maybe[ArrayOf[String]]
  def position!(token, x, y)
    return unless world[x][y].empty?

    state.store "#{role token}/#{token}/position", [x, y]
    world[x][y].push token
  end

  Contract String, Num, Num => Maybe[ArrayOf[String]]
  def reposition!(token, x, y)
    return if outside_world? x, y
    ox, oy = position token
    return unless position! token, x, y

    world[ox][oy] = (world[ox][oy] - [token])
    world[x][y]
  end

  Contract String => nil
  def spawn!(token)
    # TODO: Bad mojo here when the world is crowded...
    # Maybe resolve with telefrags?
    spawn!(token) unless position!(token, rand(width), rand(height))
  end

  Contract String => Orientation
  def orientation(token)
    state.fetch("#{role token}/#{token}/orientation") do
      orient! token, ORIENTATIONS.sample
      orientation token
    end
  end

  Contract String, Orientation => Orientation
  def orient!(token, orientation)
    state.store "#{role token}/#{token}/orientation", orientation
  end

  Contract Orientation, Direction => Any
  def relative_direction(orientation, direction)
    compass = ORIENTATIONS.cycle.take ORIENTATIONS.size * 3
    compass.at [
      ORIENTATIONS.size,
      ORIENTATIONS.index(orientation),
      OFFSET[direction]
    ].reduce(:+)
  end

  ### All the things that can go wrong.

  Contract String => Bool
  def valid_direction?(direction)
    DIRECTIONS.any? { |d| d.casecmp direction }
  end

  Contract String => Bool
  def valid?(token)
    ROLES.any? do |role|
      state.fetch(role.downcase) { [] }.include? token
    end
  end

  Contract String => Bool
  def recognized?(command)
    COMMANDS.include? command.upcase
  end

  Contract String => Bool
  def acceptable?(protocol)
    protocol.casecmp(PROTOCOL).zero?
  end

  Contract Num, Num => Bool
  def outside_world?(x, y)
    x < 0 || x >= width || y < 0 || y >= height
  end

  ### All the ways the server can tell you to fuck off.

  Contract Args[RespondTo[:to_s]] => Any
  def reject(*context)
    respond_with 'WTF', *context
  end

  alias rejection reject

  Contract None => Any
  def invalid_token!
    reject 'Invalid Token'
  end

  Contract None => Any
  def unrecognized_role!
    reject 'Unrecognized Role'
  end

  Contract None => Any
  def unrecognized!
    reject 'Unrecognized Command'
  end

  Contract None => Any
  def unacceptable!
    reject 'Unacceptable Protocol'
  end

  Contract None => Any
  def invalid_direction!
    reject 'Invalid Direction'
  end

  Contract None => Any
  def slow_the_fuck_down!
    reject 'Slow Your Roll Bro'
  end

  Contract None => Any
  def inconceivable!
    reject 'Inconceivable Request'
  end

  ### Utility Methods and Stuff

  Contract Num, Num => Bool
  def observer?(x, y)
    world[x][y].any? { |o| state.fetch('observers').include? o }
  end

  Contract Num, Num => Bool
  def actor?(x, y)
    world[x][y].any? { |a| state.fetch('actors').include? a }
  end
end

server = Server.new
server.listen
