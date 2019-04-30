
module StartingItemsRandomizer
  def randomize_starting_items
    non_progress_items = all_non_progression_pickups & ITEM_GLOBAL_ID_RANGE.to_a
    non_progress_skills = all_non_progression_pickups & SKILL_GLOBAL_ID_RANGE.to_a
    if GAME == "ooe"
      # Need to give the player at least one free glyph, or they may not be able to open the glyph statue and get a weapon.
      free_glyph_attack_glyph_ids = [0x1D, 0x1F, 0x20, 0x22, 0x24, 0x26, 0x27, 0x2A, 0x2B, 0x2F, 0x30, 0x31, 0x32]
      starting_pickups = [free_glyph_attack_glyph_ids.sample(random: rng)]
      non_progress_skills -= starting_pickups
      starting_pickups += non_progress_items.sample(3, random: rng) + non_progress_skills.sample(2, random: rng)
    else
      starting_pickups = non_progress_items.sample(3, random: rng) + non_progress_skills.sample(3, random: rng)
    end
    
    room = @starting_room
    @coll = RoomCollision.new(room, game.fs)
    room_str = "%02X-%02X-%02X" % [room.area_index, room.sector_index, room.room_index]
    starting_pickups.each do |pickup_global_id|
      #puts "%03X" % pickup_global_id
      entity = Entity.new(room, room.fs)
      
      entity.x_pos = 0x80 - 0x10
      entity.y_pos = 0x60
      
      case GAME
      when "dos"
        if room.room_str == "00-00-01"
          # Move the entities over a little so they're not behind Soma after the intro cutscene.
          entity.x_pos = 0x160
        end
      when "por"
        if room.room_str == "00-00-00"
          # Don't interfere with the intro cutscene or the game will crash.
          entity.x_pos = 0x160
        end
      when "ooe"
        if room.room_str == "02-00-04"
          # Move the entities over so they're not on a floating platform.
          entity.x_pos = 0xC0
        end
      end
      
      y = coll.get_floor_y(entity, allow_jumpthrough: true)
      unless y.nil?
        entity.y_pos = y
      end
      
      room.entities << entity
      room.write_entities_to_rom()
      
      location = "#{room_str}_%02X" % (room.entities.length-1)
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
    end
  end
  
  def add_bonus_item_to_starting_room(pickup_global_id)
    entity = @starting_room.add_new_entity()
    
    entity.x_pos = @starting_x_pos
    entity.y_pos = @starting_y_pos
    
    if (GAME == "dos" && MAGIC_SEAL_GLOBAL_ID_RANGE.include?(pickup_global_id)) || (GAME == "por" && SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id))
      @coll = RoomCollision.new(@starting_room, game.fs)
      floor_y = coll.get_floor_y(entity, allow_jumpthrough: true)
      entity.y_pos = floor_y - 0x18
    end
    
    location = "#{@starting_room.room_str}_%02X" % (@starting_room.entities.length-1)
    change_entity_location_to_pickup_global_id(location, pickup_global_id)
  end
end
