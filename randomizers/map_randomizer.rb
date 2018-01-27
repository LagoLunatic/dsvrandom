
module MapRandomizer
  def randomize_doors_no_overlap(&block)
    # TEST SEED: GrandGraveSoup
    
    @transition_rooms = game.get_transition_rooms()
    
    @rooms_unused_by_map_rando = []
    
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
    
    starting_room = game.areas[0].sectors[0].rooms[1] # TODO dummy starting room for DoS, need to select a proper one somehow
    randomize_doors_no_overlap_for_area(castle_rooms, 64, 45, starting_room)
    #randomize_doors_no_overlap_for_area(abyss_rooms, 18, 25, game.room_by_str("00-0B-00")) # TODO abyss doesn't randomize properly since it's so small
    
    replace_outer_boss_doors()
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
    
    remove_useless_transition_rooms(map_spots, map_width, map_height, placed_transition_rooms)
    
    connect_doors_based_on_map(map_spots, map_width, map_height)
    
    replace_wooden_doors(placed_transition_rooms)
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
    unplaced_sector_rooms = []
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
      debug = false
      #debug = (sector_index == 0xB)
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
      
      puts "Trying to place room: #{room.room_str}" if debug
      
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
      
      puts "Valid spots: #{valid_spots}" if debug
      
      if valid_spots.empty?
        if failed_room_counts[room] > 2
          # Already skipped this room a lot. Don't give it any more chances.
          #print 'X'
          unplaced_sector_rooms << room
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
      
      puts "Successfully placed #{room.room_str} at #{chosen_spot}" if debug
      
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
    
    # Keep track of the rooms we never used.
    @rooms_unused_by_map_rando += unplaced_sector_rooms
    
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
  
  def remove_useless_transition_rooms(map_spots, map_width, map_height, placed_transition_rooms)
    # Transition rooms are only useful if they connect properly on both the left and right.
    # Otherwise they not only useless but also can bug the game out since they're not designed to have only 1 door.
    # So we remove any transition rooms we placed, but never connected a second room to.
    removed_transition_rooms = []
    
    placed_transition_rooms.each do |transition_room|
      has_unmatched_doors = false
      x = transition_room.room_xpos_on_map
      y = transition_room.room_ypos_on_map
      
      transition_room.doors.each do |door|
        matching_dest_door = find_matching_dest_door_on_map(door.direction, map_spots, map_width, map_height, x, y)
        if matching_dest_door.nil?
          has_unmatched_doors = true
          break
        end
      end
      
      if has_unmatched_doors
        # Remove the transition room from the map.
        map_spots[x][y] = nil
        transition_room.room_xpos_on_map = 63
        transition_room.room_ypos_on_map = 47
        transition_room.write_to_rom()
        
        removed_transition_rooms << transition_room
      end
    end
    
    # Also updated the list of placed transition rooms so it doesn't include these anymore.
    removed_transition_rooms.each do |removed_transition_room|
      placed_transition_rooms.delete(removed_transition_room)
    end
  end
  
  def find_matching_dest_door_on_map(direction, map_spots, map_width, map_height, x, y)
    case direction
    when :left
      if x > 0 && map_spots[x-1][y]
        dest_room = map_spots[x-1][y]
        y_in_dest_room = y - dest_room.room_ypos_on_map
        dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        right_dest_door = dest_room_doors.find{|door| door.direction == :right && door.y_pos == y_in_dest_room}
      end
      
      return right_dest_door
    when :right
      if x < map_width-1 && map_spots[x+1][y]
        dest_room = map_spots[x+1][y]
        y_in_dest_room = y - dest_room.room_ypos_on_map
        dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        left_dest_door = dest_room_doors.find{|door| door.direction == :left && door.y_pos == y_in_dest_room}
      end
      
      return left_dest_door
    when :up
      if y > 0 && map_spots[x][y-1]
        dest_room = map_spots[x][y-1]
        x_in_dest_room = x - dest_room.room_xpos_on_map
        dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        down_dest_door = dest_room_doors.find{|door| door.direction == :down && door.x_pos == x_in_dest_room}
      end
      
      return down_dest_door
    when :down
      if y < map_height-1 && map_spots[x][y+1]
        dest_room = map_spots[x][y+1]
        x_in_dest_room = x - dest_room.room_xpos_on_map
        dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        up_dest_door = dest_room_doors.find{|door| door.direction == :up && door.x_pos == x_in_dest_room}
      end
      
      return up_dest_door
    end
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
          
          right_dest_door = find_matching_dest_door_on_map(:left, map_spots, map_width, map_height, x, y)
          
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
            unless @transition_rooms.include?(room)
              tile_x = 0
              tile_start_y = left_door.y_pos*SCREEN_HEIGHT_IN_TILES
              (tile_start_y..tile_start_y+SCREEN_HEIGHT_IN_TILES-1).each do |tile_y|
                next if coll[tile_x*0x10,tile_y*0x10].is_solid?
                tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
                coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
                coll_layer.tiles[tile_i].horizontal_flip = false
              end
              coll_layer.write_to_rom()
            end
            
            left_door.destination_room_metadata_ram_pointer = 0
            left_door.x_pos = room.width + 1
            left_door.y_pos = room.height + 1
            left_door.write_to_rom()
            checker.add_inaccessible_door(left_door)
          end
        end
        
        if right_door && !done_doors.include?(right_door)
          done_doors << right_door
          
          left_dest_door = find_matching_dest_door_on_map(:right, map_spots, map_width, map_height, x, y)
          
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
            unless @transition_rooms.include?(room)
              tile_x = room.width*SCREEN_WIDTH_IN_TILES-1
              tile_start_y = right_door.y_pos*SCREEN_HEIGHT_IN_TILES
              (tile_start_y..tile_start_y+SCREEN_HEIGHT_IN_TILES-1).each do |tile_y|
                next if coll[tile_x*0x10,tile_y*0x10].is_solid?
                tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
                coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
                coll_layer.tiles[tile_i].horizontal_flip = false
              end
              coll_layer.write_to_rom()
            end
            
            right_door.destination_room_metadata_ram_pointer = 0
            right_door.x_pos = room.width + 1
            right_door.y_pos = room.height + 1
            right_door.write_to_rom()
            checker.add_inaccessible_door(right_door)
          end
        end
        
        if up_door && !done_doors.include?(up_door)
          done_doors << up_door
          
          down_dest_door = find_matching_dest_door_on_map(:up, map_spots, map_width, map_height, x, y)
          
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
            unless @transition_rooms.include?(room)
              tile_y = 0
              tile_start_x = up_door.x_pos*SCREEN_WIDTH_IN_TILES
              (tile_start_x..tile_start_x+SCREEN_WIDTH_IN_TILES-1).each do |tile_x|
                next if coll[tile_x*0x10,tile_y*0x10].is_solid?
                tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
                coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
                coll_layer.tiles[tile_i].horizontal_flip = false
              end
              coll_layer.write_to_rom()
            end
            
            up_door.destination_room_metadata_ram_pointer = 0
            up_door.x_pos = room.width + 1
            up_door.y_pos = room.height + 1
            up_door.write_to_rom()
            checker.add_inaccessible_door(up_door)
          end
        end
        
        if down_door && !done_doors.include?(down_door)
          done_doors << down_door
          
          up_dest_door = find_matching_dest_door_on_map(:down, map_spots, map_width, map_height, x, y)
          
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
            unless @transition_rooms.include?(room)
              tile_y = room.height*SCREEN_HEIGHT_IN_TILES-1
              tile_start_x = down_door.x_pos*SCREEN_WIDTH_IN_TILES
              (tile_start_x..tile_start_x+SCREEN_WIDTH_IN_TILES-1).each do |tile_x|
                next if coll[tile_x*0x10,tile_y*0x10].is_solid?
                tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
                coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
                coll_layer.tiles[tile_i].horizontal_flip = false
              end
              coll_layer.write_to_rom()
            end
            
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
      #line_up_door(door) # TODO?
    end
  end
  
  def replace_wooden_doors(placed_transition_rooms)
    # Remove all existing wooden doors.
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_wooden_door?
          entity.type = 0
          entity.write_to_rom()
        end
      end
    end
    
    # Add replacement wooden doors in the proper places.
    placed_transition_rooms.each do |transition_room|
      transition_room.doors.each do |door|
        dest_door = door.destination_door
        dest_room = dest_door.room
        
        gap_start_index, gap_end_index, tiles_in_biggest_gap = get_biggest_door_gap(dest_door)
        gap_end_offset = gap_end_index * 0x10 + 0x10
        
        door_x = door.dest_x
        if door.direction == :left
          door_x += 0xF0
        end
        door_y = door.dest_y + gap_end_offset
        
        dest_room.sector.load_necessary_overlay()
        coll = RoomCollision.new(dest_room, game.fs)
        floor_tile_x = door_x
        if door.direction == :left
          floor_tile_x -= 0x10
        else
          floor_tile_x += 0x10
        end
        if !coll[floor_tile_x,door_y].is_solid?
          # The door wouldn't have a solid tile as ground right before it.
          # This is bad since it would softlock the player when they touch the door and control is taken away from them.
          # So don't add a wooden door here.
          next
        end
        
        new_wooden_door = dest_room.add_new_entity()
        new_wooden_door.x_pos = door_x
        new_wooden_door.y_pos = door_y - 0x20
        
        new_wooden_door.type = 2
        new_wooden_door.subtype = WOODEN_DOOR_SUBTYPE
        
        new_wooden_door.write_to_rom()
      end
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
