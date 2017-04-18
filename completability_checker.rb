
require 'yaml'

class CompletabilityChecker
  attr_reader :game, :rng
  
  def initialize(game)
    @game = game
    @rng = Random.new
    load_room_reqs()
    @current_items = []
    @current_items << 0x3D # seal 1
    
    p get_accessible_pickups()
  end
  
  def load_room_reqs
    yaml = YAML::load_file("./dsvrandom/requirements/dos_pickup_requirements.txt")
    @room_reqs = {}
    
    @defs = yaml["Defs"]
    rooms = yaml["Rooms"]
    
    rooms.each do |room_str, yaml_reqs|
      @room_reqs[room_str] ||= {}
      @room_reqs[room_str][:room] = nil
      @room_reqs[room_str][:entities] = {}
      
      yaml_reqs.each do |applies_to, reqs|
        if applies_to == "room"
          @room_reqs[room_str][:room] = reqs
        else
          entity_index = applies_to.to_i(16)
          @room_reqs[room_str][:entities][entity_index] = reqs
        end
      end
    end
  end
  
  def check_req(req)
    @recursively_checked_reqs = []
    check_req_recursive(req)
  end
  
  def check_req_recursive(req)
    return true if req.nil?
    
    if req.is_a?(Integer)
      item_global_id = req
      return @current_items.include?(item_global_id)
    end
    
    req = req.strip
    return true if req.empty?
    
    #puts "Checking req: #{req}"
    #gets
    
    # Don't recurse infinitely checking the same two interdependent requirements.
    return false if @recursively_checked_reqs.include?(req)
    @recursively_checked_reqs << req
    
    if @defs.include?(req)
      return check_req_recursive(@defs[req])
    elsif req =~ /\|/ || req =~ /\&/
      or_reqs = req.split("|")
      or_reqs.each do |or_req|
        and_reqs = or_req.split("&")
        
        or_req_met = and_reqs.all? do |and_req|
          check_req_recursive(and_req)
        end
        
        return true if or_req_met
      end
      
      return false
    else
      raise "Invalid requirement: #{req}"
    end
  end
  
  def get_accessible_pickups
    accessible_pickups = []
    
    @room_reqs.each do |room_str, room_req|
      room_access_reqs = room_req[:room]
      room_entities_reqs = room_req[:entities]
      
      #puts "### CHECKING ROOM REQ"
      if check_req(room_access_reqs)
        room_entities_reqs.each do |entity_index, entity_reqs|
          #puts "## CHECKING ENTITY REQ"
          if check_req(entity_reqs)
            accessible_pickups << {room: room_str, entity_index: entity_index}
          end
        end
      end
    end
    
    return accessible_pickups
  end
  
  def get_random_accessible_pickup
    # pick one random pickup out of the available pickups you can access. then put a progression pickup there.
  end
end
