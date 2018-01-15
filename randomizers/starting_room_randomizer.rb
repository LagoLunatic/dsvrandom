
module StartingRoomRandomizer
  def randomize_starting_room
    game.fix_top_screen_on_new_game()
    
    rooms = []
    game.each_room do |room|
      next if room.layers.length == 0
      
      room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
      room_doors.select!{|door| door.direction == :left || door.direction == :right}
      next if room_doors.empty?
      
      # Limit to save rooms.
      next unless room.entities.find{|e| e.is_save_point?}
      
      next if room.area.name.include?("Boss Rush")
      next if room.sector.name.include?("Boss Rush")
      
      next if room.sector.name == "The Abyss"
      next if room.sector.name == "Condemned Tower & Mine of Judgment" && room.room_ypos_on_map >= 0x17
      
      next if room.area.name == "Nest of Evil"
      next if room.sector.name == "The Throne Room"
      next if room.sector.name == "Master's Keep" && room.sector_index == 0xC # Cutscene where Dracula dies
      
      next if room.area.name == "Training Hall"
      next if room.area.name == "Large Cavern"
      next if room.sector.name == "Final Approach"
      
      next if room.entities.find{|e| e.is_boss?}
      
      # Limit to rooms where the player can access at least 3 item locations. Otherwise the player could be stuck right at the start with no items.
      checker.set_starting_room(room, 0)
      accessible_locations, accessible_doors = checker.get_accessible_locations_and_doors()
      next if accessible_locations.size < 3
      
      rooms << room
    end
    
    # Limit potential starting rooms by how powerful common enemies in their subsector are on average (in the base game, not after enemies are randomized).
    subsector_difficulty_for_each_room = {}
    @enemy_difficulty_by_subsector.each do |rooms_in_subsector, difficulty|
      (rooms & rooms_in_subsector).each do |room|
        subsector_difficulty_for_each_room[room] = difficulty
      end
    end
    #subsector_difficulty_for_each_room.sort_by{|k,v| p v; v}.each do |room, difficulty|
    #  puts "#{room.room_str}: #{difficulty.round(4)}"
    #end
    possible_rooms = subsector_difficulty_for_each_room.select do |room, difficulty|
      difficulty <= @difficulty_settings[:starting_room_max_difficulty]
    end.keys
    
    # TODO: for the bonus starting items option, use the new x/y pos from here.
    
    room = possible_rooms.sample(random: rng)
    
    room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
    room_doors.select!{|door| door.direction == :left || door.direction == :right}
    door = room_doors.sample(random: rng)
    gap_start_index, gap_end_index, tiles_in_biggest_gap = get_biggest_door_gap(door)
    case door.direction
    when :left
      x_pos = 0x10
      y_pos = door.y_pos*SCREEN_HEIGHT_IN_PIXELS
      y_pos += gap_end_index*0x10 + 0x10
    when :right
      x_pos = door.x_pos*SCREEN_WIDTH_IN_PIXELS-0x10
      y_pos = door.y_pos*SCREEN_HEIGHT_IN_PIXELS
      y_pos += gap_end_index*0x10 + 0x10
    when :up
      y_pos = 0
      x_pos = door.x_pos*SCREEN_WIDTH_IN_PIXELS
      x_pos += gap_end_index*0x10
    when :down
      y_pos = door.y_pos*SCREEN_HEIGHT_IN_PIXELS-1
      x_pos = door.x_pos*SCREEN_WIDTH_IN_PIXELS
      x_pos += gap_end_index*0x10
    end
    
    if GAME == "dos"
      # In DoS we don't want to actually change the starting room, we instead change where the prologue cutscene teleports you to, so you still go through the tutorial.
      
      game.fs.write(0x021C74CC, [0xE3A00000].pack("V")) # Change this to a constant mov first
      # Then replace the sector and room indexes.
      game.fs.write(0x021C74CC, [room.sector_index].pack("C"))
      game.fs.write(0x021C74D0, [room.room_index].pack("C"))
      # And the x/y position in the room.
      # The x/y are going to be arm shifted immediates, so they need to be rounded down to the nearest 0x10 to make sure they don't use too many bits.
      if x_pos > 0x100
        x_pos = x_pos/0x10*0x10
      end
      if y_pos > 0x100
        y_pos = y_pos/0x10*0x10
      end
      game.fs.replace_arm_shifted_immediate_integer(0x021C74D4, x_pos)
      game.fs.replace_arm_shifted_immediate_integer(0x021C74D8, y_pos)
      
      # And then we do that all again for the code that runs if the player skips the prologue cutscene by pressing start.
      game.fs.write(0x021C77E4, [0xE3A00000].pack("V"))
      game.fs.write(0x021C77E4, [room.sector_index].pack("C"))
      game.fs.write(0x021C77E8, [room.room_index].pack("C"))
      game.fs.replace_arm_shifted_immediate_integer(0x021C77EC, x_pos)
      game.fs.replace_arm_shifted_immediate_integer(0x021C77F0, y_pos)
    else
      game.set_starting_room(room.area_index, room.sector_index, room.room_index)
      game.set_starting_position(x_pos, y_pos)
    end
    
    @starting_room = room
    @starting_room_door_index = room.doors.index(door)
    @starting_x_pos = x_pos
    @starting_y_pos = y_pos
  end
  
  def add_starter_items_to_randomized_starting_room
    case GAME
    when "ooe"
      # Put the glyph Barlowe would normally give you at the start in the randomized starting room.
      
      entity = @starting_room.add_new_entity()
      
      entity.x_pos = @starting_x_pos
      entity.y_pos = @starting_y_pos
      
      @coll = RoomCollision.new(@starting_room, game.fs)
      floor_y = coll.get_floor_y(entity, allow_jumpthrough: true)
      entity.y_pos = floor_y
      
      if @ooe_starter_glyph_id
        pickup_global_id = @ooe_starter_glyph_id
      else
        pickup_global_id = 1
      end
      
      location = "#{@starting_room.room_str}_%02X" % (@starting_room.entities.length-1)
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
    end
  end
end
