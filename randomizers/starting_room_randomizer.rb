
module StartingRoomRandomizer
  def randomize_starting_room
    rooms = []
    game.each_room do |room|
      next if room.layers.length == 0
      next if room.doors.length == 0
      
      next if room.area.name.include?("Boss Rush")
      
      next if room.sector.name.include?("Boss Rush")
      
      rooms << room
    end
    
    room = rooms.sample(random: rng)
    game.set_starting_room(room.area_index, room.sector_index, room.room_index)
    
    @starting_room = room
  end
end
