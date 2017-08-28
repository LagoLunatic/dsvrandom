
module StartingRoomRandomizer
  def randomize_starting_room
    game.fix_top_screen_on_new_game()
    
    rooms = []
    game.each_room do |room|
      next if room.layers.length == 0
      
      room_doors = room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
      room_doors.select!{|door| door.direction == :left || door.direction == :right}
      next if room_doors.empty?
      
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
    
    room = rooms.sample(random: rng)
    game.set_starting_room(room.area_index, room.sector_index, room.room_index)
    
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
    game.set_starting_position(x_pos, y_pos)
    
    @starting_room = room
    @starting_room_door_index = room.doors.index(door)
  end
end
