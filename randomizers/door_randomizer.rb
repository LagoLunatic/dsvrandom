
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
    # TODO: make sure every room in an area is accessible. this is to prevent infinite loops of a small number of rooms that connect to each other with no way to progress.
    # loop through each room. search for remaining rooms that have a matching door. but the room we find must also have remaining doors in it besides the one we swap with so it's not a dead end, or a loop. if there are no rooms that meet those conditions, then we go with the more lax condition of just having a matching door, allowing dead ends.
    
    transition_rooms = game.get_transition_rooms()
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      area.sectors.each do |sector|
        puts "SECTOR #{sector.sector_index}"
        remaining_doors = {
          left: [],
          up: [],
          right: [],
          down: []
        }
        
        map = game.get_map(sector.area_index, sector.sector_index)
        
        sector.rooms.each do |room|
          next if transition_rooms.include?(room)
          
          room.doors.each do |door|
            next if transition_rooms.include?(door.destination_door.room)
            
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
            
            # If the door is a secret door, or is shown on the map as a wall, skip it.
            # The player won't be able to enter secret doors from the wrong side, they'd just get stopped by the breakable wall.
            # As for ones shown as a normal wall, those are leftover doors not intended to be used, and are inaccessible (except with warp glitches).
            case door.direction
            when :left
              if map_tile.left_secret || map_tile.left_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, LEFT" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.left_secret || map_tile.left_wall
            when :right
              if map_tile.right_secret || map_tile.right_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, RIGHT" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.right_secret || map_tile.right_wall
            when :up
              if map_tile.top_secret || map_tile.top_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, UP" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.top_secret || map_tile.top_wall
            when :down
              if map_tile.bottom_secret || map_tile.bottom_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, DOWN" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.bottom_secret || map_tile.bottom_wall
            end
            
            remaining_doors[door.direction] << door
          end
        end
        
        all_rooms = remaining_doors.values.flatten.map{|door| door.room}.uniq
        if all_rooms.empty?
          # No doors in this sector
          next
        end
        unvisited_rooms = all_rooms.dup
        accessible_remaining_doors = []
        
        current_room = unvisited_rooms.sample(random: rng)
        
        while true
          puts "on room %08X" % current_room.room_metadata_ram_pointer
          unvisited_rooms.delete(current_room)
          
          accessible_remaining_doors += remaining_doors.values.flatten.select{|door| door.room == current_room}
          accessible_remaining_doors.uniq!
          
          inside_door = accessible_remaining_doors.sample(random: rng)
          remaining_doors[inside_door.direction].delete(inside_door)
          
          inaccessible_remaining_matching_doors = remaining_doors[inside_door.direction] - accessible_remaining_doors
          
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
          
          if inaccessible_remaining_matching_doors_with_other_direction_exits.any?
            # There are doors we can swap with that allow more progress, and also allow going in a new direction (up/down vs left/right).
            possible_swap_doors = inaccessible_remaining_matching_doors_with_other_direction_exits
          elsif inaccessible_remaining_matching_doors_with_other_exits.any?
            # There are doors we can swap with that allow more progress.
            possible_swap_doors = inaccessible_remaining_matching_doors_with_other_exits
          elsif inaccessible_remaining_matching_doors.any?
            # There are doors we can swap with that will allow you to reach one new room which is a dead end.
            possible_swap_doors = inaccessible_remaining_matching_doors
          elsif remaining_doors[inside_door.direction].any?
            # This door direction doesn't have any more matching doors left to swap with that will result in progress.
            # So just pick any matching door.
            possible_swap_doors = remaining_doors[inside_door.direction]
          else
            # This door direction doesn't have any matching doors left.
            # Don't do anything to this door.
            
            #puts "#{inside_door.direction} empty"
            #
            #accessible_rooms = accessible_remaining_doors.map{|door| door.room}.uniq
            #accessible_rooms -= [current_room]
            #
            #current_room = accessible_rooms.sample(random: rng)
            #p accessible_remaining_doors.size
            #gets
            
            current_room = unvisited_rooms.sample(random: rng)
            p "3 #{current_room}"
            
            if current_room.nil?
              current_room = all_rooms.sample(random: rng)
              p "2 #{current_room}"
            end
            
            if remaining_doors.values.flatten.empty?
              break
            end
            
            next
          end
          
          inside_door_to_swap_with = possible_swap_doors.sample(random: rng)
          remaining_doors[inside_door_to_swap_with.direction].delete(inside_door_to_swap_with)
          current_room = inside_door_to_swap_with.room
          p "1 #{current_room}"
          
          old_outside_door = inside_door.destination_door
          remaining_doors[old_outside_door.direction].delete(old_outside_door)
          new_outside_door = inside_door_to_swap_with.destination_door
          remaining_doors[new_outside_door.direction].delete(new_outside_door)
          
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
      end
    end
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      door.write_to_rom()
    end
  end
end
