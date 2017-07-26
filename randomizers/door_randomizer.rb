
module DoorRandomizer
  def randomize_transition_doors
    transition_rooms = game.get_transition_rooms()
    remaining_transition_rooms = transition_rooms.dup
    remaining_transition_rooms.reject! do |room|
      FAKE_TRANSITION_ROOMS.include?(room.room_metadata_ram_pointer)
    end
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    transition_rooms.shuffle(random: rng).each_with_index do |transition_room, i|
      next unless remaining_transition_rooms.include?(transition_room) # Already randomized this room
      
      remaining_transition_rooms.delete(transition_room)
      
      # Transition rooms can only lead to rooms in the same area or the game will crash.
      remaining_transition_rooms_for_area = remaining_transition_rooms.select do |other_room|
        transition_room.area_index == other_room.area_index
      end
      
      if remaining_transition_rooms_for_area.length == 0
        # There aren't any more transition rooms left in this area to randomize with.
        # This is because the area had an odd number of transition rooms, so not all of them can be swapped.
        next
      end
      
      # Only randomize one of the doors, no point in randomizing them both.
      inside_door = transition_room.doors.first
      old_outside_door = inside_door.destination_door
      transition_room_to_swap_with = remaining_transition_rooms_for_area.sample(random: rng)
      remaining_transition_rooms.delete(transition_room_to_swap_with)
      inside_door_to_swap_with = transition_room_to_swap_with.doors.first
      new_outside_door = inside_door_to_swap_with.destination_door
      
      queued_door_changes[inside_door]["destination_room_metadata_ram_pointer"] = inside_door_to_swap_with.destination_room_metadata_ram_pointer
      queued_door_changes[inside_door]["dest_x"] = inside_door_to_swap_with.dest_x
      queued_door_changes[inside_door]["dest_y"] = inside_door_to_swap_with.dest_y
      
      queued_door_changes[inside_door_to_swap_with]["destination_room_metadata_ram_pointer"] = inside_door.destination_room_metadata_ram_pointer
      queued_door_changes[inside_door_to_swap_with]["dest_x"] = inside_door.dest_x
      queued_door_changes[inside_door_to_swap_with]["dest_y"] = inside_door.dest_y
      
      queued_door_changes[old_outside_door]["destination_room_metadata_ram_pointer"] = new_outside_door.destination_room_metadata_ram_pointer
      queued_door_changes[old_outside_door]["dest_x"] = new_outside_door.dest_x
      queued_door_changes[old_outside_door]["dest_y"] = new_outside_door.dest_y
      
      queued_door_changes[new_outside_door]["destination_room_metadata_ram_pointer"] = old_outside_door.destination_room_metadata_ram_pointer
      queued_door_changes[new_outside_door]["dest_x"] = old_outside_door.dest_x
      queued_door_changes[new_outside_door]["dest_y"] = old_outside_door.dest_y
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
    
    # Remove breakable walls and similar things that prevent you from going in certain doors.
    remove_door_blockers()
    
    @transition_rooms = game.get_transition_rooms()
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      area.sectors.each do |sector|
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
          
          all_rooms = remaining_doors.values.flatten.map{|door| door.room}.uniq
          if all_rooms.empty?
            # No doors in this sector
            next
          end
          unvisited_rooms = all_rooms.dup
          accessible_remaining_doors = []
          
          current_room = unvisited_rooms.sample(random: rng)
          
          while true
            debug = false
            debug = (area.area_index == 0 && sector.sector_index == 9)
            debug = true
            
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
              door.room.doors.length > 1 && unvisited_rooms.include?(door.room)
            end
            
            inaccessible_remaining_matching_doors_with_other_direction_exits = inaccessible_remaining_matching_doors_with_other_exits.select do |door|
              if door.direction == :left || door.direction == :right
                door.room.doors.any?{|x| x.direction == :up || x.direction == :down}
              else
                door.room.doors.any?{|x| x.direction == :left || x.direction == :right}
              end
            end
            
            # TODO: prioritize even higher a type 0 where it there's a room with an area exit.
            if inaccessible_remaining_matching_doors_with_other_direction_exits.any?
              # There are doors we can swap with that allow more progress, and also allow going in a new direction (up/down vs left/right).
              possible_dest_doors = inaccessible_remaining_matching_doors_with_other_direction_exits
              
              puts "TYPE 1" if debug
            elsif inaccessible_remaining_matching_doors_with_other_exits.any?
              # There are doors we can swap with that allow more progress.
              possible_dest_doors = inaccessible_remaining_matching_doors_with_other_exits
              
              puts "TYPE 2" if debug
            elsif inaccessible_remaining_matching_doors.any?
              # There are doors we can swap with that will allow you to reach one new room which is a dead end.
              possible_dest_doors = inaccessible_remaining_matching_doors
              
              puts "TYPE 3" if debug
            elsif remaining_doors[inside_door_opposite_direction].any?
              # This door direction doesn't have any more matching doors left to swap with that will result in progress.
              # So just pick any matching door.
              possible_dest_doors = remaining_doors[inside_door_opposite_direction]
              
              puts "TYPE 4" if debug
            else
              # This door direction doesn't have any matching doors left.
              # Don't do anything to this door.
              
              puts "TYPE 5" if debug
              
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
            
            new_dest_door = possible_dest_doors.sample(random: rng)
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
      [0x43, 0x44, 0x46, 0x57, 0x1E, 0x2B, 0x26, 0x2A, 0x29, 0x45, 0x27, 0x24, 0x37, 0x04, 0x05]
    when "por"
      [0x37, 0x30, 0x3B, 0x89]
    when "ooe"
      [0x5C]
    end
    
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_special_object? && obj_subtypes_to_remove.include?(entity.subtype)
          entity.type = 0
          entity.write_to_rom()
        end
      end
    end
    
    if GAME == "dos"
      drawbridge_room_waterlevel = game.areas[0].sectors[0].rooms[0x15].entities[4]
      drawbridge_room_waterlevel.type = 0
      drawbridge_room_waterlevel.write_to_rom()
    end
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
  
  def regenerate_map
    map = game.get_map(0, 0)
    area = game.areas[0]
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
      sector_index, room_index = area.get_sector_and_room_indexes_from_map_x_y(x, y)
      
      left_tile = map.tiles.find{|t| t.x_pos == x-1 && t.y_pos == y}
      top_tile = map.tiles.find{|t| t.x_pos == x && t.y_pos == y-1}
      #tile.top_secret = false
      #tile.top_door = false
      #tile.top_wall = false
      #tile.left_secret = false
      #tile.left_door = false
      #tile.left_wall = false
      if left_tile && (left_tile.sector_index != sector_index || left_tile.room_index != room_index)
        tile.left_wall = true
      end
      if top_tile && (top_tile.sector_index != sector_index || top_tile.room_index != room_index)
        tile.top_wall = true
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
    Renderer.new(game.fs).render_map(map, scale=3).save("maptest.png")
  end
end
