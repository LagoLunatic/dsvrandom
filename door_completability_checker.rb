
require 'yaml'

class DoorCompletabilityChecker < CompletabilityChecker
  attr_reader :game,
              :current_items,
              :return_portraits,
              
              :defs,
              :preferences,
              
              :inaccessible_doors,
              :progress_important_rooms,
              :subrooms_doors_only,
              :subroom_map_tiles,
              
              :all_progression_pickups,
              
              :enemy_locations,
              :event_locations,
              :easter_egg_locations,
              :villager_locations,
              :hidden_locations,
              :mirror_locations,
              :no_soul_locations,
              :no_glyph_locations,
              :no_progression_locations,
              :portrait_locations
  
  def initialize(game, options)
    @game = game
    @options = options
    
    load_room_reqs()
    @current_items = []
    @return_portraits = {}
    @required_accessible_doors_to_unlock_regular_portraits = {
      :portrait13thstreet    => [["04-01-08_000", "04-01-08_001"]], # Mummy Man
      :portraitburntparadise => [["08-00-04_000", "08-00-04_001"]], # The Creature
    }
    @post_brauner_teleport_dest_door = "00-09-03_001"
    if @options[:open_world_map]
      @world_map_areas_unlocked_from_beginning = [
        "02-00-03_000",
        "03-00-00_000",
        "04-00-00_000",
        "05-00-03_000",
        "06-00-00_000",
        "07-00-00_000",
        "08-00-00_000",
        "09-00-00_000",
        "0A-00-00_000",
        "0B-00-00_000",
        "0C-00-00_000",
        "0D-00-00_000",
        "0E-00-0C_000",
        "0F-00-08_000",
        "10-01-06_000",
        "11-00-00_000",
        "12-01-00_000",
      ]
    else
      # Ecclesia is unlocked by default in Shanoa mode.
      @world_map_areas_unlocked_from_beginning = ["02-00-03_000"]
    end
    @debug = false
    
    if @options[:randomize_world_map_exits]
      # Remove default world map values. These will be set as they are randomized.
      @world_map_unlocks = {
        "00-02-1B_000": "03-00-00_000, 0C-00-00_000", # Dracula's castle back exit unlocks are not randomized
      }
    end
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
    
    if @options[:enable_glitch_reqs]
      @defs.merge!(@glitch_defs)
    end
    
    @inaccessible_doors = yaml["Inaccessible doors"] || []
    
    @preferences = {}
    if yaml["Preferences"]
      yaml["Preferences"].each do |pickup_name, weight|
        pickup_id = @defs[pickup_name.strip.tr(" ", "_").to_sym]
        @preferences[pickup_id] = weight
      end
    end
    
    rooms = yaml["Rooms"]
    
    @enemy_locations = yaml["Enemy locations"] || []
    @event_locations = yaml["Event locations"] || []
    @easter_egg_locations = yaml["Easter egg locations"] || []
    @villager_locations = yaml["Villager locations"] || []
    @hidden_locations = yaml["Hidden locations"] || []
    @mirror_locations = yaml["Mirror locations"] || []
    @no_soul_locations = yaml["No soul locations"] || []
    @no_glyph_locations = yaml["No glyph locations"] || []
    @no_progression_locations = yaml["No progression locations"] || []
    @portrait_locations = yaml["Portrait locations"] || []
    @world_map_exits = yaml["World map exits"] || []
    @world_map_unlocks = yaml["World map unlocks"] || []
    
    @progress_important_rooms = yaml["Progress important rooms"]
    
    # If boss souls/portraits/villagers aren't randomized, then we don't have the freedom to place them wherever we want.
    # So we need to ensure their vanilla rooms are placed by the map randomizer.
    if !@options[:randomize_boss_souls]
      @progress_important_rooms += @enemy_locations.map do |location|
        location[0,8]
      end
    end
    if !@options[:randomize_portraits]
      @progress_important_rooms += @portrait_locations.map do |location|
        location[0,8]
      end
    end
    if !@options[:randomize_villagers]
      @progress_important_rooms += @villager_locations.map do |location|
        location[0,8]
      end
    end
    @progress_important_rooms.uniq!
    
    @progress_important_rooms.map! do |room_str|
      game.room_by_str(room_str)
    end
    
    @warp_connections = yaml["Warp connections"] || {}
    
    @final_room_str = yaml["Final room"]
    
    @subrooms = yaml["Subrooms"] || {}
    @subrooms_doors_only = {}
    @subroom_map_tiles = {}
    @subrooms.each do |room_str, this_rooms_subrooms|
      @subrooms_doors_only[room_str] = []
      @subroom_map_tiles[room_str] = []
      
      this_rooms_subrooms.each do |subroom_data|
        list_of_doors_and_entities = subroom_data["doors_and_entities"]
        map_tiles = subroom_data["map_tiles"]
        
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
          subroom_doors << door_index
        end
        
        @subrooms_doors_only[room_str] << subroom_doors
        
        @subroom_map_tiles[room_str] << map_tiles
      end
    end
    
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
      
      this_rooms_subrooms.each_with_index do |subroom_data, subroom_index|
        list_of_doors_and_entities = subroom_data["doors_and_entities"]
        
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
  
  def add_inaccessible_door(door)
    #puts "Adding inaccessible door: #{door.door_str}"
    @inaccessible_doors << door.door_str
  end
  
  def game_beatable?
    if GAME == "ooe" && !check_reqs([[:dominus_hatred, :dominus_anger, :dominus_agony]])
      # Reaching the throne room in OoE isn't good enough, you also need all 3 dominus glyphs.
      return false
    end
    accessible_rooms = get_accessible_doors().map{|door_str| door_str[0,8]}.uniq
    return accessible_rooms.include?(@final_room_str)
  end
  
  def albus_fight_accessible?
    get_accessible_doors().include?("0E-00-09_000")
  end
  
  def wind_accessible?
    get_accessible_doors().include?("00-01-06_000")
  end
  
  def vincent_accessible?
    get_accessible_doors().include?("00-01-09_000")
  end
  
  def check_req_recursive(req)
    puts "Checking req: #{req}" if @debug
    
    if req == :nonlinear && GAME == "ooe"
      return @options[:open_world_map]
    end
    if GAME == "ooe" && (PickupRandomizer::RANDOMIZABLE_VILLAGER_NAMES.include?(req) || req == :villagernikolai)
      return @current_items.include?(req)
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
      elsif PickupRandomizer::PORTRAIT_NAMES.include?(@defs[req])
        has_access_to_portrait = @current_items.include?(@defs[req])
        @cached_checked_reqs[@defs[req]] = has_access_to_portrait
        return has_access_to_portrait
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
      if !@options[:enable_glitch_reqs] && @glitch_defs.include?(req)
        # When glitches are disabled, always consider a glitch requirement false.
        return false
      end
      raise "Invalid requirement: #{req}"
    end
  end
  
  def all_locations
    @all_locations ||= begin
      all_locations = {}
      
      @room_reqs.each do |room_str, room_req|
        # We only bother checking door reqs since these alone should have all entities at the end.
        door_reqs = room_req[:doors]
        
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
  
  def get_accessible_locations_and_doors
    # Use a hashes instead of arrays for these because it improves performance of checking if a specific thing is accessible.
    # (Only within this method, they still get returned as arrays.)
    accessible_locations = {}
    accessible_doors = {}
    
    doors_and_entities_to_check = []
    
    doors_and_entities_to_check << @starting_location # Player can always use a magical ticket to access their starting location.
    
    case GAME
    when "dos"
      # DoS-specific variables for keeping track of whether the darkness seal is unlocked.
      has_mina_talisman = check_reqs([[:mina_talisman]])
      dos_darkness_seal_unlocked = false
    when "por"
      # PoR-specific variable for keeping track of if the Throne Room is accessible.
      por_throne_room_stairway_accessible = false
    when "ooe"
      # OoE-specific variables for dealing with the world map.
      currently_unlocked_world_map_areas = {}
      @world_map_areas_unlocked_from_beginning.each do |world_map_door_str|
        currently_unlocked_world_map_areas[world_map_door_str] = true
      end
      world_map_accessible = false
      castle_accessible = false
      barlowe_accessible = false
      george_accessible = false
      albus_fight_accessible = false
      wygol_accessible = true
      lighthouse_accessible = @options[:open_world_map]
      lighthouse_past_spikes_accessible = false
      has_all_randomizable_villagers = false
      if (PickupRandomizer::RANDOMIZABLE_VILLAGER_NAMES - @current_items).empty?
        has_all_randomizable_villagers = true
      end
    end
    
    if GAME == "por"
      locked_accessible_portraits = []
      @current_items.each do |pickup_global_id|
        if PickupRandomizer::PORTRAIT_NAMES.include?(pickup_global_id)
          portrait_name = pickup_global_id
          
          required_doors_for_this_portrait = @required_accessible_doors_to_unlock_regular_portraits[portrait_name]
          if required_doors_for_this_portrait
            # Can't count 13th street/burnt paradise as accessible by default.
            # In the middle of the main door crawling logic we will repeatedly check to see if the bosses needed to unlock these are reachable yet.
            locked_accessible_portraits << portrait_name
            next
          end
          
          dest_door_strs = get_destination_of_portrait(portrait_name)
          
          if dest_door_strs == false
            # Can't access any doors in the destination room.
            next
          end
          
          doors_and_entities_to_check += dest_door_strs
        end
      end
    end
    
    # Initialize reachable destinations of the current location the player is at.
    if @current_location_in_room =~ /^e(\h\h)/
      # At an entity
      entity_index = $1.to_i(16)
      current_entity_str = "#{@current_room}_e%02X" % entity_index
      doors_and_entities_to_check << current_entity_str
    else
      # At a door
      current_door_str = "#{@current_room}_#{@current_location_in_room}"
      doors_and_entities_to_check << current_door_str
    end
    
    while doors_and_entities_to_check.any?
      door_or_entity_str = doors_and_entities_to_check.shift()
      
      if door_or_entity_str =~ /^(\h\h-\h\h-\h\h)_e(\h\h)$/
        room_str = $1
        entity_index = $2.to_i(16)
        
        next if accessible_locations[door_or_entity_str]
        entity_location_str = "#{room_str}_%02X" % entity_index # Remove the e prefix for the entity.
        accessible_locations[entity_location_str] = true
        
        current_room = game.room_by_str(room_str)
        current_entity = current_room.entities[entity_index]
        
        if @room_reqs[room_str]
          possible_path_ends = @room_reqs[room_str][:entities][entity_index]
          possible_path_ends.each do |path_end, path_reqs|
            if check_reqs(path_reqs)
              if path_end =~ /^e(\h\h)$/
                # Entity. This code shouldn't ever run since the room reqs don't include entity->entity paths, but put it here anyway for future-proofing.
                entity_str = "#{room_str}_#{$1}"
                accessible_locations[entity_str] = true
              else
                # Door
                door_index = path_end.to_i(16)
                door = current_room.doors[door_index]
                next if door.destination_room_metadata_ram_pointer == 0 # Door dummied out by the map-friendly room randomizer.
                dest_door = door.destination_door
                doors_and_entities_to_check << dest_door.door_str
              end
            end
          end
        elsif current_room.doors.length >= 2
          raise "Room #{room_str} has 2 or more doors but no logic!"
        end
      elsif door_or_entity_str =~ /^(\h\h-\h\h-\h\h)_(\h\h\h)$/
        room_str = $1
        door_index = $2.to_i(16)
        
        next if accessible_doors[door_or_entity_str]
        accessible_doors[door_or_entity_str] = true
        
        current_room = game.room_by_str(room_str)
        current_door = current_room.doors[door_index]
        
        # Add this door's destination door to the list of doors to check
        # Unless this door has been dummied out by the map-friendly room randomizer, in which case it has no destination door.
        unless current_door.destination_room_metadata_ram_pointer == 0
          dest_door = current_door.destination_door
          doors_and_entities_to_check << dest_door.door_str
        end
        
        if @room_reqs[room_str]
          possible_path_ends = @room_reqs[room_str][:doors][door_index]
          possible_path_ends.each do |path_end, path_reqs|
            if check_reqs(path_reqs)
              if path_end =~ /^e(\h\h)$/
                # Entity
                entity_str = "#{room_str}_#{$1}"
                accessible_locations[entity_str] = true
              else
                # Door
                door_index = path_end.to_i(16)
                door = current_room.doors[door_index]
                next if door.destination_room_metadata_ram_pointer == 0 # Door dummied out by the map-friendly room randomizer.
                dest_door = door.destination_door
                doors_and_entities_to_check << dest_door.door_str
              end
            end
          end
        elsif current_room.doors.length >= 2
          raise "Room #{room_str} has 2 or more doors but no logic!"
        end
      else
        raise "Invalid door or entity str: #{door_or_entity_str.inspect}"
      end
      
      
      
      
      if @warp_connections[door_or_entity_str]
        connected_door_str = @warp_connections[door_or_entity_str]
        doors_and_entities_to_check << connected_door_str
      end
      
      # Handle the darkness seal.
      if GAME == "dos"
        if has_mina_talisman && !dos_darkness_seal_unlocked && (accessible_doors["00-03-0E_000"] || accessible_doors["00-03-0E_001"])
          # Player can access and complete the doppelganger event in the center of the castle.
          dos_darkness_seal_unlocked = true
        end
        if dos_darkness_seal_unlocked && accessible_doors["00-05-0C_000"]
          # Player can access the darkness seal room, and has also unlocked the darkness seal.
          doors_and_entities_to_check << "00-05-0C_001"
        end
      end
      
      if GAME == "por" && locked_accessible_portraits.any?
        portraits_to_unlock = []
        locked_accessible_portraits.each do |portrait_name|
          required_doors_for_this_portrait = @required_accessible_doors_to_unlock_regular_portraits[portrait_name]
        
          portrait_unlocked = required_doors_for_this_portrait.all? do |possible_door_strs|
            # Consider the portrait unlocked if at least one door in each of the required rooms is accessible.
            possible_door_strs.any?{|door_str| accessible_doors[door_str]}
          end
          
          if portrait_unlocked
            # Can reach all the doors needed to unlock this portrait.
            dest_door_strs = get_destination_of_portrait(portrait_name)
            
            if dest_door_strs == false
              # Can't access any doors in the destination room. Do nothing.
            else
              doors_and_entities_to_check += dest_door_strs
              portraits_to_unlock << portrait_name # Can't delete this portrait from the locked_accessible_portraits array in the middle of a loop. Delete it after.
            end
          end
        end
        
        locked_accessible_portraits -= portraits_to_unlock # Now delete the unlocked portraits from locked_accessible_portraits.
      end
      
      # Handle the Studio Portrait warp to the Throne Room stairway in PoR.
      if GAME == "por"
        if !por_throne_room_stairway_accessible && accessible_doors["00-0B-00_000"] # Player has access to the 5-portrait room.
          studio_portrait_unlocked = @required_boss_room_doors_to_unlock_studio_portrait.all? do |possible_door_strs|
            # Consider the studio portrait unlocked if at least one door in each of the required boss rooms is accessible.
            possible_door_strs.any?{|door_str| accessible_doors[door_str]}
          end
          if studio_portrait_unlocked # The studio portrait is unlocked.
            doors_and_entities_to_check << @post_brauner_teleport_dest_door # Give access to the stairway room leading to the Throne Room.
            por_throne_room_stairway_accessible = true
          end
        end
      end
      
      if GAME == "por"
        if @return_portraits[door_or_entity_str]
          # If the current door we're on is a door in a return portrait room, we need to add the enter portrait to the list of locations to check.
          enter_portrait_entity_str = @return_portraits[door_or_entity_str]
          doors_and_entities_to_check << enter_portrait_entity_str
        end
      end
      
      # Handle the world map in OoE.
      if GAME == "ooe"
        newly_unlocked_world_map_door_strs = []
        
        # Normal world map unlocks, not hardcoded.
        if @world_map_unlocks[door_or_entity_str]
          newly_world_map_unlocks = @world_map_unlocks[door_or_entity_str].split(",").map{|str| str.strip}
          newly_world_map_unlocks.each do |world_map_entrance_door_str|
            if world_map_entrance_door_str == "09-00-00_000"
              # For the Lighthouse entrance we need to delay giving access to the right door because there are spikes in between the entrance and door.
              lighthouse_accessible = true
            else
              newly_unlocked_world_map_door_strs << world_map_entrance_door_str
            end
          end
        end
        
        if !barlowe_accessible && accessible_doors["02-00-06_000"]
          barlowe_accessible = true
        end
        if !albus_fight_accessible && accessible_doors["0E-00-09_000"]
          albus_fight_accessible = true
        end
        if !george_accessible && accessible_doors["11-00-08_000"]
          george_accessible = true
        end
        
        # Unlock the castle on the world map.
        if !castle_accessible && has_all_randomizable_villagers &&
            george_accessible &&
            wygol_accessible && # nikolai in wygol
            albus_fight_accessible &&
            barlowe_accessible
          newly_unlocked_world_map_door_strs << "00-0C-00_000"
          castle_accessible = true
        end
        
        # Unlock the lighthouse, but only if the player can jump over the spikes.
        if lighthouse_accessible && !lighthouse_past_spikes_accessible
          if check_reqs([[:magnes], [:medium_height, :small_distance], [:distance], [:big_height], [:cat_tackle]])
            newly_unlocked_world_map_door_strs << "09-00-00_000"
            lighthouse_past_spikes_accessible = true
          end
        end
        
        if world_map_accessible
          # If the world map is already accessible, we add them to the list of doors to check.
          doors_and_entities_to_check += newly_unlocked_world_map_door_strs
          newly_unlocked_world_map_door_strs.each do |world_map_door_str|
            currently_unlocked_world_map_areas[world_map_door_str] = true
          end
        else
          # Otherwise we add them to a temporary list which will be added to our doors to check whenever we get access to the world map.
          newly_unlocked_world_map_door_strs.each do |world_map_door_str|
            currently_unlocked_world_map_areas[world_map_door_str] = true
          end
        end
        
        if !world_map_accessible
          # Check if we should unlock the world map.
          @world_map_exits.each do |entry_point|
            if accessible_doors[entry_point]
              if entry_point == "09-00-00_000" && !check_reqs([[:magnes], [:medium_height, :small_distance], [:distance], [:big_height], [:cat_tackle]])
                # Can't get past the spikes in the first room of lighthouse without taking damage.
                next
              elsif entry_point == "06-01-00_000" && !check_reqs([[:serpent_scale]])
                # Can't get out of the bottom left exit of kalidus without serpent scale.
                next
              end
              
              # When we first unlock the world map, add the world map areas that we unlocked earlier to the currently accessible rooms.
              doors_and_entities_to_check += currently_unlocked_world_map_areas.keys
              
              world_map_accessible = true
              break
            end
          end
        end
      end
    end
    
    if wygol_accessible
      accessible_doors["01-01-00_000"] = true # Technically not a real door, Wygol has no doors. This is just a hack to keep track of whether we can access Nikolai.
    end
    
    accessible_locations = accessible_locations.keys
    accessible_doors = accessible_doors.keys
    
    return [accessible_locations, accessible_doors]
  end
  
  def get_accessible_locations
    get_accessible_locations_and_doors()[0]
  end
  
  def get_accessible_doors
    get_accessible_locations_and_doors()[1]
  end
  
  def set_starting_room(starting_room, starting_room_door_index)
    @current_room = starting_room.room_str
    @current_location_in_room = "%03X" % starting_room_door_index
    @starting_location = "#{@current_room}_#{@current_location_in_room}"
  end
  
  def restore_return_portraits(old_return_portraits)
    @return_portraits = old_return_portraits
  end
  
  def set_removed_portraits(removed_portraits)
    @removed_portraits = removed_portraits
    
    if removed_portraits.empty?
      required_boss_rooms_to_unlock_studio_portrait = ["02-02-14", "04-01-08", "06-00-05", "08-00-04"] # Werewolf, Mummy Man, Medusa, and The Creature
    else
      portraits_needed = PickupRandomizer::PORTRAIT_NAMES - [:portraitnestofevil] - removed_portraits
      
      required_boss_rooms_to_unlock_studio_portrait = portraits_needed.map do |portrait_name|
        case portrait_name
        when :portraitcityofhaze
          "01-02-0B" # Dullahan
        when :portraitsandygrave
          "03-00-0C" # Astarte
        when :portraitnationoffools
          "05-02-0C" # Legion
        when :portraitforestofdoom
          "07-00-0E" # Dagon
        when :portraitdarkacademy
          "08-00-04" # The Creature
        when :portraitburntparadise
          "06-00-05" # Medusa
        when :portraitforgottencity
          "04-01-08" # Mummy Man
        when :portrait13thstreet
          "02-02-14" # Werewolf
        else
          raise "Invalid portrait name: #{portrait_name}"
        end
      end
    end
    
    # Convert the list of rooms to a list of all the doors in those rooms.
    # This way the logic can check if ANY of the doors are accessible to know if the boss is accessible.
    # Picking any individual door won't work if the map randomizer blocks off that specific door but a different door still lets the player access the boss.
    @required_boss_room_doors_to_unlock_studio_portrait = required_boss_rooms_to_unlock_studio_portrait.map do |room_str|
      if room_str == "05-02-0C"
        # Legion. In this case it has to be the top door, the others won't work.
        ["05-02-0C_000"]
      else
        room = game.room_by_str(room_str)
        room_doors = room.doors.reject{|door| inaccessible_doors.include?(door.door_str)}
        room_doors.map{|door| door.door_str}
      end
    end
  end
  
  def remove_13th_street_and_burnt_paradise_boss_death_prerequisites
    # Remove 13th street's mummy requirement.
    game.fs.write(0x02078FC4+3, [0xEA].pack("C")) # Change conditional branch to unconditional branch.
    @required_accessible_doors_to_unlock_regular_portraits.delete(:portrait13thstreet) # Remove the logic's check for this unlock
    
    # Remove burnt paradise's creature requirement.
    game.fs.write(0x02079008+3, [0xEA].pack("C")) # Change conditional branch to unconditional branch.
    @required_accessible_doors_to_unlock_regular_portraits.delete(:portraitburntparadise) # Remove the logic's check for this unlock
  end
  
  def move_por_white_barrier_location(new_room_str, path_begin_door, path_end_door)
    @room_reqs["00-0A-01"][:doors][1]["000"] = nil # Unset the default white barrier req
    @room_reqs[new_room_str][:doors][path_begin_door]["%03X" % path_end_door] = false # Set the new location
  end
  
  def set_post_brauner_teleport_dest_door(door_str)
    @post_brauner_teleport_dest_door = door_str
  end
  
  def add_return_portrait(return_portrait_room_str, enter_portrait_entity_str)
    # Create a mapping of doors in return portrait rooms to the enter portrait entity locations they lead to.
    
    if return_portrait_room_str !~ /^\h\h-\h\h-\h\h$/
      raise "Invalid room string for return portrait: #{return_portrait_room_str.inspect}"
    end
    if enter_portrait_entity_str !~ /^\h\h-\h\h-\h\h_\h\h$/
      raise "Invalid entity string for enter portrait: #{enter_portrait_entity_str.inspect}"
    end
    
    # Add the e prefix to the entity string to further distinguish it from a door string.
    enter_portrait_entity_str =~ /^(\h\h-\h\h-\h\h)_(\h\h)$/
    room_str, entity_index = $1, $2
    enter_portrait_entity_str = "#{room_str}_e#{entity_index}"
    
    case return_portrait_room_str
    when "05-00-21" # Nation of Fools
      door_indexes = [0, 1, 2]
    when "06-00-20" # Burnt Paradise main entrance
      door_indexes = [0, 1]
    else
      door_indexes = [0]
    end
    
    door_indexes.each do |door_index|
      return_portrait_door_str = "#{return_portrait_room_str}_%03X" % door_index
      @return_portraits[return_portrait_door_str] = enter_portrait_entity_str
    end
  end
  
  def get_destination_of_portrait(portrait_name)
    portrait_data = PickupRandomizer::PORTRAIT_NAME_TO_DATA[portrait_name]
    area_index = portrait_data[:area_index]
    sector_index = portrait_data[:sector_index]
    room_index = portrait_data[:room_index]
    case area_index
    when 5 # Nation of Fools
      door_indexes = [1, 2]
      if check_reqs([[:double_jump, :puppet_master], [:jumpglitch, :puppet_master], [:quad_jump_height]])
        door_indexes += [0]
      end
    when 6 # Burnt Paradise
      if check_reqs([[:small_height]])
        door_indexes = [0, 1]
      else
        # The player needs at least small height to reach either door in the first room of Burnt Paradise.
        # Don't count Burnt Paradise as being reachable if the player can't reach any doors in it yet.
        return false
      end
    else
      door_indexes = [0]
    end
    
    return door_indexes.map{|door_index| "%02X-%02X-%02X_%03X" % [area_index, sector_index, room_index, door_index]}
  end
  
  def remove_final_approach_gate_requirement
    # Remove the logic that it's impossible to get through the room with the big gate in the Final Approach.
    @room_reqs["00-0A-01"][:doors][0]["001"] = nil
  end
  
  def set_world_map_exit_destination_area(world_map_exit_door_str, entrance_door_str)
    if @world_map_unlocks[world_map_exit_door_str]
      raise "Tried to set a world map unlock that already exists: #{world_map_exit_door_str}"
    end
    @world_map_unlocks[world_map_exit_door_str] = entrance_door_str
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
        pickups = room.entities.select{|e| e.is_pickup? || e.is_item_chest? || e.is_money_chest? || e.is_glyph_statue? || e.is_villager?}
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
    if pickup.is_villager?
      return case pickup.var_a
      when 0x2A
        "Jacob"
      when 0x2D
        "Abram"
      when 0x3C
        "Aeon"
      when 0x38
        "Eugen"
      when 0x4F
        "Monica"
      when 0x32
        "Laura"
      when 0x40
        "Marcel"
      when 0x47
        "Serge"
      when 0x4B
        "Anna"
      when 0x57
        "Daniela"
      when 0x53
        "Irina"
      end
    end
  end
end

class RoomRandoDoor < Door
  attr_reader :original_door
  
  def initialize(door, subroom)
    attrs = %w(fs game door_ram_pointer destination_room_metadata_ram_pointer x_pos y_pos dest_x_2 dest_y_2 dest_x dest_y unused)
    
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
  
  def door_str
    @original_door.door_str
  end
end

class RoomRandoSubroom < Room
  def initialize(room, subroom_index)
    attrs = %w(area_index sector_index room_index room_xpos_on_map room_ypos_on_map layers room_metadata_ram_pointer sector entities)
    
    attrs.each do |attr_name|
      instance_variable_set("@#{attr_name}", room.instance_variable_get("@#{attr_name}"))
    end
    
    @subroom_index = subroom_index
  end
  
  def set_subroom_doors(subroom_doors)
    @doors = subroom_doors
  end
end
