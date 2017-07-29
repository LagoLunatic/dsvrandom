
require 'yaml'

class DoorCompletabilityChecker
  attr_reader :game,
              :current_items,
              :defs,
              :enemy_locations,
              :event_locations,
              :villager_locations,
              :hidden_locations,
              :mirror_locations,
              :no_glyph_locations,
              :no_progression_locations,
              :inaccessible_doors
  
  def initialize(game, enable_glitches, ooe_nonlinear, ooe_randomize_villagers)
    @game = game
    @enable_glitches = enable_glitches
    @ooe_nonlinear = ooe_nonlinear
    @ooe_randomize_villagers = ooe_randomize_villagers
    
    load_room_reqs()
    @current_items = []
    @current_room = "00-00-01"
    @current_location_in_room = "000"
    @debug = false
  end
  
  def load_room_reqs
    yaml = YAML::load_file("./dsvrandom/progressreqs/#{GAME}_room_requirements.txt")
    @room_reqs = {}
    
    defs = yaml["Defs"]
    @defs = {}
    defs.each do |name, reqs|
      name = name.strip.tr(" ", "_").to_sym
      reqs = parse_reqs(reqs)
      @defs[name] = reqs
    end
    
    glitch_defs = yaml["Glitch defs"]
    @glitch_defs = {}
    if glitch_defs
      glitch_defs.each do |name, reqs|
        name = name.strip.tr(" ", "_").to_sym
        reqs = parse_reqs(reqs)
        @glitch_defs[name] = reqs
      end
    end
    
    if @enable_glitches
      @defs.merge!(@glitch_defs)
    end
    
    @inaccessible_doors = yaml["Inaccessible doors"]
    
    rooms = yaml["Rooms"]
    
    @enemy_locations = yaml["Enemy locations"] || []
    @event_locations = yaml["Event locations"] || []
    @villager_locations = yaml["Villager locations"] || []
    @hidden_locations = yaml["Hidden locations"] || []
    @mirror_locations = yaml["Mirror locations"] || []
    @no_soul_locations = yaml["No soul locations"] || []
    @no_glyph_locations = yaml["No glyph locations"] || []
    @no_progression_locations = yaml["No progression locations"] || []
    
    @warp_connections = yaml["Warp connections"]
    
    @final_room_str = yaml["Final room"]
    
    @subrooms = yaml["Subrooms"]
    
    rooms.each do |room_str, yaml_reqs|
      @room_reqs[room_str] ||= {}
      @room_reqs[room_str][:doors] = {}
      @room_reqs[room_str][:entities] = {}
      
      yaml_reqs.each do |path, reqs|
        parsed_reqs = parse_reqs(reqs)
        
        path =~ /^(\h{3}|e\h{2})-(\h{3}|e\h{2})$/
        path_end = $2
        
        path_begin = $1
        if path_begin =~ /^e(\h{2})$/
          # Entity start
          path_begin = $1.to_i(16)
          @room_reqs[room_str][:entities][path_begin] ||= {}
          @room_reqs[room_str][:entities][path_begin][path_end] = parsed_reqs
        else
          # Door start
          path_begin = path_begin.to_i(16)
          @room_reqs[room_str][:doors][path_begin] ||= {}
          @room_reqs[room_str][:doors][path_begin][path_end] = parsed_reqs
        end
      end
    end
  end
  
  def convert_rooms_to_subrooms(rooms)
    subrooms = []
    
    rooms.each do |room|
      this_rooms_subrooms = @subrooms[room.room_str]
      if this_rooms_subrooms.nil?
        subrooms << room
        next
      end
      
      this_rooms_subrooms.each_with_index do |list_of_doors_and_entities, subroom_index|
        subroom = RoomRandoSubroom.new(room, subroom_index)
        subrooms << subroom
        
        subroom_doors = []
        list_of_doors_and_entities.each do |door_or_ent_str|
          if door_or_ent_str =~ /^e/
            next
          end
          if door_or_ent_str.is_a?(String)
            door_index = door_or_ent_str.to_i(16)
          else
            door_index = door_or_ent_str
          end
          door = room.doors[door_index]
          subroom_doors << RoomRandoDoor.new(door, subroom)
        end
        
        subroom.set_subroom_doors(subroom_doors)
      end
    end
    
    return subrooms
  end
  
  def parse_reqs(reqs)
    if reqs.is_a?(Integer) || reqs.nil?
      return reqs
    elsif reqs == true
      return true
    elsif reqs == false
      return false
    elsif PickupRandomizer::RANDOMIZABLE_VILLAGER_NAMES.include?(reqs.to_sym)
      return reqs.to_sym
    end
    
    or_reqs = reqs.split("|")
    or_reqs.map! do |or_req|
      and_reqs = or_req.split("&")
      and_reqs.map! do |and_req|
        and_req = and_req.strip.tr(" ", "_").to_sym
        and_req = nil if and_req.empty?
        and_req
      end
    end
  end
  
  def game_beatable?
    return get_accessible_rooms().include?(@final_room_str)
  end
  
  def check_reqs(reqs)
    if reqs == true
      return true
    elsif reqs == false
      return false
    end
    
    @cached_checked_reqs = {}
    check_multiple_reqs_recursive(reqs)
  end
  
  def check_req_recursive(req)
    puts "Checking req: #{req}" if @debug
    
    if req == :nonlinear && GAME == "ooe"
      return @ooe_nonlinear
    end
    
    if @defs[req]
      if @defs[req].is_a?(Integer)
        item_global_id = @defs[req]
        has_item = @current_items.include?(item_global_id)
        @cached_checked_reqs[@defs[req]] = has_item
        return has_item
      elsif PickupRandomizer::RANDOMIZABLE_VILLAGER_NAMES.include?(@defs[req])
        has_villager = @current_items.include?(@defs[req])
        @cached_checked_reqs[@defs[req]] = has_villager
        return has_villager
      elsif @defs[req] == true
        return true
      elsif @defs[req] == false
        return false
      end
      
      if @cached_checked_reqs[req] == :currently_checking
        # Don't recurse infinitely checking the same two interdependent requirements.
        return false
      elsif @cached_checked_reqs[req] == true || @cached_checked_reqs[req] == false
        return @cached_checked_reqs[req]
      end
      @cached_checked_reqs[req] = :currently_checking
      
      req_met = check_multiple_reqs_recursive(@defs[req])
      puts "Req #{req} is true" if @debug && req_met
      puts "Req #{req} is false" if @debug && !req_met
      @cached_checked_reqs[req] = req_met
      return req_met
    else
      if !@enable_glitches && @glitch_defs.include?(req)
        # When glitches are disabled, always consider a glitch requirement false.
        return false
      end
      raise "Invalid requirement: #{req}"
    end
  end
  
  def check_multiple_reqs_recursive(or_reqs)
    return true if or_reqs.nil?
    
    or_reqs.each do |and_reqs|
      or_req_met = and_reqs.all? do |and_req|
        check_req_recursive(and_req)
      end
      
      puts "Req #{or_reqs} is true (AND req: #{and_reqs})" if @debug && or_req_met
      return true if or_req_met
    end
    
    puts "Req #{or_reqs} is false" if @debug
    return false
  end
  
  def all_locations
    @all_locations ||= begin
      all_locations = {}
      
      @room_reqs.each do |room_str, room_req|
        door_reqs = room_req[:doors] #TODO entities??
        
        door_reqs.each do |path_begin, path_ends|
          path_ends.each do |path_end, path_reqs|
            if path_end =~ /^e(\h\h)$/
              entity_index = $1
              entity_str = "#{room_str}_#{entity_index}"
              all_locations[entity_str] = nil # the nil is a just a dummy placeholder, the regular completability checker puts reqs there but we don't need to here.
            end
          end
        end
      end
      
      all_locations
    end
  end
  
  def get_accessible_locations_and_rooms
    accessible_locations = []
    
    accessible_doors = []
    checked_doors = []
    
    current_door_str = "#{@current_room}_#{@current_location_in_room}"
    accessible_doors << current_door_str
    
    if @current_location_in_room =~ /^e(\h\h)/
      # At an entity
      entity_index = $1.to_i(16)
      possible_path_ends = @room_reqs[@current_room][:entities][entity_index]
      possible_path_ends.each do |path_end, path_reqs|
        if check_reqs(path_reqs)
          reachable_door_str = "#{@current_room}_#{path_end}"
          accessible_doors << reachable_door_str
        end
      end
    else
      # At a door
      current_door = game.door_by_str(current_door_str)
      dest_door = current_door.destination_door
      dest_room = dest_door.room
      dest_door_index = dest_room.doors.index(dest_door)
      dest_door_str = "%02X-%02X-%02X_%03X" % [dest_room.area_index, dest_room.sector_index, dest_room.room_index, dest_door_index]
      accessible_doors << dest_door_str
    end
    
    accessible_doors.each do |door_str|
      next if checked_doors.include?(door_str)
      checked_doors << door_str
      
      if @warp_connections[door_str]
        connected_door_str = @warp_connections[door_str]
        accessible_doors << connected_door_str
        connected_door = game.door_by_str(connected_door_str)
        destination_door_str = connected_door.destination_door.door_str
        accessible_doors << destination_door_str
      end
      
      door_str =~ /^(\h\h-\h\h-\h\h)_(\h\h\h|e\h\h)$/
      room_str = $1
      door_or_ent_index = $2
      if door_or_ent_index =~ /^e(\h\h)/
        entity_index = $1.to_i(16)
      else
        door_index = door_or_ent_index.to_i(16)
      end
      room = game.room_by_str(room_str)
      
      if @room_reqs[room_str].nil?
        next
      end
      
      if door_index
        possible_path_ends = @room_reqs[room_str][:doors][door_index]
      else
        possible_path_ends = @room_reqs[room_str][:entities][entity_index]
      end
      possible_path_ends.each do |path_end, path_reqs|
        if check_reqs(path_reqs)
          if path_end =~ /^e(\h\h)$/
            # Entity
            entity_index = $1
            entity_str = "#{room_str}_#{$1}"
            accessible_locations << entity_str
          else
            # Door
            door_index = path_end.to_i(16)
            door = room.doors[door_index]
            dest_door = door.destination_door
            dest_room = dest_door.room
            dest_door_index = dest_room.doors.index(dest_door)
            dest_door_str = "%02X-%02X-%02X_%03X" % [dest_room.area_index, dest_room.sector_index, dest_room.room_index, dest_door_index]
            accessible_doors << dest_door_str
          end
        end
      end
    end
    
    accessible_rooms = accessible_doors.map{|door_str| door_str[0,8]}.uniq
    
    return [accessible_locations, accessible_rooms]
  end
  
  def get_accessible_locations
    get_accessible_locations_and_rooms().first
  end
  
  def get_accessible_rooms
    get_accessible_locations_and_rooms().last
  end
  
  def all_progression_pickups
    @all_progression_pickups ||= begin
      pickups = []
      
      @defs.each do |name, req|
        pickups << req if req.is_a?(Integer)
      end
      if GAME == "ooe" && @ooe_randomize_villagers
        pickups += PickupRandomizer::RANDOMIZABLE_VILLAGER_NAMES
      end
      
      pickups
    end
  end
  
  def pickups_by_current_num_locations_they_access
    orig_current_items = @current_items
    
    possibly_useful_pickups = all_progression_pickups - @current_items
    
    currently_accessible_locations = get_accessible_locations()
    
    pickups_by_locations = {}
    
    possibly_useful_pickups.each do |pickup_global_id|
      @current_items = orig_current_items + [pickup_global_id]
      next_accessible_pickups = get_accessible_locations() - currently_accessible_locations
      
      pickups_by_locations[pickup_global_id] = next_accessible_pickups.length
    end
    
    return pickups_by_locations
  ensure
    @current_items = orig_current_items
  end
  
  def add_item(new_item_global_id)
    @current_items << new_item_global_id
  end
  
  def set_current_location_by_entity(entity_str)
    entity_str =~ /^(\h\h-\h\h-\h\h)_(\h\h)$/
    @current_room = $1
    @current_location_in_room = "e#{$2}"
  end
  
  def generate_empty_room_requirements_file
    File.open("./dsvrandom/#{GAME}_room_requirements.txt", "w+") do |f|
      prev_area_name = nil
      prev_sector_name = nil
      game.each_room do |room|
        pickups = room.entities.select{|e| e.is_pickup? || e.is_item_chest? || e.is_money_chest? || e.is_glyph_statue?}
        doors = room.doors
        next if (pickups + doors).length < 2
        
        area_name = AREA_INDEX_TO_AREA_NAME[room.area_index]
        if area_name != prev_area_name
          f.puts "#%s:" % area_name
          prev_area_name = area_name
        end
        
        if SECTOR_INDEX_TO_SECTOR_NAME[room.area_index]
          sector_name = SECTOR_INDEX_TO_SECTOR_NAME[room.area_index][room.sector_index]
          if sector_name != prev_sector_name
            f.puts "#%s:" % sector_name
            prev_sector_name = sector_name
          end
        end
        
        door_indexes = (0..doors.length-1).map{|i| "%03X" % i}
        entity_indexes = pickups.map{|entity| "e%02X" % room.entities.index(entity)}
        indexes = door_indexes + entity_indexes
        
        f.puts "  %02X-%02X-%02X:" % [room.area_index, room.sector_index, room.room_index]
        door_indexes.each do |index|
          (indexes-[index]).each do |other_index|
            f.puts "    #{index}-#{other_index}: "
          end
        end
        entity_indexes.each do |ent_index|
          door_indexes.each do |other_index|
            f.puts "    #{ent_index}-#{other_index}: "
          end
        end
      end
    end
  end
  
  def get_item_name_for_generated_reqs_file(pickup)
    if pickup.is_heart?
      return "Heart"
    end
    if pickup.is_money_bag?
      return "Money"
    end
    if pickup.is_item?
      if GAME == "ooe"
        item_id = pickup.var_b - 1
        item = game.items[item_id]
        return item.name
      else
        item_type_index = pickup.subtype
        item_index = pickup.var_b
        item = game.get_item_by_type_and_index(item_type_index, item_index)
        return item.name
      end
    end
    if pickup.is_glyph?
      item_id = pickup.var_b - 1
      item = game.items[item_id]
      return item.name
    end
    if pickup.is_skill?
      item_type_index = PICKUP_SUBTYPES_FOR_SKILLS.begin
      item_index = pickup.var_b
      item = game.get_item_by_type_and_index(item_type_index, item_index)
      return item.name
    end
    if pickup.is_item_chest?
      item_id = pickup.var_a - 1
      item = game.items[item_id]
      return item.name
    end
    if pickup.is_glyph_statue?
      item_id = pickup.var_b - 1
      item = game.items[item_id]
      return item.name
    end
    if pickup.is_money_chest?
      return "Money Chest"
    end
  end
end

class RoomRandoDoor < Door
  def initialize(door, subroom)
    attrs = %w(fs game door_ram_pointer destination_room_metadata_ram_pointer x_pos y_pos dest_x_unused dest_y_unused dest_x dest_y unknown)
    
    attrs.each do |attr_name|
      instance_variable_set("@#{attr_name}", door.instance_variable_get("@#{attr_name}"))
    end
    
    @original_door = door
    
    @room = subroom
  end
  
  def write_to_rom()
    super
    # Need to reload the original door so it can be referenced by the completability checking logic.
    @original_door.read_from_rom(door_ram_pointer)
  end
end

class RoomRandoSubroom < Room
  def initialize(room, subroom_index)
    attrs = %w(area_index sector_index room_index room_xpos_on_map room_ypos_on_map layers room_metadata_ram_pointer sector)
    
    attrs.each do |attr_name|
      instance_variable_set("@#{attr_name}", room.instance_variable_get("@#{attr_name}"))
    end
    
    @subroom_index = subroom_index
  end
  
  def set_subroom_doors(subroom_doors)
    @doors = subroom_doors
  end
  
  #def room_str
  #  "#{super}-SUB%02X" % @subroom_index
  #end
end
