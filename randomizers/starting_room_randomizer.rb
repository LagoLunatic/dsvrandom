
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
      
      next if room.area.name == "Nest of Evil"
      next if room.sector.name == "The Throne Room"
      next if room.sector.name == "Master's Keep" && room.sector_index == 0xC # Cutscene where Dracula dies
      
      next if room.area.name == "Training Chamber"
      next if room.area.name == "Large Cavern"
      next if room.sector.name == "Final Approach"
      
      next if room.entities.find{|e| e.is_boss?}
      
      rooms << room
    end
    
    # TODO: in OoE put the glyph given by barlowe in the randomized starting room so the player has a weapon
    
    # TODO: for the bonus starting items option, use the new x/y pos from here.
    
    room = rooms.sample(random: rng)
    
    room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
    room_doors.select!{|door| door.direction == :left || door.direction == :right}
    door = room_doors.sample(random: rng)
    gap_start_index, gap_end_index, tiles_in_biggest_gap = get_biggest_door_gap(door)
    case door.direction
    when :left
      x_pos = 0
      y_pos = door.y_pos*SCREEN_HEIGHT_IN_PIXELS
      y_pos += gap_end_index*0x10 + 0x10
    when :right
      x_pos = door.x_pos*SCREEN_WIDTH_IN_PIXELS-1
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
end
