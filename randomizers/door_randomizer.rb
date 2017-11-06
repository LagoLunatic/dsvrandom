
module DoorRandomizer
  def randomize_transition_doors
    @transition_rooms = game.get_transition_rooms()
    @transition_rooms.reject! do |room|
      FAKE_TRANSITION_ROOMS.include?(room.room_metadata_ram_pointer)
    end
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      all_area_transition_rooms = @transition_rooms.select do |transition_room|
        transition_room.area_index == area.area_index
      end
      
      if all_area_transition_rooms.empty?
        # No transition rooms in this area.
        next
      end
      
      all_area_subsectors = []
      area.sectors.each do |sector|
        all_area_subsectors += get_subsectors(sector)
      end
      
      remaining_transitions = {
        left: [],
        right: [],
      }
      
      other_transitions_in_same_subsector = {}
      accessible_unused_transitions = []
      transition_doors_by_subsector = Array.new(all_area_subsectors.size){ [] }
      
      starting_transition = nil
      
      # First we make a list of the transition doors, specifically the left door in a transition room, and the right door that leads into that transition room.
      all_area_transition_rooms.each do |transition_room|
        transition_door = transition_room.doors.find{|door| door.direction == :left}
        dest_door = transition_door.destination_door
        remaining_transitions[transition_door.direction] << transition_door
        remaining_transitions[dest_door.direction] << dest_door
      end
      
      # Then we go through each transition door and keep track of what subsector it's located in.
      remaining_transitions.values.flatten.each do |transition_door|
        all_area_subsectors.each_with_index do |subsector_rooms, subsector_index|
          if subsector_rooms.include?(transition_door.room)
            transition_doors_by_subsector[subsector_index] << transition_door
            other_transitions_in_same_subsector[transition_door] = transition_doors_by_subsector[subsector_index]
            break
          end
        end
        
        if other_transitions_in_same_subsector[transition_door].nil?
          puts all_area_subsectors.flatten.map{|x| x.room_str}
          raise "#{transition_door.door_str} can't be found in any subsector"
        end
      end
      
      starting_transition = remaining_transitions.values.flatten.sample(random: rng)
      
      on_first = true
      while true
        debug = false
        
        if on_first
          inside_transition_door = starting_transition
          on_first = false
        else
          inside_transition_door = accessible_unused_transitions.sample(random: rng)
        end
        
        puts "(area connections) inside door: #{inside_transition_door.door_str}" if debug
        
        inside_door_opposite_direction = case inside_transition_door.direction
        when :left
          :right
        when :right
          :left
        end
        inaccessible_remaining_matching_doors = remaining_transitions[inside_door_opposite_direction] - accessible_unused_transitions
        inaccessible_remaining_matching_doors -= other_transitions_in_same_subsector[inside_transition_door]
        
        inaccessible_remaining_matching_doors_with_other_exits = inaccessible_remaining_matching_doors.select do |door|
          new_subsector_exits = (other_transitions_in_same_subsector[door] & remaining_transitions.values.flatten) - [door]
          new_subsector_exits.any?
        end
        
        if inaccessible_remaining_matching_doors_with_other_exits.any?
          # There are doors we can swap with that allow more progress to new subsectors.
          possible_dest_doors = inaccessible_remaining_matching_doors_with_other_exits
          
          puts "TRANSITION TYPE 1" if debug
        elsif inaccessible_remaining_matching_doors.any?
          # There are doors we can swap with that will allow you to reach one new subsector which is a dead end.
          possible_dest_doors = inaccessible_remaining_matching_doors
          
          puts "TRANSITION TYPE 2" if debug
        elsif remaining_transitions[inside_door_opposite_direction].any?
          # This door direction doesn't have any more matching doors left to swap with that will result in progress.
          # So just pick any matching door.
          possible_dest_doors = remaining_transitions[inside_door_opposite_direction]
          
          puts "TRANSITION TYPE 3" if debug
        else
          # This door direction doesn't have any matching doors left.
          
          puts "TRANSITION TYPE 4" if debug
          
          raise "Area connections randomizer: Could not link all subsectors!"
        end
        
        outside_transition_door = possible_dest_doors.sample(random: rng)
        
        puts "(area connections) outside door: #{outside_transition_door.door_str}" if debug
        
        remaining_transitions[inside_transition_door.direction].delete(inside_transition_door)
        remaining_transitions[outside_transition_door.direction].delete(outside_transition_door)
        
        if queued_door_changes[inside_transition_door].any?
          puts "changed inside transition door twice: #{inside_transition_door.door_str}"
          raise "Changed a transition door twice"
        end
        if queued_door_changes[outside_transition_door].any?
          puts "changed outside transition door twice: #{outside_transition_door.door_str}"
          raise "Changed a transition door twice"
        end
        
        queued_door_changes[inside_transition_door]["destination_room_metadata_ram_pointer"] = outside_transition_door.room.room_metadata_ram_pointer
        queued_door_changes[inside_transition_door]["dest_x"] = outside_transition_door.destination_door.dest_x
        queued_door_changes[inside_transition_door]["dest_y"] = outside_transition_door.destination_door.dest_y
        queued_door_changes[outside_transition_door]["destination_room_metadata_ram_pointer"] = inside_transition_door.room.room_metadata_ram_pointer
        queued_door_changes[outside_transition_door]["dest_x"] = inside_transition_door.destination_door.dest_x
        queued_door_changes[outside_transition_door]["dest_y"] = inside_transition_door.destination_door.dest_y
        
        accessible_unused_transitions.delete(inside_transition_door)
        accessible_unused_transitions.delete(outside_transition_door)
        accessible_unused_transitions += (other_transitions_in_same_subsector[inside_transition_door] & remaining_transitions.values.flatten)
        accessible_unused_transitions += (other_transitions_in_same_subsector[outside_transition_door] & remaining_transitions.values.flatten)
        accessible_unused_transitions.uniq!
        
        if accessible_unused_transitions.empty?
          if remaining_transitions.values.flatten.size == 0
            break
          else
            raise "Area connections randomizer: Not all sectors connected: #{remaining_transitions.values.flatten.map{|door| door.door_str}}"
          end
        end
      end
    end
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      door.write_to_rom()
    end
  end
  
  def randomize_non_transition_doors
    # We make sure every room in an area is accessible. This is to prevent infinite loops of a small number of rooms that connect to each other with no way to progress.
    # Loop through each room. search for remaining rooms that have a matching door. But the room we find must also have remaining doors in it besides the one we swap with so it's not a dead end, or a loop. If there are no rooms that meet those conditions, then we go with the more lax condition of just having a matching door, allowing dead ends.
    
    @transition_rooms = game.get_transition_rooms()
    @transition_rooms.reject! do |room|
      FAKE_TRANSITION_ROOMS.include?(room.room_metadata_ram_pointer)
    end
    
    # Make a list of doors that lead into transition rooms so we can tell these apart from regular doors.
    transition_doors = []
    @transition_rooms.each do |room|
      room.doors.each do |inside_door|
        transition_doors << inside_door.destination_door
      end
    end
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      if GAME == "ooe" && area.area_index == 2
        # Don't randomize Ecclesia.
        next
      end
      
      area.sectors.each do |sector|
        if GAME == "ooe" && area.area_index == 7 && sector.sector_index == 1
          # Don't randomize Rusalka's sector. It's too small to do anything with properly.
          next
        end
        
        # First get the "subsectors" in this sector.
        # A subsector is a group of rooms in a sector that can access each other.
        # This separates certains sectors into multiple parts like the first sector of PoR.
        subsectors = get_subsectors(sector)
        
        # TODO: for each subsector, count the number of up/down connections vs the number of left/right connections.
        # then prioritize doing the rarer ones first when possible.
        # also, guarantee that ALL rooms in a subsector connect to each other somehow.
        subsectors.each_with_index do |subsector_rooms, i|
          if GAME == "por" && area.area_index == 0 && sector.sector_index == 0 && i == 0
            # Don't randomize first subsector in PoR.
            next
          end
          
          subsector_rooms = checker.convert_rooms_to_subrooms(subsector_rooms)
          
          #if sector.sector_index == 2
          #  puts "On subsector: #{i}"
          #  puts "Subsector rooms:"
          #  subsector_rooms.each do |room|
          #    puts "  %08X" % room.room_metadata_ram_pointer
          #  end
          #end
          
          remaining_doors = get_valid_doors(subsector_rooms, sector)
          
          #if sector.sector_index == 1
          #  remaining_doors.values.flatten.each do |door|
          #    puts "  #{door.door_str}"
          #  end
          #  puts "num doors: #{remaining_doors.values.flatten.size}"
          #  gets
          #end
          
          all_randomizable_doors = remaining_doors.values.flatten
          all_rooms = all_randomizable_doors.map{|door| door.room}.uniq
          if all_rooms.empty?
            # No doors in this sector
            next
          end
          unvisited_rooms = all_rooms.dup
          accessible_remaining_doors = []
          
          current_room = unvisited_rooms.sample(random: rng)
          
          while true
            debug = false
            #debug = (area.area_index == 0 && sector.sector_index == 1)
            
            #puts remaining_doors[:down].map{|d| d.door_str} if debug
            #gets if debug
            
            puts "on room #{current_room.room_str}" if debug
            
            unvisited_rooms.delete(current_room)
            
            accessible_remaining_doors += remaining_doors.values.flatten.select{|door| door.room == current_room}
            accessible_remaining_doors.uniq!
            accessible_remaining_doors = accessible_remaining_doors & remaining_doors.values.flatten
            
            if accessible_remaining_doors.empty?
              break
            end
            
            accessible_remaining_updown_doors = accessible_remaining_doors.select{|door| [:up, :down].include?(door.direction)}
            if accessible_remaining_updown_doors.any?
              # Always prioritize doing up and down doors first.
              inside_door = accessible_remaining_updown_doors.sample(random: rng)
            else
              inside_door = accessible_remaining_doors.sample(random: rng)
            end
            remaining_doors[inside_door.direction].delete(inside_door)
            accessible_remaining_doors.delete(inside_door)
            accessible_remaining_leftright_doors = accessible_remaining_doors.select{|door| [:left, :right].include?(door.direction)}
            
            puts "inside door chosen: #{inside_door.door_str}" if debug
            
            inside_door_opposite_direction = case inside_door.direction
            when :left
              :right
            when :right
              :left
            when :up
              :down
            when :down
              :up
            end
            
            inaccessible_remaining_matching_doors = remaining_doors[inside_door_opposite_direction] - accessible_remaining_doors
            #puts "REMAINING: #{remaining_doors[inside_door_opposite_direction].map{|x| "  #{x.door_str}\n"}}"
            
            inaccessible_remaining_matching_doors_with_other_exits = inaccessible_remaining_matching_doors.select do |door|
              ((door.room.doors & all_randomizable_doors) - transition_doors).length > 1 && unvisited_rooms.include?(door.room)
            end
            
            inaccessible_remaining_matching_doors_with_updown_door_exits = []
            inaccessible_remaining_matching_doors_with_no_leftright_door_exits = []
            if [:left, :right].include?(inside_door.direction)
              # If we're on a left/right door, prioritize going to new rooms that have an up/down door so we don't get locked out of having any up/down doors to work with.
              
              inaccessible_remaining_matching_doors_with_updown_door_exits = inaccessible_remaining_matching_doors_with_other_exits.select do |door|
                if door.direction == :left || door.direction == :right
                  ((door.room.doors & all_randomizable_doors) - transition_doors).any?{|x| x.direction == :up || x.direction == :down}
                end
              end
            else
              # If we're on an up/down door, prioritize going to new rooms that DON'T have any usable left/right doors in them.
              # This is because those rooms with left/right doors are more easily accessible via left/right doors. We need to prioritize the ones that only have up/down doors as they're trickier to make the logic place.
              
              inaccessible_remaining_matching_doors_with_no_leftright_door_exits = inaccessible_remaining_matching_doors.select do |door|
                if door.direction == :up || door.direction == :down
                  ((door.room.doors & all_randomizable_doors) - transition_doors).none?{|x| x.direction == :left || x.direction == :right}
                end
              end
              
              if debug && inaccessible_remaining_matching_doors_with_no_leftright_door_exits.any?
                puts "Found up/down doors with no left/right exits in destination:"
                inaccessible_remaining_matching_doors_with_no_leftright_door_exits.each{|x| puts "  #{x.door_str}"}
              end
            end
            
            if inaccessible_remaining_matching_doors_with_no_leftright_door_exits.any? && accessible_remaining_leftright_doors.size >= 1
              # There are doors we can swap with that allow you to reach a new room which is a dead end, but is a dead end with only up/down doors.
              # We want to prioritize these because they can't be gotten into via left/right doors like rooms that have at least one left/right.
              # Note that we also only take this option if there's at least 1 accessible left/right door for us to still use. If there's not this would deadend us instantly.
              possible_dest_doors = inaccessible_remaining_matching_doors_with_no_leftright_door_exits
              
              puts "TYPE 1" if debug
            elsif inaccessible_remaining_matching_doors_with_updown_door_exits.any?
              # There are doors we can swap with that allow more progress, and also allow accessing an new up/down door from a left/right door.
              possible_dest_doors = inaccessible_remaining_matching_doors_with_updown_door_exits
              
              puts "TYPE 2" if debug
            elsif inaccessible_remaining_matching_doors_with_other_exits.any?
              # There are doors we can swap with that allow more progress.
              possible_dest_doors = inaccessible_remaining_matching_doors_with_other_exits
              
              puts "TYPE 3" if debug
            elsif inaccessible_remaining_matching_doors.any?
              # There are doors we can swap with that will allow you to reach one new room which is a dead end.
              possible_dest_doors = inaccessible_remaining_matching_doors
              
              puts "TYPE 4" if debug
            elsif remaining_doors[inside_door_opposite_direction].any?
              # This door direction doesn't have any more matching doors left to swap with that will result in progress.
              # So just pick any matching door.
              possible_dest_doors = remaining_doors[inside_door_opposite_direction]
              
              puts "TYPE 5" if debug
            else
              # This door direction doesn't have any matching doors left.
              # Don't do anything to this door.
              
              puts "TYPE 6" if debug
              
              #puts "#{inside_door.direction} empty"
              #
              #accessible_rooms = accessible_remaining_doors.map{|door| door.room}.uniq
              #accessible_rooms -= [current_room]
              #
              #current_room = accessible_rooms.sample(random: rng)
              #p accessible_remaining_doors.size
              #gets
              
              raise "not all rooms in this subsector are connected! %02X-%02X" % [area.area_index, sector.sector_index]
              
              current_room = unvisited_rooms.sample(random: rng)
              
              if current_room.nil?
                current_room = all_rooms.sample(random: rng)
              end
              
              if remaining_doors.values.flatten.empty?
                break
              end
              
              next
            end
            
            if [:up, :down].include?(inside_door.direction)
              # Don't randomize up/down doors. This is a temporary hacky measure to greatly reduce failures at connecting all rooms in a subsector.
              new_dest_door = inside_door.destination_door
              # Also need to convert this door to a subroomdoor, if applicable.
              new_dest_door = all_randomizable_doors.find{|subroomdoor| subroomdoor.door_str == new_dest_door.door_str}
            else
              new_dest_door = possible_dest_doors.sample(random: rng)
            end
            remaining_doors[new_dest_door.direction].delete(new_dest_door)
            
            current_room = new_dest_door.room
            
            if queued_door_changes[inside_door].any? || queued_door_changes[new_dest_door].any?
              raise "Changed a door twice"
            end
            
            queued_door_changes[inside_door]["destination_room_metadata_ram_pointer"] = new_dest_door.room.room_metadata_ram_pointer
            queued_door_changes[inside_door]["dest_x"] = new_dest_door.destination_door.dest_x
            queued_door_changes[inside_door]["dest_y"] = new_dest_door.destination_door.dest_y
            
            queued_door_changes[new_dest_door]["destination_room_metadata_ram_pointer"] = inside_door.room.room_metadata_ram_pointer
            queued_door_changes[new_dest_door]["dest_x"] = inside_door.destination_door.dest_x
            queued_door_changes[new_dest_door]["dest_y"] = inside_door.destination_door.dest_y
            
            if debug
              puts "inside_door: #{inside_door.door_str}"
              #puts "old_outside_door: %08X" % old_outside_door.door_ram_pointer
              #puts "inside_door_to_swap_with: %08X" % inside_door_to_swap_with.door_ram_pointer
              puts "new_outside_door: #{new_dest_door.door_str}"
              puts "dest room: #{new_dest_door.room.room_str}"
              puts
              #break
            end
          end
          
          if unvisited_rooms.any?
            puts "Failed to connect the following rooms:"
            unvisited_rooms.each do |room|
              puts "  #{room.room_str}"
            end
            raise "Room connections randomizer failed to connect some rooms."
          end
        end
      end
    end
    
    doors_to_line_up = []
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      unless doors_to_line_up.include?(door.destination_door)
        doors_to_line_up << door
      end
      
      door.write_to_rom()
    end
    
    lined_up_door_strs = []
    doors_to_line_up.each do |door|
      next if lined_up_door_strs.include?(door.destination_door.door_str)
      lined_up_door_strs << door.door_str
      
      line_up_door(door)
    end
    
    replace_outer_boss_doors()
  end
  
  def get_subsectors(sector)
    subsectors = []
    
    remaining_rooms_to_check = sector.rooms.dup
    while remaining_rooms_to_check.any?
      current_subsector = []
      current_room = remaining_rooms_to_check.first
      while true
        current_subsector << current_room
        remaining_rooms_to_check.delete(current_room)
        connected_rooms = current_room.doors.map{|door| door.destination_door.room}.uniq
        connected_rooms = connected_rooms & sector.rooms
        current_subsector += connected_rooms
        current_subsector.uniq!
        
        remaining_subsector_rooms = current_subsector & remaining_rooms_to_check
        break if remaining_subsector_rooms.empty?
        current_room = remaining_subsector_rooms.first
      end
      subsectors += [current_subsector]
    end
    
    return subsectors
  end
  
  def get_valid_doors(rooms, sector)
    remaining_doors = {
      left: [],
      up: [],
      right: [],
      down: []
    }
    
    map = game.get_map(sector.area_index, sector.sector_index)
    
    rooms.each do |room|
      next if @transition_rooms.include?(room)
      
      room.doors.each do |door|
        next if @transition_rooms.include?(door.destination_door.room)
        next if checker.inaccessible_doors.include?(door.door_str)
        
        if GAME == "dos" && ["00-01-1C_001", "00-01-20_000"].include?(door.door_str)
          # Don't randomize the door connecting Paranoia and Mini-Paranoia.
          next
        end
        if GAME == "ooe" && ["09-00-05_000", "09-00-05_001", "09-00-02_000", "09-00-02_001", "09-00-04_000", "09-00-04_001", "09-00-03_000", "09-00-03_001"].include?(door.door_str)
          # Don't randomize the doors at the top of the Lighthouse, otherwise the player could enter Brachyura's room from the top and the fight would bug out.
          next
        end
        if GAME == "ooe" && ["0C-00-0E_000", "0C-00-0F_000", "0C-00-0F_001", "0C-00-10_000"].include?(door.door_str)
          # Don't randomize the doors in Large Cavern connecting the warp room, one-way room, and boss room.
          next
        end
        
        map_tile_x_pos = room.room_xpos_on_map
        map_tile_y_pos = room.room_ypos_on_map
        
        if door.x_pos == 0xFF
          # Do nothing
        elsif door.x_pos >= room.main_layer_width
          map_tile_x_pos += room.main_layer_width - 1
        else
          map_tile_x_pos += door.x_pos
        end
        if door.y_pos == 0xFF
          # Do nothing
        elsif door.y_pos >= room.main_layer_height
          map_tile_y_pos += room.main_layer_height - 1
        else
          map_tile_y_pos += door.y_pos
        end
        
        map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos &&  tile.y_pos == map_tile_y_pos}
        
        if map_tile.nil?
          # Door that's not on the map, just an unused door.
          next
        end
        
        # If the door is shown on the map as a wall, skip it.
        # Those are leftover doors not intended to be used, and are inaccessible (except with warp glitches).
        case door.direction
        when :left
          next if map_tile.left_wall
        when :right
          next if map_tile.right_wall
          if GAME == "dos" || GAME == "aos"
            # Right walls in DoS are handled as the left wall of the tile to the right.
            right_map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos+1 &&  tile.y_pos == map_tile_y_pos}
            next if right_map_tile.left_wall
          end
        when :up
          next if map_tile.top_wall
        when :down
          next if map_tile.bottom_wall
          if GAME == "dos" || GAME == "aos"
            # Bottom walls in DoS are handled as the top wall of the tile below.
            below_map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos &&  tile.y_pos == map_tile_y_pos+1}
            next if below_map_tile.top_wall
          end
        end
        
        remaining_doors[door.direction] << door
      end
    end
    
    return remaining_doors
  end
  
  def remove_door_blockers
    obj_subtypes_to_remove = case GAME
    when "dos"
      [0x43, 0x44, 0x46, 0x57, 0x1E, 0x2B, 0x26, 0x2A, 0x29, 0x45, 0x27, 0x24, 0x37, 0x04]
    when "por"
      [0x37, 0x30, 0x89, 0x38, 0x2F, 0x36, 0x32, 0x31, 0x88, 0x26, 0x46, 0x41, 0x78, 0xB2, 0xB3, 0x2E, 0x40, 0x83]
    when "ooe"
      [0x5B, 0x5A, 0x59]
    end
    
    breakable_wall_subtype = case GAME
    when "dos"
      nil # All breakable walls are path blocking in DoS, so they're instead included in obj_subtypes_to_remove.
    when "por"
      0x3B
    when "ooe"
      0x5C
    end
    
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_special_object? && obj_subtypes_to_remove.include?(entity.subtype)
          entity.type = 0
          entity.write_to_rom()
        elsif entity.is_special_object? && entity.subtype == breakable_wall_subtype
          case GAME
          when "por"
            PATH_BLOCKING_BREAKABLE_WALLS.each do |wall_data|
              if entity.var_a == wall_data[:var_a] && entity.room.area_index == wall_data[:area_index] && (entity.room.area_index != 0 || entity.room.sector_index == wall_data[:sector_index])
                entity.type = 0
                entity.write_to_rom()
                break
              end
            end
          when "ooe"
            PATH_BLOCKING_BREAKABLE_WALLS.each do |wall_vars|
              if entity.var_a == wall_vars[:var_a] && entity.var_b == wall_vars[:var_b]
                entity.type = 0
                entity.write_to_rom()
                break
              end
            end
          end
        end
      end
    end
    
    case GAME
    when "dos"
      drawbridge_room_waterlevel = game.entity_by_str("00-00-15_04")
      drawbridge_room_waterlevel.type = 0
      drawbridge_room_waterlevel.write_to_rom()
    when "ooe"
      forsaken_cloister_gate = game.entity_by_str("00-09-06_00")
      forsaken_cloister_gate.type = 0
      forsaken_cloister_gate.write_to_rom()
    end
    
    # Remove breakable walls from the map as well so it matches visually with the level design.
    maps = []
    if GAME == "dos"
      maps << game.get_map(0, 0)
      maps << game.get_map(0, 0xA)
    else
      AREA_INDEX_TO_OVERLAY_INDEX.keys.each do |area_index|
        maps << game.get_map(area_index, 0)
      end
    end
    maps.each do |map|
      map.tiles.each do |tile|
        if tile.left_secret
          tile.left_secret = false
          tile.left_door = true
        end
        if tile.top_secret
          tile.top_secret = false
          tile.top_door = true
        end
        if tile.right_secret
          tile.right_secret = false
          tile.right_door = true
        end
        if tile.bottom_secret
          tile.bottom_secret = false
          tile.bottom_door = true
        end
      end
      map.write_to_rom()
    end
  end
  
  def replace_outer_boss_doors
    boss_rooms = []
    if GAME == "dos"
      boss_rooms << game.room_by_str("00-03-0E") # Doppelganger event room
    end
    
    # Make a list of boss rooms to fix the boss doors for.
    game.each_room do |room|
      next if room.area.name == "Ecclesia"
      next if room.area.name == "Nest of Evil"
      next if room.area.name == "Large Cavern"
      
      room.entities.each do |entity|
        if entity.is_boss_door? && entity.var_a == 0
          # Boss door outside a boss room. Remove it.
          entity.type = 0
          entity.write_to_rom()
        end
        
        if entity.is_boss_door? && entity.var_a != 0
          boss_rooms << room
        end
      end
    end
    
    
    # Replace boss doors.
    boss_rooms.uniq.each do |boss_room|
      if boss_room.room_str == "00-03-0E"
        # Doppelganger event room
        boss_index = 0xE
      else
        boss_index = boss_room.entities.find{|e| e.is_boss_door?}.var_b
      end
      
      doors = boss_room.doors
      if GAME == "dos" && boss_index == 7 # Gergoth
        doors = doors[0..1] # Only do the top two doors in the tower.
      end
      
      doors.each do |door|
        next unless [:left, :right].include?(door.direction)
        next if checker.inaccessible_doors.include?(door.door_str)
        
        dest_door = door.destination_door
        dest_room = dest_door.room
        
        # Don't add a boss door when two boss rooms are connected to each other, that would result in overlapping boss doors.
        if boss_rooms.include?(dest_room)
          next
        end
        
        gap_start_index, gap_end_index, tiles_in_biggest_gap = get_biggest_door_gap(dest_door)
        gap_end_offset = gap_end_index * 0x10 + 0x10
        
        new_boss_door = Entity.new(dest_room, game.fs)
        new_boss_door.x_pos = door.dest_x
        new_boss_door.y_pos = door.dest_y + gap_end_offset
        if door.direction == :left
          new_boss_door.x_pos += 0xF0
        end
        
        new_boss_door.type = 2
        new_boss_door.subtype = BOSS_DOOR_SUBTYPE
        new_boss_door.var_a = 0
        new_boss_door.var_b = boss_index
        
        dest_room.entities << new_boss_door
        dest_room.write_entities_to_rom()
      end
    end
    
    
    # Fix Nest of Evil/Large Cavern boss doors.
    game.each_room do |room|
      next unless room.area.name == "Nest of Evil" || room.area.name == "Large Cavern"
      
      room_has_enemies = room.entities.find{|e| e.type == 1}
      
      room.entities.each do |entity|
        if entity.is_boss_door? && entity.var_a == 2
          # Boss door in Nest of Evil/Large Cavern that never opens.
          if room_has_enemies
            # We switch these to the normal ones that open when the room is cleared so the player can progress even with rooms randomized.
            entity.var_a = 1
          else
            # This is one of the vertical corridors with no enemies. A normal boss door wouldn't open here since there's no way to clear a room with no enemies.
            # So instead just delete the door.
            entity.type = 0
          end
          entity.write_to_rom()
        end
      end
    end
  end
  
  def line_up_door(door)
    # Sometimes two doors don't line up perfectly. For example if the opening is at the bottom of one room but the middle of the other.
    # We change the dest_x/dest_y of these so they line up correctly.
    
    dest_door = door.destination_door
    dest_room = dest_door.room
    
    case door.direction
    when :left
      left_door = door
      right_door = dest_door
    when :right
      right_door = door
      left_door = dest_door
    when :up
      up_door = door
      down_door = dest_door
    when :down
      down_door = door
      up_door = dest_door
    end
    
    case door.direction
    when :left, :right
      left_first_tile_i, left_last_tile_i, left_tiles_in_biggest_gap = get_biggest_door_gap(left_door)
      right_first_tile_i, right_last_tile_i, right_tiles_in_biggest_gap = get_biggest_door_gap(right_door)
      
      unless left_last_tile_i == right_last_tile_i
        left_door_dest_y_offset = (right_last_tile_i - left_last_tile_i) * 0x10
        right_door_dest_y_offset = (left_last_tile_i - right_last_tile_i) * 0x10
        
        # We use the unused dest offsets because they still work fine and this way we don't mess up the code Door#destination_door uses to guess the destination door, since that's based off the used dest_x and dest_y.
        left_door.dest_y_2 = left_door_dest_y_offset
        right_door.dest_y_2 = right_door_dest_y_offset
      end
      
      # If the gaps are not the same size we need to block off part of the bigger gap so that they are the same size.
      # Otherwise the player could enter a room inside a solid wall, and get thrown out of bounds.
      if left_tiles_in_biggest_gap.size < right_tiles_in_biggest_gap.size
        num_tiles_to_remove = right_tiles_in_biggest_gap.size - left_tiles_in_biggest_gap.size
        tiles_to_remove = right_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        # For those huge doorways that take up the entire screen (e.g. Kalidus), we want to make sure the bottommost tile of that screen is solid so it's properly delineated from the doorway of the screen below.
        if right_tiles_in_biggest_gap.size == SCREEN_HEIGHT_IN_TILES
          # We move up the gap by one block.
          tiles_to_remove = tiles_to_remove[0..-2]
          tiles_to_remove << right_tiles_in_biggest_gap.last
          
          # Then we also have to readjust the dest y offsets.
          left_door.dest_y_2 -= 0x10
          right_door.dest_y_2 += 0x10
        end
        
        block_off_tiles(right_door.room, tiles_to_remove)
      elsif right_tiles_in_biggest_gap.size < left_tiles_in_biggest_gap.size
        num_tiles_to_remove = left_tiles_in_biggest_gap.size - right_tiles_in_biggest_gap.size
        tiles_to_remove = left_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        # For those huge doorways that take up the entire screen (e.g. Kalidus), we want to make sure the bottommost tile of that screen is solid so it's properly delineated from the doorway of the screen below.
        if left_tiles_in_biggest_gap.size == SCREEN_HEIGHT_IN_TILES
          # We move up the gap by one block.
          tiles_to_remove = tiles_to_remove[0..-2]
          tiles_to_remove << left_tiles_in_biggest_gap.last
          
          # Then we also have to readjust the dest y offsets.
          right_door.dest_y_2 -= 0x10
          left_door.dest_y_2 += 0x10
        end
        
        block_off_tiles(left_door.room, tiles_to_remove)
      end
      
      left_door.write_to_rom()
      right_door.write_to_rom()
    when :up, :down
      up_first_tile_i, up_last_tile_i, up_tiles_in_biggest_gap = get_biggest_door_gap(up_door)
      down_first_tile_i, down_last_tile_i, down_tiles_in_biggest_gap = get_biggest_door_gap(down_door)
      
      unless up_last_tile_i == down_last_tile_i
        up_door_dest_x_offset = (down_last_tile_i - up_last_tile_i) * 0x10
        down_door_dest_x_offset = (up_last_tile_i - down_last_tile_i) * 0x10
        
        # We use the unused dest offsets because they still work fine and this way we don't mess up the code Door#destination_door uses to guess the destination door, since that's based off the used dest_x and dest_y.
        up_door.dest_x_2 = up_door_dest_x_offset
        down_door.dest_x_2 = down_door_dest_x_offset
      end
      
      # If the gaps are not the same size we need to block off part of the bigger gap so that they are the same size.
      # Otherwise the player could enter a room inside a solid wall, and get thrown out of bounds.
      if up_tiles_in_biggest_gap.size < down_tiles_in_biggest_gap.size
        num_tiles_to_remove = down_tiles_in_biggest_gap.size - up_tiles_in_biggest_gap.size
        tiles_to_remove = down_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        block_off_tiles(down_door.room, tiles_to_remove)
      elsif down_tiles_in_biggest_gap.size < up_tiles_in_biggest_gap.size
        num_tiles_to_remove = up_tiles_in_biggest_gap.size - down_tiles_in_biggest_gap.size
        tiles_to_remove = up_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        block_off_tiles(up_door.room, tiles_to_remove)
      end
      
      up_door.write_to_rom()
      down_door.write_to_rom()
    end
  end
  
  def get_biggest_door_gap(door)
    coll = RoomCollision.new(door.room, game.fs)
    
    tiles = []
    
    case door.direction
    when :left, :right
      if door.direction == :left
        x = 0
      else
        x = door.x_pos*SCREEN_WIDTH_IN_TILES - 1
      end
      
      y_start = door.y_pos*SCREEN_HEIGHT_IN_TILES
      (y_start..y_start+SCREEN_HEIGHT_IN_TILES-1).each_with_index do |y, i|
        is_solid = coll[x*0x10,y*0x10].is_solid?
        tiles << {is_solid: is_solid, i: i, x: x, y: y}
      end
    when :up, :down
      if door.direction == :up
        y = 0
      else
        y = door.y_pos*SCREEN_HEIGHT_IN_TILES - 1
      end
      
      x_start = door.x_pos*SCREEN_WIDTH_IN_TILES
      (x_start..x_start+SCREEN_WIDTH_IN_TILES-1).each_with_index do |x, i|
        is_solid = coll[x*0x10,y*0x10].is_solid?
        tiles << {is_solid: is_solid, i: i, x: x, y: y}
      end
    end
    
    chunks = tiles.chunk{|tile| tile[:is_solid]}
    gaps = chunks.select{|is_solid, tiles| !is_solid}
    tiles_in_biggest_gap = gaps.max_by{|is_solid, tiles| tiles.length}[1]
    first_tile_i = tiles_in_biggest_gap.first[:i]
    last_tile_i = tiles_in_biggest_gap.last[:i]
    
    return [first_tile_i, last_tile_i, tiles_in_biggest_gap]
  end
  
  def block_off_tiles(room, tiles)
    coll_layer = room.layers.first
    coll_tileset = CollisionTileset.new(coll_layer.collision_tileset_pointer, game.fs)
    solid_tile = coll_tileset.tiles.find{|tile| tile.is_solid?}
    solid_tile_index_on_tileset = coll_tileset.tiles.index(solid_tile)
    
    tiles.each do |tile|
      tile_i = tile[:x] + tile[:y]*SCREEN_WIDTH_IN_TILES*coll_layer.width
      coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
      coll_layer.tiles[tile_i].horizontal_flip = false
    end
    coll_layer.write_to_rom()
  end
  
  def randomize_doors_no_overlap(&block)
    # TEST SEED: GrandGraveSoup
    
    @transition_rooms = game.get_transition_rooms()
    
    maps_rendered = 0
    
    castle_rooms = []
    abyss_rooms = []
    game.each_room do |room|
      case room.sector_index
      when 0..9
        castle_rooms << room
      when 0xA..0xB
        abyss_rooms << room
      end
    end
    
    randomize_doors_no_overlap_for_area(castle_rooms, 64, 45, @starting_room)
    randomize_doors_no_overlap_for_area(abyss_rooms, 18, 25, game.room_by_str("00-0B-00"))
  end
  
  def randomize_doors_no_overlap_for_area(area_rooms, map_width, map_height, area_starting_room)
    map_spots = Array.new(map_width) { Array.new(map_height) }
    unplaced_transition_rooms = game.get_transition_rooms()
    placed_transition_rooms = []
    unreachable_subroom_doors = []
    
    sectors_done = 0
    total_sectors = 10
    
    area_rooms.each do |room|
      # Move the rooms off the edge of the map before they're placed so they don't interfere.
      room.room_xpos_on_map = 63
      room.room_ypos_on_map = 47
      room.write_to_rom()
    end
    
    sectors_for_area = area_rooms.group_by{|room| room.sector_index}
    
    if GAME == "dos" && sectors_for_area[0xA]
      # Menace. Don't try to connect this room since it has no doors, just place it first at the normal position since the center of the Abyss map doesn't like other tiles being there anyway.
      room = sectors_for_area[0xA].first
      room_x = 7
      room_y = 10
      room.room_xpos_on_map = room_x
      room.room_ypos_on_map = room_y
      room.write_to_rom()
      (room_x..room_x+room.width-1).each do |tile_x|
        (room_y..room_y+room.height-1).each do |tile_y|
          map_spots[tile_x][tile_y] = room
        end
      end
      
      sectors_for_area.delete(0xA)
    end
    
    sectors_for_area.each do |sector_index, sector_rooms|
      randomize_doors_no_overlap_for_sector(sector_index, sector_rooms, map_spots, map_width, map_height, area_starting_room, unplaced_transition_rooms, placed_transition_rooms, unreachable_subroom_doors)
    
      sectors_done += 1
      percent_done = sectors_done.to_f / total_sectors
      #yield percent_done
    end
    
    connect_doors_based_on_map(map_spots, map_width, map_height)
  end
  
  def randomize_doors_no_overlap_for_sector(sector_index, sector_rooms, map_spots, map_width, map_height, area_starting_room, unplaced_transition_rooms, placed_transition_rooms, unreachable_subroom_doors)
    puts "ON SECTOR: #{sector_index}"
    
    sector_rooms.select! do |room|
      next if room.layers.empty?
      next if room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}.empty?
      next if @transition_rooms.include?(room)
      
      true
    end
    
    if sector_index != area_starting_room.sector_index
      #return
      
      open_transition_rooms = placed_transition_rooms.select do |room|
        x = room.room_xpos_on_map
        y = room.room_ypos_on_map
        if x > 0 && map_spots[x-1][y].nil?
          true
        elsif x < map_width-1 && map_spots[x+1][y].nil?
          true
        else
          false
        end
      end
      
      if open_transition_rooms.empty?
        puts "no transition room to use as a base!"
        return
      end
      
      transition_room_to_start_sector = open_transition_rooms.sample(random: rng)
    end
    failed_room_counts = Hash.new(0)
    transition_rooms_in_this_sector = unplaced_transition_rooms.sample(2, random: rng)
    puts "Total sector rooms available to place: #{sector_rooms.size}"
    puts "Transition rooms to place: #{transition_rooms_in_this_sector.size}"
    #puts "Which non-transition rooms to place: #{sector_rooms.map{|x| x.room_str}.join(", ")}"
    #puts "Which transition rooms to place: #{transition_rooms_in_this_sector.map{|x| x.room_str}.join(", ")}"
    sector_rooms += transition_rooms_in_this_sector
    
    # TODO: keep list of all locations on the map that are currently open to place rooms at (number of empty spots next to a door on this sector)
    # then we just use this to improve performance instead of recalculating everything every time. we just add and delete from this list.
    
    # TODO: don't place a room in a given spot if doing so would waste more open door spots than it adds (room's walls overlap more unused doors than this room's number of doors that would touch an empty spot)
    
    # TODO: instead of selecting room to place, then finding all valid spots to place it, then picking one at random, let's use a different method:
    # shuffle the list of all currently open doors we can use. then go through these, and for each spot, go through a shuffled list of each room we can place, and check if we can place it.
    # but we also need to account for the difference in open doors (+/- the total number of open doors after placing this room) and take that into account somehow.
    
    num_placed_non_transition_rooms = 0
    num_placed_transition_rooms = 0
    on_starting_room = (sector_index == 0)
    while true
      if on_starting_room
        on_starting_room = false
        room = area_starting_room
      else
        #p "sector_rooms: #{sector_rooms.size}"
        #p "sector_rooms transitions: #{(sector_rooms & @transition_rooms).size}"
        break if sector_rooms.empty?
        
        room = select_next_room_to_place(sector_rooms)
      end
      sector_rooms.delete(room)
      
      if room == area_starting_room && GAME == "dos" && area_starting_room.sector_index == 0xB
        # Placing the first room, in the Abyss.
        # Can't place any rooms too close to the center where Menace's room is. Also don't place it too close to the map edges.
        non_center_spots = (2..5).to_a + (11..15).to_a
        start_x = non_center_spots.sample(random: rng)
        start_y = non_center_spots.sample(random: rng)
        valid_spots = [[start_x, start_y]]
      elsif room == area_starting_room
        # Placing the first room. Place it somewhere random, but not too close to the map edges.
        start_x = rng.rand(5..map_width-5)
        start_y = rng.rand(5..map_height-5)
        valid_spots = [[start_x, start_y]]
      elsif @transition_rooms.include?(room)
        valid_spots = get_valid_positions_for_room(room, map_spots, map_width, map_height, limit_connections_to_sector: sector_index, transition_room_to_allow_connecting_to: transition_room_to_start_sector, unreachable_subroom_doors: unreachable_subroom_doors)
      else
        valid_spots = get_valid_positions_for_room(room, map_spots, map_width, map_height, transition_room_to_allow_connecting_to: transition_room_to_start_sector, unreachable_subroom_doors: unreachable_subroom_doors)
      end
      
      #p valid_spots.size if sector_index == 5 && valid_spots.size > 0
      
      if valid_spots.empty?
        if failed_room_counts[room] > 2
          # Already skipped this room a lot. Don't give it any more chances.
          #print 'X'
          next
        else
          failed_room_counts[room] += 1
          # Give the room another try eventually.
          #print 'x'
          sector_rooms << room
          next
        end
      end
      
      if unplaced_transition_rooms.include?(room)
        unplaced_transition_rooms.delete(room)
        placed_transition_rooms << room
        num_placed_transition_rooms += 1
      else
        num_placed_non_transition_rooms += 1
      end
      
      chosen_spot = valid_spots.sample(random: rng)
      
      #if @transition_rooms.include?(room)
      #  puts "PLACING TRANSITION #{room.room_str}. in unplaced_transition_rooms?: #{unplaced_transition_rooms.include?(room)} chosen spot: #{chosen_spot.inspect}, valid spots: #{valid_spots.inspect}"
      #end
      room_x = chosen_spot[0]
      room_y = chosen_spot[1]
      room.room_xpos_on_map = room_x
      room.room_ypos_on_map = room_y
      room.write_to_rom()
      (room_x..room_x+room.width-1).each do |tile_x|
        (room_y..room_y+room.height-1).each do |tile_y|
          map_spots[tile_x][tile_y] = room
        end
      end
      
      door_strs_accessible_in_this_room = chosen_spot[2]
      subrooms_in_room = checker.subrooms_doors_only[room.room_str]
      if subrooms_in_room
        subrooms_in_room.each do |door_indexes_in_subroom|
          door_strs_in_subroom = door_indexes_in_subroom.map{|door_index| "#{room.room_str}_%03X" % door_index}
          #p "SUBROOM: #{door_strs_in_subroom}"
          if (door_strs_in_subroom & door_strs_accessible_in_this_room).empty?
            # None of the doors in this subroom are connected on the map yet. So mark all the doors in this subroom as being inaccessible.
            unreachable_subroom_doors += door_strs_in_subroom
            #puts "ROOM #{room.room_str} HAS INACCESSIBLE SUBROOMS"
            
            # TODO: what about if we gain access to this subroom via a room placed later in the logic?
          end
        end
      end
      
      #if @transition_rooms.include?(room)
      #  regenerate_map()
      #  gets
      #end
      
      #regenerate_map(maps_rendered)
      #maps_rendered += 1
    end
    
    puts "Successfully placed non-transition rooms: #{num_placed_non_transition_rooms}"
    puts "Successfully placed transition rooms: #{num_placed_transition_rooms}"
  end
  
  def select_next_room_to_place(rooms)
    rooms_by_num_doors = rooms.group_by do |room|
      room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
      room_doors.size
    end
    
    rooms_with_several_doors = rooms_by_num_doors.select{|num_doors, rooms| num_doors >= 3}
    
    progress_important_rooms = rooms & checker.progress_important_rooms
    
    transition_rooms = rooms & @transition_rooms
    
    if rooms_with_several_doors.any?
      max_num_doors = rooms_by_num_doors.keys.max
      rooms_with_max_doors = rooms_by_num_doors[max_num_doors]
      rooms_to_choose_from = rooms_with_max_doors
    elsif progress_important_rooms.any?
      rooms_to_choose_from = progress_important_rooms
    elsif transition_rooms.any?
      rooms_to_choose_from = transition_rooms
    else
      rooms_to_choose_from = rooms
    end
    
    room = rooms_to_choose_from.sample(random: rng)
    return room
  end
  
  def connect_doors_based_on_map(map_spots, map_width, map_height)
    # TODO: don't connect doors from different sectors that just happen to overlap
    
    done_doors = []
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    map_spots.each_with_index do |col, x|
      col.each_with_index do |room, y|
        next if room.nil?
        
        # Choose the solid tile to use to block off doors we remove.
        room.sector.load_necessary_overlay()
        coll_layer = room.layers.first
        coll_tileset = CollisionTileset.new(coll_layer.collision_tileset_pointer, game.fs)
        solid_tile = coll_tileset.tiles.find{|tile| tile.is_solid?}
        solid_tile_index_on_tileset = coll_tileset.tiles.index(solid_tile)
        coll = RoomCollision.new(room, game.fs)
        
        x_in_room = x - room.room_xpos_on_map
        y_in_room = y - room.room_ypos_on_map
        room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        
        if x_in_room == 0
          left_door = room_doors.find{|door| door.direction == :left && door.y_pos == y_in_room}
        end
        if x_in_room == room.width - 1
          right_door = room_doors.find{|door| door.direction == :right && door.y_pos == y_in_room}
        end
        if y_in_room == 0
          up_door = room_doors.find{|door| door.direction == :up && door.x_pos == x_in_room}
        end
        if y_in_room == room.height - 1
          down_door = room_doors.find{|door| door.direction == :down && door.x_pos == x_in_room}
        end
        
        if left_door && !done_doors.include?(left_door)
          done_doors << left_door
          
          if x > 0 && map_spots[x-1][y]
            dest_room = map_spots[x-1][y]
            y_in_dest_room = y - dest_room.room_ypos_on_map
            dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
            right_dest_door = dest_room_doors.find{|door| door.direction == :right && door.y_pos == y_in_dest_room}
          end
          
          if right_dest_door
            # Connect these two doors that are touching on the map.
            done_doors << right_dest_door
            
            queued_door_changes[left_door]["destination_room_metadata_ram_pointer"] = right_dest_door.room.room_metadata_ram_pointer
            queued_door_changes[left_door]["dest_x"] = (right_dest_door.x_pos-1) * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[left_door]["dest_y"] = right_dest_door.y_pos * SCREEN_HEIGHT_IN_PIXELS
            
            queued_door_changes[right_dest_door]["destination_room_metadata_ram_pointer"] = left_door.room.room_metadata_ram_pointer
            queued_door_changes[right_dest_door]["dest_x"] = 0
            queued_door_changes[right_dest_door]["dest_y"] = left_door.y_pos * SCREEN_HEIGHT_IN_PIXELS
            
            left_door.write_to_rom()
            right_dest_door.write_to_rom()
          else
            # No matching door. Block this door off.
            tile_x = 0
            tile_start_y = left_door.y_pos*SCREEN_HEIGHT_IN_TILES
            (tile_start_y..tile_start_y+SCREEN_HEIGHT_IN_TILES-1).each do |tile_y|
              next if coll[tile_x*0x10,tile_y*0x10].is_solid?
              tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
              coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
              coll_layer.tiles[tile_i].horizontal_flip = false
            end
            coll_layer.write_to_rom()
            
            left_door.destination_room_metadata_ram_pointer = 0
            left_door.x_pos = room.width + 1
            left_door.y_pos = room.height + 1
            left_door.write_to_rom()
            checker.add_inaccessible_door(left_door)
          end
        end
        
        if right_door && !done_doors.include?(right_door)
          done_doors << right_door
          
          if x < map_width-1 && map_spots[x+1][y]
            dest_room = map_spots[x+1][y]
            y_in_dest_room = y - dest_room.room_ypos_on_map
            dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
            left_dest_door = dest_room_doors.find{|door| door.direction == :left && door.y_pos == y_in_dest_room}
          end
          
          if left_dest_door
            # Connect these two doors that are touching on the map.
            done_doors << left_dest_door
            
            queued_door_changes[right_door]["destination_room_metadata_ram_pointer"] = left_dest_door.room.room_metadata_ram_pointer
            queued_door_changes[right_door]["dest_x"] = 0
            queued_door_changes[right_door]["dest_y"] = left_dest_door.y_pos * SCREEN_HEIGHT_IN_PIXELS
            
            queued_door_changes[left_dest_door]["destination_room_metadata_ram_pointer"] = right_door.room.room_metadata_ram_pointer
            queued_door_changes[left_dest_door]["dest_x"] = (right_door.x_pos-1) * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[left_dest_door]["dest_y"] = right_door.y_pos * SCREEN_HEIGHT_IN_PIXELS
            
            right_door.write_to_rom()
            left_dest_door.write_to_rom()
          else
            # No matching door. Block this door off.
            if room.room_str == "00-02-21"
              puts right_door.door_str
              p left_dest_door
              p [x,y]
            end
            tile_x = room.width*SCREEN_WIDTH_IN_TILES-1
            tile_start_y = right_door.y_pos*SCREEN_HEIGHT_IN_TILES
            (tile_start_y..tile_start_y+SCREEN_HEIGHT_IN_TILES-1).each do |tile_y|
              next if coll[tile_x*0x10,tile_y*0x10].is_solid?
              tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
              coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
              coll_layer.tiles[tile_i].horizontal_flip = false
            end
            coll_layer.write_to_rom()
            
            right_door.destination_room_metadata_ram_pointer = 0
            right_door.x_pos = room.width + 1
            right_door.y_pos = room.height + 1
            right_door.write_to_rom()
            checker.add_inaccessible_door(right_door)
          end
        end
        
        if up_door && !done_doors.include?(up_door)
          done_doors << up_door
          
          if y > 0 && map_spots[x][y-1]
            dest_room = map_spots[x][y-1]
            x_in_dest_room = x - dest_room.room_xpos_on_map
            dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
            down_dest_door = dest_room_doors.find{|door| door.direction == :down && door.x_pos == x_in_dest_room}
          end
          
          if down_dest_door
            # Connect these two doors that are touching on the map.
            done_doors << down_dest_door
            
            queued_door_changes[up_door]["destination_room_metadata_ram_pointer"] = down_dest_door.room.room_metadata_ram_pointer
            queued_door_changes[up_door]["dest_x"] = down_dest_door.x_pos * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[up_door]["dest_y"] = (down_dest_door.y_pos-1) * SCREEN_HEIGHT_IN_PIXELS
            
            queued_door_changes[down_dest_door]["destination_room_metadata_ram_pointer"] = up_door.room.room_metadata_ram_pointer
            queued_door_changes[down_dest_door]["dest_x"] = up_door.x_pos * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[down_dest_door]["dest_y"] = 0
            
            up_door.write_to_rom()
            down_dest_door.write_to_rom()
          else
            # No matching door. Block this door off.
            tile_y = 0
            tile_start_x = up_door.x_pos*SCREEN_WIDTH_IN_TILES
            (tile_start_x..tile_start_x+SCREEN_WIDTH_IN_TILES-1).each do |tile_x|
              next if coll[tile_x*0x10,tile_y*0x10].is_solid?
              tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
              coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
              coll_layer.tiles[tile_i].horizontal_flip = false
            end
            coll_layer.write_to_rom()
            
            up_door.destination_room_metadata_ram_pointer = 0
            up_door.x_pos = room.width + 1
            up_door.y_pos = room.height + 1
            up_door.write_to_rom()
            checker.add_inaccessible_door(up_door)
          end
        end
        
        if down_door && !done_doors.include?(down_door)
          done_doors << down_door
          
          if y < map_height-1 && map_spots[x][y+1]
            dest_room = map_spots[x][y+1]
            x_in_dest_room = x - dest_room.room_xpos_on_map
            dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
            up_dest_door = dest_room_doors.find{|door| door.direction == :up && door.x_pos == x_in_dest_room}
          end
          
          if up_dest_door
            # Connect these two doors that are touching on the map.
            done_doors << up_dest_door
            
            queued_door_changes[down_door]["destination_room_metadata_ram_pointer"] = up_dest_door.room.room_metadata_ram_pointer
            queued_door_changes[down_door]["dest_x"] = up_dest_door.x_pos * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[down_door]["dest_y"] = 0
            
            queued_door_changes[up_dest_door]["destination_room_metadata_ram_pointer"] = down_door.room.room_metadata_ram_pointer
            queued_door_changes[up_dest_door]["dest_x"] = down_door.x_pos * SCREEN_WIDTH_IN_PIXELS
            queued_door_changes[up_dest_door]["dest_y"] = (down_door.y_pos-1) * SCREEN_HEIGHT_IN_PIXELS
            
            down_door.write_to_rom()
            up_dest_door.write_to_rom()
          else
            # No matching door. Block this door off.
            tile_y = room.height*SCREEN_HEIGHT_IN_TILES-1
            tile_start_x = down_door.x_pos*SCREEN_WIDTH_IN_TILES
            (tile_start_x..tile_start_x+SCREEN_WIDTH_IN_TILES-1).each do |tile_x|
              next if coll[tile_x*0x10,tile_y*0x10].is_solid?
              tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
              coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
              coll_layer.tiles[tile_i].horizontal_flip = false
            end
            coll_layer.write_to_rom()
            
            down_door.destination_room_metadata_ram_pointer = 0
            down_door.x_pos = room.width + 1
            down_door.y_pos = room.height + 1
            down_door.write_to_rom()
            checker.add_inaccessible_door(down_door)
          end
        end
      end
    end
    
    doors_to_line_up = []
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      unless doors_to_line_up.include?(door.destination_door)
        doors_to_line_up << door
      end
      
      door.write_to_rom()
    end
    
    doors_to_line_up.each do |door|
      #line_up_door(door)
    end
  end
  
  def get_valid_positions_for_room(room, map_spots, map_width, map_height, limit_connections_to_sector: nil, transition_room_to_allow_connecting_to: nil, unreachable_subroom_doors: [])
    valid_spots = []
    transition_rooms_not_allowed_to_connect_to = @transition_rooms - [transition_room_to_allow_connecting_to]
    
    (map_width-room.width+1).times do |room_x|
      (map_height-room.height+1).times do |room_y|
        debug = false
        if room_x == 0x22 && room_y == 0x14 && room.room_str == "00-03-20"
          debug = true
        end
        
        # Don't place rooms right on the edge of the map
        next if room_x == 0
        next if room_y == 0
        next if room_x + room.width - 1 == map_width - 1
        next if room_y + room.height - 1 == map_height - 1
        
        spot_is_free = true
        
        (room_x..room_x+room.width-1).each do |tile_x|
          (room_y..room_y+room.height-1).each do |tile_y|
            if !map_spots[tile_x][tile_y].nil?
              # Spot occupied, don't place another room overlapping it.
              spot_is_free = false
            end
          end
        end
        
        next unless spot_is_free
            
        adjacent_rooms = []
        inside_doors_connecting_to_adjacent_rooms = []
        
        room.width.times do |x_in_room|
          room.height.times do |y_in_room|
            tile_x = room_x + x_in_room
            tile_y = room_y + y_in_room
            room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
            
            left_door = room_doors.find{|door| door.direction == :left && door.y_pos == y_in_room}
            if left_door && tile_x > 0 && map_spots[tile_x-1][tile_y]
              dest_room = map_spots[tile_x-1][tile_y]
              if dest_room.sector_index == room.sector_index || @transition_rooms.include?(dest_room) || @transition_rooms.include?(room)
                y_in_dest_room = tile_y - dest_room.room_ypos_on_map
                #p unreachable_subroom_doors.map{|x| x.door_str} if room.sector_index == 5
                dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
                right_dest_door = dest_room_doors.find{|door| door.direction == :right && door.y_pos == y_in_dest_room}
                if right_dest_door && !transition_rooms_not_allowed_to_connect_to.include?(dest_room)
                  adjacent_rooms << dest_room
                  inside_doors_connecting_to_adjacent_rooms << left_door
                  #puts "connected to the left: #{dest_room.room_str}" if debug
                end
              end
            end
            
            right_door = room_doors.find{|door| door.direction == :right && door.y_pos == y_in_room}
            if right_door && tile_x < map_width-1 && map_spots[tile_x+1][tile_y]
              dest_room = map_spots[tile_x+1][tile_y]
              if dest_room.sector_index == room.sector_index || @transition_rooms.include?(dest_room) || @transition_rooms.include?(room)
                y_in_dest_room = tile_y - dest_room.room_ypos_on_map
                dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
                left_dest_door = dest_room_doors.find{|door| door.direction == :left && door.y_pos == y_in_dest_room}
                if left_dest_door && !transition_rooms_not_allowed_to_connect_to.include?(dest_room)
                  adjacent_rooms << dest_room
                  inside_doors_connecting_to_adjacent_rooms << right_door
                  #puts "connected to the right: #{dest_room.room_str}" if debug
                end
              end
            end
            
            up_door = room_doors.find{|door| door.direction == :up && door.x_pos == x_in_room}
            if up_door && tile_y > 0 && map_spots[tile_x][tile_y-1]
              dest_room = map_spots[tile_x][tile_y-1]
              if dest_room.sector_index == room.sector_index || @transition_rooms.include?(dest_room) || @transition_rooms.include?(room)
                x_in_dest_room = tile_x - dest_room.room_xpos_on_map
                dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
                down_dest_door = dest_room_doors.find{|door| door.direction == :down && door.x_pos == x_in_dest_room}
                if down_dest_door
                  adjacent_rooms << dest_room
                  inside_doors_connecting_to_adjacent_rooms << up_door
                  #puts "connected up: #{dest_room.room_str}" if debug
                end
              end
            end
            
            down_door = room_doors.find{|door| door.direction == :down && door.x_pos == x_in_room}
            if down_door && tile_y < map_height-1 && map_spots[tile_x][tile_y+1]
              dest_room = map_spots[tile_x][tile_y+1]
              if dest_room.sector_index == room.sector_index || @transition_rooms.include?(dest_room) || @transition_rooms.include?(room)
                x_in_dest_room = tile_x - dest_room.room_xpos_on_map
                dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
                up_dest_door = dest_room_doors.find{|door| door.direction == :up && door.x_pos == x_in_dest_room}
                if up_dest_door
                  adjacent_rooms << dest_room
                  inside_doors_connecting_to_adjacent_rooms << down_door
                  #puts "connected down: #{dest_room.room_str}" if debug
                end
              end
            end
            
            #if (tile_x < map_width-1 && map_spots[tile_x+1][tile_y]) ||
            #   (tile_x > 0 && map_spots[tile_x-1][tile_y]) ||
            #   (tile_y < map_height-1 && map_spots[tile_x][tile_y+1]) ||
            #   (tile_y > 0 && map_spots[tile_x][tile_y-1])
            #  # Spot is connected to another room, allow placing a room here.
            #  spot_is_connected = true
            #end
          end
        end
        
        if limit_connections_to_sector && !@transition_rooms.include?(room)
          adjacent_rooms.select! do |adjacent_room|
            adjacent_room.sector_index == limit_connections_to_sector || adjacent_room == transition_room_to_allow_connecting_to
          end
        end
        
        next if adjacent_rooms.empty?
        
        inside_door_strs_connecting_to_adjacent_rooms = inside_doors_connecting_to_adjacent_rooms.map{|door| door.door_str}
        
        valid_spots << [room_x, room_y, inside_door_strs_connecting_to_adjacent_rooms]
      end
    end
    
    return valid_spots
  end
  
  def update_room_positions_on_maps
    unvisited_rooms = []
    game.each_room do |room|
      next if (0xA..0x10).include?(room.sector_index)
      unvisited_rooms << room
    end
    current_room = unvisited_rooms.first
    (unvisited_rooms-[current_room]).each do |room|
      room.room_xpos_on_map = 0
      room.room_ypos_on_map = 0
    end
    rooms_to_do = [current_room]
    done_rooms = []
    while true
      unvisited_rooms.delete(current_room)
      rooms_to_do.delete(current_room)
      
      curr_x = current_room.room_xpos_on_map
      curr_y = current_room.room_ypos_on_map
      
      room_doors = current_room.doors.reject do |door|
        checker.inaccessible_doors.include?(door.door_str)
      end
      room_doors.uniq!{|door| door.destination_door.room}
      room_doors.each do |door|
        dest_door = door.destination_door
        dest_room = dest_door.room
        
        door_x = door.x_pos
        door_x = -1 if door_x == 0xFF
        door_y = door.y_pos
        door_y = -1 if door_y == 0xFF
        dest_door_x = dest_door.x_pos
        dest_door_x = -1 if dest_door_x == 0xFF
        dest_door_y = dest_door.y_pos
        dest_door_y = -1 if dest_door_y == 0xFF
        
        new_x = curr_x + door_x - dest_door_x
        new_y = curr_y + door_y - dest_door_y
        case door.direction
        when :left
          new_x += 1
        when :right
          new_x -= 1
        when :up
          new_y += 1
        when :down
          new_y -= 1
        end
        dest_room.room_xpos_on_map = new_x
        dest_room.room_ypos_on_map = new_y
        
        rooms_to_do << dest_room
      end
      
      current_room.write_to_rom()
      done_rooms << current_room
      
      puts current_room.room_str
      if !unvisited_rooms.find{|x| x.room_str == "00-01-00"}
        puts "!!!"
      end
      
      rooms_to_do = rooms_to_do.uniq & unvisited_rooms
      break if rooms_to_do.empty?
      current_room = rooms_to_do.first
    end
    puts "undone rooms: #{unvisited_rooms.size}"
    unvisited_rooms.each_with_index do |room, i|
      room.room_xpos_on_map = 0#i
      room.room_ypos_on_map = 0
      puts "  #{room.room_str}"
    end
    
    min_x = done_rooms.map{|room| room.room_xpos_on_map}.min
    if min_x < 1
      offset = 1 - min_x
      done_rooms.each do |room|
        room.room_xpos_on_map += offset
        room.room_xpos_on_map = room.room_xpos_on_map % 64 # TODO
        room.write_to_rom()
      end
    end
    min_y = done_rooms.map{|room| room.room_ypos_on_map}.min
    if min_y < 1
      offset = 1 - min_y
      done_rooms.each do |room|
        room.room_ypos_on_map += offset
        room.room_ypos_on_map = room.room_ypos_on_map % 0x30 # TODO
        room.write_to_rom()
      end
    end
    
    #regenerate_map()
    #gets
  end
  
  def regenerate_all_maps
    if GAME == "dos"
      # Fix warps.
      map = game.get_map(0, 0)
      map.warp_rooms.each do |warp|
        next if warp.sector_index == 0xB # Abyss
        
        sector_rooms = game.areas[0].sectors[warp.sector_index].rooms
        room = sector_rooms.find{|room| room.entities.any?{|e| e.is_special_object? && e.subtype == 0x31}}
        warp.x_pos_in_tiles = room.room_xpos_on_map
        warp.y_pos_in_tiles = room.room_ypos_on_map
      end
      map.write_to_rom()
      
      regenerate_map(0, 0)
      regenerate_map(0, 0xB)
    end
  end
  
  def regenerate_map(area_index, map_sector_index, filename_num=nil)
    map = game.get_map(area_index, map_sector_index)
    area = game.areas[area_index]
    
    map.tiles.each do |tile|
      tile.is_blank = true
      
      tile.is_save = false
      tile.is_warp = false
      
      tile.top_secret = false
      tile.top_door = false
      tile.top_wall = false
      tile.left_secret = false
      tile.left_door = false
      tile.left_wall = false
      
      tile.sector_index = nil
      tile.room_index = nil
    end
    map.tiles.each do |tile|
      x, y = tile.x_pos, tile.y_pos
      sector_index, room_index = area.get_sector_and_room_indexes_from_map_x_y(x, y, map.is_abyss)
      
      left_tile = map.tiles.find{|t| t.x_pos == x-1 && t.y_pos == y}
      top_tile = map.tiles.find{|t| t.x_pos == x && t.y_pos == y-1}
      if left_tile && (left_tile.sector_index != sector_index || left_tile.room_index != room_index)
        tile.left_wall = true
      end
      if top_tile && (top_tile.sector_index != sector_index || top_tile.room_index != room_index)
        tile.top_wall = true
      end
      
      if left_tile && left_tile.sector_index && (left_tile.sector_index != sector_index || left_tile.room_index != room_index)
        left_room = game.areas[0].sectors[left_tile.sector_index].rooms[left_tile.room_index]
        y_in_dest_room = y - left_room.room_ypos_on_map
        room_doors = left_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        right_door = room_doors.find{|door| door.direction == :right && door.y_pos == y_in_dest_room}
        if right_door
          tile.left_wall = false
          tile.left_door = true
        else
          tile.left_wall = true
        end
      end
      if top_tile && top_tile.sector_index && (top_tile.sector_index != sector_index || top_tile.room_index != room_index)
        top_room = game.areas[0].sectors[top_tile.sector_index].rooms[top_tile.room_index]
        x_in_dest_room = x - top_room.room_xpos_on_map
        room_doors = top_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        down_door = room_doors.find{|door| door.direction == :down && door.x_pos == x_in_dest_room}
        if down_door
          tile.top_wall = false
          tile.top_door = true
        else
          tile.top_wall = true
        end
      end
      
      if sector_index
        room = area.sectors[sector_index].rooms[room_index]
        
        tile.is_blank = false
        
        tile.is_save = room.entities.any?{|e| e.is_special_object? && e.subtype == 0x30}
        tile.is_warp = room.entities.any?{|e| e.is_special_object? && e.subtype == 0x31}
        
        tile.sector_index = sector_index
        tile.room_index = room_index
        
        room_doors = room.doors.reject do |door|
          checker.inaccessible_doors.include?(door.door_str)
        end
        tile_y_offset_in_room = tile.y_pos - room.room_ypos_on_map
        if tile.left_wall && room_doors.find{|door| door.direction == :left && door.y_pos == tile_y_offset_in_room}
          tile.left_door = true
          tile.left_wall = false
        end
        tile_x_offset_in_room = tile.x_pos - room.room_xpos_on_map
        if tile.top_wall && room_doors.find{|door| door.direction == :up && door.x_pos == tile_x_offset_in_room}
          tile.top_door = true
          tile.top_wall = false
        end
      end
    end
    map.write_to_rom()
    
    p [area_index, map_sector_index]
    filename = "./logs/maptest %02X-%02X.png" % [area_index, map_sector_index]
    if filename_num
      filename = "./logs/maptest %02X-%02X #{filename_num}.png" % [area_index, map_sector_index]
    end
    renderer.render_map(map, scale=3, hardcoded_transition_rooms=@transition_rooms).save(filename)
  end
end
