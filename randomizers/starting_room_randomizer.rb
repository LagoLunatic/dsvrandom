
module StartingRoomRandomizer
  def randomize_starting_room
    game.fix_top_screen_on_new_game()
    
    rooms = []
    game.each_room do |room|
      next if room.layers.length == 0
      next if room.doors.length == 0
      
      next if room.area.name.include?("Boss Rush")
      next if room.sector.name.include?("Boss Rush")
      
      if options[:bonus_starting_items]
        # These sectors have the largest sector overlay in their respective game.
        # Adding new items (for the starting items) is not possible currently, so don't allow these to be the starting area.
        next if room.sector.name == "Demon Guest House"
        next if room.area.name == "Forgotten City" && room.sector_index == 0
        next if room.sector.name == "Underground Labyrinth"
      end
      
      rooms << room
    end
    
    room = rooms.sample(random: rng)
    game.set_starting_room(room.area_index, room.sector_index, room.room_index)
    
    @starting_room = room
  end
end
