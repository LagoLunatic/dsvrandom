
module MapRandomizer
  DOS_WARP_ROOM_STRS = [
    "00-00-18",
    "00-01-3E",
    "00-02-24",
    "00-03-23",
    "00-04-17",
    "00-05-1E",
    "00-05-1F",
    "00-06-20",
    "00-07-10",
    "00-08-21",
    "00-09-1F",
    "00-0B-23",
  ]
  CONDEMNED_TOWER_ROOM_INDEXES = (0..0xC).to_a + [0x19, 0x1A, 0x1C, 0x1E]
  
  def randomize_doors_no_overlap(&block)
    add_extra_helper_rooms()
    
    @rooms_unused_by_map_rando = []
    
    maps_rendered = 0
    
    case GAME
    when "dos"
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
      
      starting_room = game.areas[0].sectors[0].rooms[1] # TODO dummy starting room for DoS, need to select a proper one somehow for starting room rando to work
      randomize_doors_no_overlap_for_area(castle_rooms, 64, 45, starting_room)
      randomize_doors_no_overlap_for_area(abyss_rooms, 18, 25, game.room_by_str("00-0B-00"))
    when "por"
      game.areas.each do |area|
        next if area.area_index >= 0xA
        
        rooms = []
        area.sectors.each do |sector|
          rooms += sector.rooms
        end
        
        starting_room = case area.name
        when "Dracula's Castle"
          area.sectors[0].rooms[0]
        when "City of Haze"
          area.sectors[0].rooms[0x1A]
        when "13th Street"
          area.sectors[0].rooms[7]
        when "Sandy Grave"
          area.sectors[0].rooms[0]
        when "Forgotten City"
          area.sectors[0].rooms[0]
        when "Nation of Fools"
          area.sectors[0].rooms[0x21]
        when "Burnt Paradise"
          area.sectors[0].rooms[0x20]
        when "Forest of Doom"
          area.sectors[0].rooms[0]
        when "Dark Academy"
          area.sectors[1].rooms[6]
        when "Nest of Evil"
          area.sectors[0].rooms[0]
        else
          raise "Invalid area"
        end
        randomize_doors_no_overlap_for_area(rooms, 64, 45, starting_room)
      end
    when "ooe"
      game.areas.each do |area|
        next if area.area_index == 1 # Wygol
        next if area.area_index == 2 # Ecclesia
        next if area.area_index == 0x13 # Epilogue/Boss rush/Practice mode
        
        rooms = []
        area.sectors.each do |sector|
          rooms += sector.rooms
        end
        
        starting_room = case area.name
        when "Dracula's Castle"
          area.sectors[0xC].rooms[0]
        when "Training Hall"
          area.sectors[0].rooms[0]
        when "Ruvas Forest"
          area.sectors[0].rooms[0]
        when "Argila Swamp"
          area.sectors[0].rooms[3]
        when "Kalidus Channel"
          area.sectors[0].rooms[0] # TODO need to do something about kalidus's alternate entrance
        when "Somnus Reef"
          area.sectors[0].rooms[0]
        when "Minera Prison Island"
          area.sectors[0].rooms[0]
        when "Lighthouse"
          area.sectors[0].rooms[0]
        when "Tymeo Mountains"
          area.sectors[0].rooms[0]
        when "Tristis Pass"
          area.sectors[0].rooms[0]
        when "Large Cavern"
          area.sectors[0].rooms[0]
        when "Giant's Dwelling"
          area.sectors[0].rooms[0]
        when "Mystery Manor"
          area.sectors[0].rooms[0xC]
        when "Misty Forest Road"
          area.sectors[0].rooms[8]
        when "Oblivion Ridge"
          area.sectors[1].rooms[6]
        when "Skeleton Cave"
          area.sectors[0].rooms[0]
        when "Monastery"
          area.sectors[1].rooms[0]
        else
          raise "Invalid area"
        end
        randomize_doors_no_overlap_for_area(rooms, 64, 45, starting_room)
      end
    end
    
    replace_outer_boss_doors()
    
    if GAME == "por"
      # Add the white barrier to the transition room before the Throne Room.
      transition_for_throne_room = game.room_by_str("00-0A-17")
      barrier = transition_for_throne_room.add_new_entity()
      barrier.type = 2
      barrier.subtype = 0x81
      barrier.write_to_rom()
      
      # Remove the white barrier from the room that originally had it (and the event and font loader too).
      orig_white_barrier_room = game.room_by_str("00-0A-01")
      [1, 3, 4].each do |entity_index|
        entity = orig_white_barrier_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    end
  end
  
  def add_extra_helper_rooms
    case GAME
    when "por"
      sector = game.areas[0].sectors[9]
      sector.add_new_room()
      room = sector.rooms[-1]
      filename = "./dsvrandom/roomedits/por_map_rando_00-09-04.tmx"
      tiled.read(filename, room)
    end
  end
  
  def randomize_doors_no_overlap_for_area(area_rooms, map_width, map_height, area_starting_room)
    area_index = area_rooms.first.area_index
    map_spots = Array.new(map_width) { Array.new(map_height) }
    unplaced_transition_rooms = @transition_rooms.select{|room| room.area_index == area_index}
    placed_transition_rooms = []
    unreachable_subroom_doors = []
    
    puts "ON AREA: %02X" % area_index
    
    #sectors_done = 0
    #total_sectors = 10
    
    area_rooms.each do |room|
      # Move the rooms off the edge of the map before they're placed so they don't interfere.
      room.room_xpos_on_map = 63
      room.room_ypos_on_map = 47
      room.write_to_rom()
    end
    
    sectors_for_area = area_rooms.group_by{|room| room.sector_index}
    
    if GAME == "dos" && sectors_for_area[0xA]
      # Menace. Don't try to connect this room since it has no doors.
      menace_room = sectors_for_area[0xA].first
      sectors_for_area.delete(0xA)
    end
    
    starting_room_sector = area_starting_room.sector_index
    remaining_sectors_to_place = sectors_for_area.keys
    redo_counts_per_sector = Hash.new(0)
    unplaced_rooms_for_each_sector = {}
    sectors_for_area.keys.each do |sector_index|
      unplaced_rooms_for_each_sector[sector_index] = sectors_for_area[sector_index].select do |room|
        next if room.layers.empty?
        next if room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}.empty?
        next if @transition_rooms.include?(room)
        
        true
      end
    end
    
    on_starting_sector = true
    placement_mode = :placing_skeleton
    while true
      if on_starting_sector
        on_starting_sector = false
        sector_index = starting_room_sector
      else
        sector_index = remaining_sectors_to_place.sample(random: rng)
      end
      
      unplaced_sector_rooms = unplaced_rooms_for_each_sector[sector_index]
      
      orig_unplaced_sector_rooms     = unplaced_sector_rooms.dup
      orig_map_spots                 = Array.new(map_width) { Array.new(map_height) }
      map_spots.each_with_index do |col, x|
        orig_map_spots[x] = col.dup
      end
      orig_unplaced_transition_rooms = unplaced_transition_rooms.dup
      orig_placed_transition_rooms   = placed_transition_rooms.dup
      orig_unreachable_subroom_doors = unreachable_subroom_doors.dup
      
      result = randomize_doors_no_overlap_for_sector(
        sector_index, unplaced_sector_rooms,
        map_spots, map_width, map_height,
        area_starting_room,
        unplaced_transition_rooms, placed_transition_rooms,
        unreachable_subroom_doors,
        placement_mode
      )
      
      if result == :mustredo || (result == :shouldredo && redo_counts_per_sector[sector_index] <= 7)
        if redo_counts_per_sector[sector_index] > 15
          raise "Map randomizer had to redo area %02X sector %02X more than 15 times." % [area_index, sector_index]
        end
        
        unplaced_rooms_for_each_sector[sector_index] = orig_unplaced_sector_rooms
        map_spots                 = orig_map_spots
        unplaced_transition_rooms = orig_unplaced_transition_rooms
        placed_transition_rooms   = orig_placed_transition_rooms
        unreachable_subroom_doors = orig_unreachable_subroom_doors
        
        (orig_unplaced_sector_rooms + orig_unplaced_transition_rooms).each do |room|
          # Any rooms that got placed need to be moved back off the map.
          room.room_xpos_on_map = 63
          room.room_ypos_on_map = 47
          room.write_to_rom()
        end
        
        redo_counts_per_sector[sector_index] += 1
        puts "Map rando is redoing sector #{sector_index} (time #{redo_counts_per_sector[sector_index]})"
        redo
      end
      
      if placement_mode != :placing_skeleton
        # Keep track of the rooms we never used.
        @rooms_unused_by_map_rando += unplaced_sector_rooms
      end
      
      remaining_sectors_to_place.delete(sector_index)
      
      regenerate_map(area_index, sector_index, should_recenter_map: false)
      #gets
      
      #sectors_done += 1
      #percent_done = sectors_done.to_f / total_sectors
      #yield percent_done
      
      if remaining_sectors_to_place.empty?
        if placement_mode == :placing_skeleton
          # Finished placing the skeleton. Now place the dead ends for all sectors.
          placement_mode = :placing_dead_ends
          remaining_sectors_to_place = sectors_for_area.keys
        else
          # Finished placing the dead ends too.
          break
        end
      end
    end
    
    if menace_room
      valid_spots = []
      map_width.times do |x|
        map_height.times do |y|
          valid_placement = true
          (x..x+menace_room.width-1).each do |x_to_check|
            (y..y+menace_room.height-1).each do |y_to_check|
              if !(0..map_width-1).include?(x_to_check) || !(0..map_height-1).include?(y_to_check) || map_spots[x_to_check][y_to_check]
                valid_placement = false
              end
            end
          end
          
          if valid_placement
            valid_spots << [x,y]
          end
        end
      end
      
      if valid_spots.any?
        # Place the Menace room at a random open spot.
        room_x, room_y = valid_spots.sample(random: rng)
        menace_room.room_xpos_on_map = room_x
        menace_room.room_ypos_on_map = room_y
        menace_room.write_to_rom()
        (room_x..room_x+menace_room.width-1).each do |tile_x|
          (room_y..room_y+menace_room.height-1).each do |tile_y|
            map_spots[tile_x][tile_y] = menace_room
          end
        end
      else
        # Do nothing. Leave the Menace room off the map.
      end
    end
    
    @rooms_unused_by_map_rando += unplaced_transition_rooms
    
    remove_useless_transition_rooms(map_spots, map_width, map_height, placed_transition_rooms)
    
    connect_doors_based_on_map(map_spots, map_width, map_height)
    
    replace_wooden_doors(placed_transition_rooms)
  end
  
  def randomize_doors_no_overlap_for_sector(sector_index, unplaced_sector_rooms, map_spots, map_width, map_height, area_starting_room, unplaced_transition_rooms, placed_transition_rooms, unreachable_subroom_doors, placement_mode)
    area_index = area_starting_room.area_index
    
    puts
    puts "ON AREA %02X, SECTOR: %02X" % [area_index, sector_index]
    
    if sector_index != area_starting_room.sector_index && placement_mode == :placing_skeleton
      if GAME == "por" && area_index == 0
        # We need to make sure a Master's Keep transition room connects to the Throne Room so we can put the white barrier in that transition room.
        transition_for_throne_room = game.room_by_str("00-0A-17")
        if sector_index == 9
          unless unplaced_transition_rooms.include?(transition_for_throne_room)
            raise "Transition for Throne Room (00-0A-17) has already been placed."
          end
          transition_room_to_start_sector = transition_for_throne_room
        else
          transition_room_to_start_sector = (unplaced_transition_rooms - [transition_for_throne_room]).sample(random: rng)
        end
      else
        transition_room_to_start_sector = unplaced_transition_rooms.sample(random: rng)
      end
      
      puts "transition_room_to_start_sector: #{transition_room_to_start_sector.room_str} (#{transition_room_to_start_sector.room_xpos_on_map},#{transition_room_to_start_sector.room_ypos_on_map})"
    end
    
    total_sector_rooms = unplaced_sector_rooms.size
    puts "Total sector rooms available to place: #{total_sector_rooms}"
    
    # Method: Go through all open spaces that would connect to a place door, and find rooms that would fit in those spots.
    # Then select one of those rooms at random and place it.
    
    # TODO: don't place a room in a given spot if doing so would waste more open door spots than it adds (room's walls overlap more unused doors than this room's number of doors that would touch an empty spot)
    
    # TODO: the priority for different types of rooms should be like this:
    # 1. rooms that open up more door connection spots than they close.
    #   however, this should only be the #1 priority as long as the current number of open spots are few. when there are a lot, ignore this priotity.
    # 2. transition rooms, boss rooms, and progress important rooms.
    #   however, these rooms should only be placed once a decent percentage of the available rooms for this sector have been placed.
    # 3. other rooms.
    
    # TODO: keep list of all open spots and just add and delete from this list instead of recalculating it from scratch every loop to improve performance.
    
    # TODO: don't place all rooms in a sector at once. this can lead to not enough open spots being left to place the next transition room and sector with it.
    # instead go through and place SOME normal rooms, as well as boss rooms and progress important rooms.
    # go through each sector to ensure some rooms from every sector get placed.
    # then go BACK through each sector (again in random order) and try to place any rooms that didn't get placed.
    
    num_placed_non_transition_rooms = 0
    num_placed_transition_rooms = 0
    if placement_mode == :placing_skeleton
      on_starting_room = (sector_index == area_starting_room.sector_index)
      on_starting_transition_room = !on_starting_room
    else
      on_starting_room = false
      on_starting_transition_room = false
    end
    while true
      debug = false
      #debug = (sector_index == 9)
      #debug = true
      if on_starting_room
        on_starting_room = false
        
        room = area_starting_room
        
        chosen_room_position = {
          room: room,
          x: map_width/2, # Place at the center of the map.
          y: map_height/2,
        }
      elsif on_starting_transition_room
        on_starting_transition_room = false
        
        room = transition_room_to_start_sector
        
        open_spots = get_open_spots(
          map_spots, map_width, map_height,
          unreachable_subroom_doors: unreachable_subroom_doors
        )
        
        total_number_of_open_spots = open_spots.size
        
        p "open_spots: #{open_spots}" if debug
        if open_spots.empty?
          puts "No open spots on the map to place the starting transition room!"
          break
        end
        
        room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
        
        valid_room_positions = []
        open_spots.each do |x, y, dir, dest_room|
          next unless [:left, :right].include?(dir)
          
          if GAME == "por" && area_index == 0 && sector_index == 9
            # When placing the transition to the Throne Room, we need to make sure the open spot faces left.
            # This is because when we add the white barrier, it only works on the left side of the room.
            next unless dir == :right
          end
          
          number_of_spots_opened_up, number_of_spots_closed_up = get_num_spots_opened_and_closed_for_placement(room, room_doors, map_spots, map_width, map_height, open_spots, x, y)
          
          diff_in_num_spots = number_of_spots_opened_up - number_of_spots_closed_up
          
          if (total_number_of_open_spots + diff_in_num_spots) > 0 # Don't allow positions that would block off literally every open spot.
            valid_room_positions << {
              room: room,
              x: x,
              y: y,
              #inside_door_strs_connecting_to_adjacent_rooms: inside_door_strs_connecting_to_adjacent_rooms,
              number_of_spots_opened_up: number_of_spots_opened_up,
              number_of_spots_closed_up: number_of_spots_closed_up,
              diff_in_num_spots: diff_in_num_spots,
            }
          end
        end
        
        puts "Number of valid room positions: #{valid_room_positions.size}" if debug
        if valid_room_positions.empty?
          #puts "No valid room positions!"
          break
        end
        
        chosen_room_position = valid_room_positions.sample(random: rng)
      else
        break if unplaced_sector_rooms.empty?
        
        open_spots = get_open_spots(
          map_spots, map_width, map_height,
          unreachable_subroom_doors: unreachable_subroom_doors,
          transition_room_to_allow_connecting_to: transition_room_to_start_sector
        )
        
        total_number_of_open_spots = open_spots.size
        
        p "open_spots: #{open_spots}" if debug
        
        if open_spots.empty?
          puts "No open spots on the map!"
          break
        end
        
        valid_room_positions = []
        open_spots.each do |x, y, direction, dest_room|
          puts "on spot #{[x, y, direction]} - going to check unplaced_sector_rooms: #{unplaced_sector_rooms.size}" if debug
          unplaced_sector_rooms.each do |room|
            #puts "checking room: #{room.room_str}" if debug
            
            next unless check_rooms_can_be_connected(room, dest_room)
            
            room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
            
            room_doors_to_attach = room_doors.select{|door| door.direction == direction}
            if room_doors_to_attach.empty?
              next
            end
            
            room_doors_to_attach.each do |door|
              case direction
              when :left
                x_to_place_room_at = x
                y_to_place_room_at = y - door.y_pos
              when :right
                x_to_place_room_at = x - room.width + 1
                y_to_place_room_at = y - door.y_pos
              when :up
                x_to_place_room_at = x - door.x_pos
                y_to_place_room_at = y
              when :down
                x_to_place_room_at = x - door.x_pos
                y_to_place_room_at = y - room.height + 1
              end
              
              valid_placement = true
              (x_to_place_room_at..x_to_place_room_at+room.width-1).each do |x_to_check|
                (y_to_place_room_at..y_to_place_room_at+room.height-1).each do |y_to_check|
                  if !(0..map_width-1).include?(x_to_check) || !(0..map_height-1).include?(y_to_check) || map_spots[x_to_check][y_to_check]
                    valid_placement = false
                    break
                  end
                end
                break unless valid_placement
              end
              
              if valid_placement
                number_of_spots_opened_up, number_of_spots_closed_up = get_num_spots_opened_and_closed_for_placement(room, room_doors, map_spots, map_width, map_height, open_spots, x_to_place_room_at, y_to_place_room_at)
                
                diff_in_num_spots = number_of_spots_opened_up - number_of_spots_closed_up
                
                # Keep track of which placements would result in no more spots being open.
                if (total_number_of_open_spots + diff_in_num_spots) > 0
                  would_block_off_all_open_spots = false
                else
                  would_block_off_all_open_spots = true
                end
                
                valid_room_positions << {
                  room: room,
                  x: x_to_place_room_at,
                  y: y_to_place_room_at,
                  inside_door_str_used_to_attach: door.door_str,
                  number_of_spots_opened_up: number_of_spots_opened_up,
                  number_of_spots_closed_up: number_of_spots_closed_up,
                  diff_in_num_spots: diff_in_num_spots,
                  would_block_off_all_open_spots: would_block_off_all_open_spots,
                }
              end
            end
          end
        end
        
        puts "Number of valid room positions: #{valid_room_positions.size}" if debug
        if valid_room_positions.empty?
          #puts "No valid room positions!"
          break
        end
        
        p valid_room_positions.map{|x| x[:room].room_str + " opened: #{x[:number_of_spots_opened_up]}, closed: #{x[:number_of_spots_closed_up]}"} if debug
        
        every_room_pos_would_block_off_all_spots = valid_room_positions.all?{|room_position| room_position[:would_block_off_all_open_spots]}
        unless every_room_pos_would_block_off_all_spots
          # Don't allow positions that would block off literally every open spot.
          # Unless all the room positions we can use would do that, then this is going to be the final room we place anyway, so allow it.
          valid_room_positions.reject! do |room_position|
            room_position[:would_block_off_all_open_spots]
          end
        end
        
        if placement_mode == :placing_skeleton
          # Only placing the skeleton of the sector for now.
          
          possible_room_positions = valid_room_positions.select do |room_position|
            room = room_position[:room]
            if @transition_rooms.include?(room)
              true
            elsif checker.progress_important_rooms.include?(room)
              true
            elsif room_position[:diff_in_num_spots] >= 1
              true
            else
              false
            end
            # TODO boss rooms
          end
          
          if possible_room_positions.empty?
            # If there are no important rooms or rooms that increase the number of available doors, use a room that keeps the number of doors the same.
            possible_room_positions = valid_room_positions.select do |room_position|
              if room_position[:diff_in_num_spots] == 0
                true
              else
                false
              end
            end
          end
          
          # TODO: prioritize long rooms over normal rooms that are not long.
        else
          # Filling in the remaining dead ends.
          
          non_dead_end_room_positions = valid_room_positions.select do |room_position|
            room_position[:diff_in_num_spots] >= 0
          end
          area_entrance_room_positions = valid_room_positions.select do |room_position|
            GAME == "ooe" && room_position[:room].entities.find{|e| e.is_special_object? && e.subtype == 0x2B}
          end
          save_room_positions = valid_room_positions.select do |room_position|
            room_position[:room].entities.find{|e| e.is_save_point?}
          end
          warp_room_positions = valid_room_positions.select do |room_position|
            room_position[:room].entities.find{|e| e.is_warp_point?}
          end
          
          # Prioritize OoE area entrances, then save rooms, then warp rooms, then other dead ends.
          if area_entrance_room_positions.any?
            possible_room_positions = area_entrance_room_positions
          elsif save_room_positions.any?
            possible_room_positions = save_room_positions
          elsif warp_room_positions.any?
            possible_room_positions = warp_room_positions
          else
            possible_room_positions = valid_room_positions
          end
        end
        
        if possible_room_positions.empty?
          puts "No possible room positions."
          break
        end
        
        chosen_room_position = possible_room_positions.sample(random: rng)
      end
      
      room = chosen_room_position[:room]
      unplaced_sector_rooms.delete(room)
      
      room_x = chosen_room_position[:x]
      room_y = chosen_room_position[:y]
      
      if @transition_rooms.include?(room)
        is_transition_str = " (transition)"
      end
      puts "Successfully placed #{room.room_str}#{is_transition_str} at (#{room_x},#{room_y})" if debug
      
      room.room_xpos_on_map = room_x
      room.room_ypos_on_map = room_y
      room.write_to_rom()
      (room_x..room_x+room.width-1).each do |tile_x|
        (room_y..room_y+room.height-1).each do |tile_y|
          map_spots[tile_x][tile_y] = room
        end
      end
      
      inside_door_str_used_to_attach = chosen_room_position[:inside_door_str_used_to_attach]
      subrooms_in_room = checker.subrooms_doors_only[room.room_str]
      if subrooms_in_room
        subrooms_in_room.each do |door_indexes_in_subroom|
          door_strs_in_subroom = door_indexes_in_subroom.map{|door_index| "#{room.room_str}_%03X" % door_index}
          if !door_strs_in_subroom.include?(inside_door_str_used_to_attach)
            # This subroom is not the subroom we just connected this room with. So mark all the doors in this subroom as being inaccessible.
            unreachable_subroom_doors.concat(door_strs_in_subroom)
          else
            # This subroom IS the subroom we just connected this room with. So unmark all the doors in this subroom as being inaccessible.
            door_strs_in_subroom.each do |door_str|
              unreachable_subroom_doors.delete(door_str)
            end
          end
        end
      end
      
      if unplaced_transition_rooms.include?(room)
        unplaced_transition_rooms.delete(room)
        placed_transition_rooms << room
        num_placed_transition_rooms += 1
      else
        num_placed_non_transition_rooms += 1
      end
      
      
      recenter_map_spots(map_spots, map_width, map_height)
      
      #if @transition_rooms.include?(room)
      #  regenerate_map()
      #  gets
      #end
      
      #regenerate_map(maps_rendered)
      #maps_rendered += 1
      
      #regenerate_map(area_index, sector_index)
      #gets
    end
    
    unplaced_progress_important_rooms = unplaced_sector_rooms & checker.progress_important_rooms
    if unplaced_progress_important_rooms.any?
      puts "Map randomizer failed to place progress important rooms: " + unplaced_progress_important_rooms.map{|room| room.room_str}.join(", ")
      return :mustredo
    end
    
    ratio_unplaced_rooms = unplaced_sector_rooms.size.to_f / total_sector_rooms
    if ratio_unplaced_rooms > 0.75
      puts "Map randomizer failed to place #{(ratio_unplaced_rooms*100).to_i}% of rooms in this sector."
      return :shouldredo
    end
    
    puts "Successfully placed non-transition rooms: #{num_placed_non_transition_rooms}"
  end
  
  def get_num_spots_opened_and_closed_for_placement(room, room_doors, map_spots, map_width, map_height, open_spots, x_to_place_room_at, y_to_place_room_at)
    number_of_spots_opened_up = 0
    room_doors.each do |door|
      case door.direction
      when :left
        check_x = x_to_place_room_at - 1
        check_y = y_to_place_room_at + door.y_pos
        if (1..map_width-1).include?(check_x) && (1..map_height-1).include?(check_y) && map_spots[check_x][check_y].nil?
          number_of_spots_opened_up += 1
        end
      when :right
        check_x = x_to_place_room_at + room.width
        check_y = y_to_place_room_at + door.y_pos
        if (1..map_width-1).include?(check_x) && (1..map_height-1).include?(check_y) && map_spots[check_x][check_y].nil?
          number_of_spots_opened_up += 1
        end
      when :up
        check_x = x_to_place_room_at + door.x_pos
        check_y = y_to_place_room_at - 1
        if (1..map_width-1).include?(check_x) && (1..map_height-1).include?(check_y) && map_spots[check_x][check_y].nil?
          number_of_spots_opened_up += 1
        end
      when :down
        check_x = x_to_place_room_at + door.x_pos
        check_y = y_to_place_room_at + room.height
        if (1..map_width-1).include?(check_x) && (1..map_height-1).include?(check_y) && map_spots[check_x][check_y].nil?
          number_of_spots_opened_up += 1
        end
      end
    end
    
    number_of_spots_closed_up = 0
    open_spots.each do |x, y, direction, dest_room|
      if (x_to_place_room_at..x_to_place_room_at+room.width-1).include?(x) && (y_to_place_room_at..y_to_place_room_at+room.height-1).include?(y)
        number_of_spots_closed_up += 1
      end
    end
    
    return [number_of_spots_opened_up, number_of_spots_closed_up]
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
  
  def recenter_map_spots(map_spots, map_width, map_height)
    min_x = map_width
    min_y = map_height
    max_x = 0
    max_y = 0
    map_spots.each_with_index do |col, x|
      col.each_with_index do |room, y|
        if room
          room_x = room.room_xpos_on_map
          room_y = room.room_ypos_on_map
          next if room_x == 63 || room_y == 47 || @rooms_unused_by_map_rando.include?(room) # Dummied out room
          
          if room_x < min_x
            min_x = room_x
          end
          if room_y < min_y
            min_y = room_y
          end
          
          room_right_x = room.room_xpos_on_map + room.width - 1
          if room_right_x > max_x
            max_x = room_right_x
          end
          room_bottom_y = room.room_ypos_on_map + room.height - 1
          if room_bottom_y > max_y
            max_y = room_bottom_y
          end
        end
      end
    end
    
    used_map_width = max_x - min_x + 1
    used_map_height = max_y - min_y + 1
    desired_topleft_x = (map_width - used_map_width) / 2
    desired_topleft_y = (map_height - used_map_height) / 2
    needed_x_offset = desired_topleft_x - min_x
    needed_y_offset = desired_topleft_y - min_y
    
    # Rotate the map spots array to offset all spots by the desired amount.
    map_spots.rotate!(-needed_x_offset)
    map_spots.each do |col|
      col.rotate!(-needed_y_offset)
    end
    
    done_rooms = []
    map_spots.each_with_index do |col, x|
      col.each_with_index do |room, y|
        if room && !done_rooms.include?(room)
          room.room_xpos_on_map = x
          room.room_ypos_on_map = y
          room.write_to_rom()
          done_rooms << room
        end
      end
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
          elsif !@transition_rooms.include?(room)
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
          elsif !@transition_rooms.include?(room)
            # No matching door. Block this door off.
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
          elsif !@transition_rooms.include?(room)
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
          elsif !@transition_rooms.include?(room)
            # No matching door. Block this door off.
            tile_y = room.height*SCREEN_HEIGHT_IN_TILES-1
            tile_start_x = down_door.x_pos*SCREEN_WIDTH_IN_TILES
            (tile_start_x..tile_start_x+SCREEN_WIDTH_IN_TILES-1).each do |tile_x|
              next if coll[tile_x*0x10,tile_y*0x10].is_solid?
              tile_i = tile_x + tile_y*SCREEN_WIDTH_IN_TILES*coll_layer.width
              coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
              coll_layer.tiles[tile_i].horizontal_flip = false
              
              # If there are any jumpthrough platforms immediately above the downdoor we're blocking off, delete those platforms.
              # If we don't delete them and the player tries to fall through one, it kind of bugs out the physics and the player teleports around a little bit.
              if coll[tile_x*0x10,(tile_y-1)*0x10].is_jumpthrough_platform?
                tile_i = tile_x + (tile_y-1)*SCREEN_WIDTH_IN_TILES*coll_layer.width
                coll_layer.tiles[tile_i].index_on_tileset = 0
              end
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
      line_up_door(door)
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
  
  def get_open_spots(map_spots, map_width, map_height, transition_room_to_allow_connecting_to: nil, unreachable_subroom_doors: [])
    transition_rooms_not_allowed_to_connect_to = @transition_rooms - [transition_room_to_allow_connecting_to]
    
    open_spots = []
    map_width.times do |x|
      map_height.times do |y|
        next if map_spots[x][y]
        
        # Don't place rooms right on the edge of the map
        next if x == 0
        next if y == 0
        next if x == map_width - 1
        next if y == map_height - 1
        
        if map_spots[x-1][y]
          dest_room = map_spots[x-1][y]
          
          y_in_dest_room = y - dest_room.room_ypos_on_map
          dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
          right_dest_door = dest_room_doors.find{|door| door.direction == :right && door.y_pos == y_in_dest_room}
          if right_dest_door && !transition_rooms_not_allowed_to_connect_to.include?(dest_room)
            open_spots << [x, y, :left, dest_room]
          end
        end
        
        if map_spots[x+1][y]
          dest_room = map_spots[x+1][y]
          
          y_in_dest_room = y - dest_room.room_ypos_on_map
          dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
          left_dest_door = dest_room_doors.find{|door| door.direction == :left && door.y_pos == y_in_dest_room}
          if left_dest_door && !transition_rooms_not_allowed_to_connect_to.include?(dest_room)
            open_spots << [x, y, :right, dest_room]
          end
        end
        
        if map_spots[x][y-1]
          dest_room = map_spots[x][y-1]
          
          x_in_dest_room = x - dest_room.room_xpos_on_map
          dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
          down_dest_door = dest_room_doors.find{|door| door.direction == :down && door.x_pos == x_in_dest_room}
          if down_dest_door
            open_spots << [x, y, :up, dest_room]
          end
        end
        
        if map_spots[x][y+1]
          dest_room = map_spots[x][y+1]
          
          x_in_dest_room = x - dest_room.room_xpos_on_map
          dest_room_doors = dest_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str) || unreachable_subroom_doors.include?(door.door_str)}
          up_dest_door = dest_room_doors.find{|door| door.direction == :up && door.x_pos == x_in_dest_room}
          if up_dest_door
            open_spots << [x, y, :down, dest_room]
          end
        end
      end
    end
    
    return open_spots
  end
  
  def check_rooms_can_be_connected(room_a, room_b)
    if GAME == "por" && !options[:randomize_starting_room] && [room_a.room_str, room_b.room_str].sort == ["00-00-00", "00-00-03"]
      # Don't connect the default starting room of the game to the tall underground room. This can make the player not have access to any items at the start.
      return false
    end
    if @transition_rooms.include?(room_a) && @transition_rooms.include?(room_b)
      return false
    end
    if GAME == "dos" && room_a.sector_index == 5 && room_b.sector_index == 5
      # Condemned Tower/Mine of Judgement. Don't interconnect these two.
      if CONDEMNED_TOWER_ROOM_INDEXES.include?(room_a.room_index) && CONDEMNED_TOWER_ROOM_INDEXES.include?(room_b.room_index)
        # Both Condemned Tower.
        return true
      end
      if !CONDEMNED_TOWER_ROOM_INDEXES.include?(room_a.room_index) && !CONDEMNED_TOWER_ROOM_INDEXES.include?(room_b.room_index)
        # Both Mine of Judgement.
        return true
      end
      if [room_a.room_str, room_b.room_str].sort == ["00-05-0C", "00-05-18"]
        # The connector rooms with the up/down doors.
        return true
      end
      return false
    end
    if room_a.sector_index == room_b.sector_index
      return true
    end
    if @transition_rooms.include?(room_a)
      return true
    end
    if @transition_rooms.include?(room_b)
      return true
    end
    return false
  end
  
  def regenerate_all_maps
    case GAME
    when "dos"
      regenerate_map(0, 0) # Castle
      regenerate_map(0, 0xB) # Abyss
    when "por"
      (0..9).each do |area_index|
        regenerate_map(area_index, 0)
      end
    when "ooe"
      (0..0x12).each do |area_index|
        next if area_index == 1 # Skip Wygol
        regenerate_map(area_index, 0)
      end
    end
  end
  
  def regenerate_map(area_index, map_sector_index, filename_num=nil, should_recenter_map: true)
    map = game.get_map(area_index, map_sector_index)
    area = game.areas[area_index]
    
    if GAME == "dos"
      regenerate_map_dos(map, area)
    else
      regenerate_map_por_ooe(map, area, should_recenter_map: should_recenter_map)
    end
    
    filename = "./logs/maptest #{GAME} %02X" % area_index
    if GAME == "dos" && map_sector_index == 0xB
      filename += "-abyss" % map_sector_index
    end
    if filename_num
      filename += " #{filename_num}" % [area_index, map_sector_index]
    end
    filename += ".png"
    hardcoded_transition_rooms = (GAME == "dos" ? @transition_rooms : [])
    renderer.render_map(map, scale=3, hardcoded_transition_rooms=hardcoded_transition_rooms).save(filename)
  end
  
  def regenerate_map_dos(map, area)
    unless map.is_abyss
      # Fix warps.
      map.warp_rooms.each_with_index do |warp, warp_index|
        if warp_index == 0xB # Abyss
          warp.x_pos_in_tiles = 54
          warp.y_pos_in_tiles = 42
        else
          room = game.room_by_str(DOS_WARP_ROOM_STRS[warp_index])
          warp.x_pos_in_tiles = room.room_xpos_on_map
          warp.y_pos_in_tiles = room.room_ypos_on_map
        end
      end
    end
    
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
        left_room = area.sectors[left_tile.sector_index].rooms[left_tile.room_index]
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
        top_room = area.sectors[top_tile.sector_index].rooms[top_tile.room_index]
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
  end
  
  def regenerate_map_por_ooe(map, area, should_recenter_map: true)
    map.tiles.clear() # Empty the array of vanilla map tiles.
    
    min_x = 9999
    min_y = 9999
    max_x = 0
    max_y = 0
    area.sectors.each do |sector|
      sector.rooms.each do |room|
        room_x = room.room_xpos_on_map
        room_y = room.room_ypos_on_map
        next if room_x == 63 || room_y == 47 || @rooms_unused_by_map_rando.include?(room) # Dummied out room
        
        if room_x < min_x
          min_x = room_x
        end
        if room_y < min_y
          min_y = room_y
        end
        
        room_right_x = room.room_xpos_on_map + room.width - 1
        if room_right_x > max_x
          max_x = room_right_x
        end
        room_bottom_y = room.room_ypos_on_map + room.height - 1
        if room_bottom_y > max_y
          max_y = room_bottom_y
        end
      end
    end
    
    if should_recenter_map
      # Push the map up into the top left corner if it's not already.
      if min_x > 0 || min_y > 0
        area.sectors.each do |sector|
          sector.rooms.each do |room|
            unless room.room_xpos_on_map == 63 || room.room_ypos_on_map == 47 # Skip dummied out rooms
              room.room_xpos_on_map -= min_x
              room.room_ypos_on_map -= min_y
              room.write_to_rom()
            end
          end
        end
        
        max_x -= min_x
        max_y -= min_y
        min_x = 0
        min_y = 0
      end
      
      # Visually center the map.
      x_offset_in_tiles = (64 - max_x) / 2
      y_offset_in_tiles = (48 - max_y) / 2
      map.draw_x_offset = x_offset_in_tiles / 2 # These properties are in terms of pairs of 2 tiles, so divide by 2 again.
      map.draw_y_offset = y_offset_in_tiles / 2
    end
    
    (0..max_y).each do |y|
      (0..max_x).each do |x|
        sector_index, room_index = area.get_sector_and_room_indexes_from_map_x_y(x, y)
        
        if sector_index
          room = area.sectors[sector_index].rooms[room_index]
          
          tile = MapTile.new([0, y, x], 0)
          map.tiles << tile
          
          tile.sector_index = sector_index
          tile.room_index = room_index
          
          tile.is_save = room.entities.any?{|e| e.is_save_point?}
          tile.is_warp = room.entities.any?{|e| e.is_warp_point?}
          tile.is_transition = @transition_rooms.include?(room)
          
          tile_x_off = (x - room.room_xpos_on_map) * SCREEN_WIDTH_IN_PIXELS
          tile_y_off = (y - room.room_ypos_on_map) * SCREEN_HEIGHT_IN_PIXELS
          if GAME == "por"
            tile.is_entrance = room.entities.find do |e|
              e.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(e.subtype) &&
                (tile_x_off..tile_x_off+SCREEN_WIDTH_IN_PIXELS-1).include?(e.x_pos) &&
                (tile_y_off..tile_y_off+SCREEN_HEIGHT_IN_PIXELS-1).include?(e.y_pos)
            end
          else # OoE
            tile.is_entrance = room.entities.find do |e|
              e.is_special_object? && e.subtype == 0x2B &&
                (tile_x_off..tile_x_off+SCREEN_WIDTH_IN_PIXELS).include?(e.x_pos) &&
                (tile_y_off..tile_y_off+SCREEN_HEIGHT_IN_PIXELS-1).include?(e.y_pos)
            end
          end
        end
      end
    end
    
    # Now go through the tiles again and generate the lines delineating rooms.
    map.tiles.each do |tile|
      sector_index = tile.sector_index
      room_index = tile.room_index
      x = tile.x_pos
      y = tile.y_pos
      room = area.sectors[sector_index].rooms[room_index]
      
      left_tile = map.tiles.find{|t| t.x_pos == x-1 && t.y_pos == y}
      top_tile = map.tiles.find{|t| t.x_pos == x && t.y_pos == y-1}
      right_tile = map.tiles.find{|t| t.x_pos == x+1 && t.y_pos == y}
      bottom_tile = map.tiles.find{|t| t.x_pos == x && t.y_pos == y+1}
      
      if left_tile.nil?
        tile.left_wall = true
      elsif left_tile.sector_index != sector_index || left_tile.room_index != room_index
        left_room = area.sectors[left_tile.sector_index].rooms[left_tile.room_index]
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
      if top_tile.nil?
        tile.top_wall = true
      elsif top_tile.sector_index != sector_index || top_tile.room_index != room_index
        top_room = area.sectors[top_tile.sector_index].rooms[top_tile.room_index]
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
      if right_tile.nil?
        tile.right_wall = true
      elsif right_tile.sector_index != sector_index || right_tile.room_index != room_index
        right_room = area.sectors[right_tile.sector_index].rooms[right_tile.room_index]
        y_in_dest_room = y - right_room.room_ypos_on_map
        room_doors = right_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        left_door = room_doors.find{|door| door.direction == :left && door.y_pos == y_in_dest_room}
        if left_door
          tile.right_wall = false
          tile.right_door = true
        else
          tile.right_wall = true
        end
      end
      if bottom_tile.nil?
        tile.bottom_wall = true
      elsif bottom_tile.sector_index != sector_index || bottom_tile.room_index != room_index
        bottom_room = area.sectors[bottom_tile.sector_index].rooms[bottom_tile.room_index]
        x_in_dest_room = x - bottom_room.room_xpos_on_map
        room_doors = bottom_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        up_door = room_doors.find{|door| door.direction == :up && door.x_pos == x_in_dest_room}
        if up_door
          tile.bottom_wall = false
          tile.bottom_door = true
        else
          tile.bottom_wall = true
        end
      end
    end
    
    map.write_to_rom(allow_changing_num_tiles: true)
  end
end
