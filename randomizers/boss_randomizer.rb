
module BossRandomizer
  def randomize_bosses
    boss_entities = []
    game.each_room do |room|
      boss_entities += room.entities.select{|e| e.is_boss? && RANDOMIZABLE_BOSS_IDS.include?(e.subtype)}
    end
    
    if GAME == "dos"
      # Turn the throne room Dario entity into Aguni so the boss randomizer logic works.
      throne_room_dario = game.areas[0].sectors[9].rooms[1].entities[6]
      throne_room_dario.subtype = 0x70
      
      # Remove the throne room event because it doesn't work without Dario.
      throne_room_event = game.areas[0].sectors[9].rooms[1].entities[2]
      throne_room_event.type = 0
      throne_room_event.write_to_rom()
    end
    
    # Determine unique boss rooms.
    boss_rooms_for_each_boss = {}
    boss_entities.each do |boss_entity|
      boss_rooms_for_each_boss[boss_entity.subtype] ||= []
      boss_rooms_for_each_boss[boss_entity.subtype] << boss_entity.room
      boss_rooms_for_each_boss[boss_entity.subtype].uniq!
    end
    # Figure out what bosses can be placed in what rooms.
    boss_swaps_that_work = {}
    boss_rooms_for_each_boss.each do |old_boss_id, boss_rooms|
      old_boss = game.enemy_dnas[old_boss_id]
      
      RANDOMIZABLE_BOSS_IDS.each do |new_boss_id|
        new_boss = game.enemy_dnas[new_boss_id]
        
        all_rooms_work = boss_rooms.all? do |boss_room|
          boss_entity = boss_room.entities.select{|e| e.is_boss? && e.subtype == old_boss_id}.first
          case GAME
          when "dos"
            dos_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
          when "por"
            por_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
          when "ooe"
            ooe_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
          end
        end
        
        if all_rooms_work
          boss_swaps_that_work[old_boss_id] ||= []
          boss_swaps_that_work[old_boss_id] << new_boss_id
        end
      end
    end
    # Limit to swaps that work both ways.
    boss_swaps_that_work.each do |old_boss_id, new_boss_ids|
      new_boss_ids.select! do |new_boss_id|
        next if boss_swaps_that_work[new_boss_id].nil?
        boss_swaps_that_work[new_boss_id].include?(old_boss_id)
      end
    end
    
    remaining_boss_ids = RANDOMIZABLE_BOSS_IDS.dup
    queued_dna_changes = Hash.new{|h, k| h[k] = {}}
    already_randomized_bosses = {}
    
    boss_entities.shuffle(random: rng).each do |boss_entity|
      old_boss_id = boss_entity.subtype
      old_boss = game.enemy_dnas[old_boss_id]
      
      already_randomized_new_boss_id = already_randomized_bosses[old_boss_id]
      if already_randomized_new_boss_id
        new_boss_id = already_randomized_new_boss_id
      else
        possible_boss_ids_for_this_boss = boss_swaps_that_work[old_boss_id] & remaining_boss_ids
        if possible_boss_ids_for_this_boss.empty?
          # Nothing this could possibly randomize into and work correctly. Skip.
          puts "BOSS %02X FAILED!" % old_boss_id
          next
        end
        
        new_boss_id = possible_boss_ids_for_this_boss.sample(random: rng)
      end
      new_boss = game.enemy_dnas[new_boss_id]
      
      result = case GAME
      when "dos"
        dos_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
      when "por"
        por_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
      when "ooe"
        ooe_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
      end
      if result == :skip
        next
      end
      puts "BOSS %02X-%02X" % [old_boss_id, new_boss_id]
      
      boss_entity.subtype = new_boss_id
      remaining_boss_ids.delete(new_boss_id)
      remaining_boss_ids.delete(old_boss_id)
      
      boss_entity.write_to_rom()
      
      already_randomized_bosses[old_boss_id] = new_boss_id
      already_randomized_bosses[new_boss_id] = old_boss_id
      
      # Update the boss doors for the new boss
      old_boss_door_var_b = BOSS_ID_TO_BOSS_DOOR_VAR_B[old_boss_id] || 0
      new_boss_door_var_b = BOSS_ID_TO_BOSS_DOOR_VAR_B[new_boss_id] || 0
      ([boss_entity.room] + boss_entity.room.connected_rooms).each do |room|
        room.entities.each do |entity|
          if entity.type == 0x02 && entity.subtype == BOSS_DOOR_SUBTYPE && entity.var_b == old_boss_door_var_b
            entity.var_b = new_boss_door_var_b
            
            entity.write_to_rom()
          end
        end
      end
      
      # Give the new boss the old boss's soul so progression still works.
      queued_dna_changes[new_boss_id]["Soul"] = old_boss["Soul"]
      
      # Make the new boss have the stats of the old boss so it fits in at this point in the game.
      queued_dna_changes[new_boss_id]["HP"]               = old_boss["HP"]
      queued_dna_changes[new_boss_id]["MP"]               = old_boss["MP"]
      queued_dna_changes[new_boss_id]["SP"]               = old_boss["SP"]
      queued_dna_changes[new_boss_id]["AP"]               = old_boss["AP"]
      queued_dna_changes[new_boss_id]["EXP"]              = old_boss["EXP"]
      queued_dna_changes[new_boss_id]["Attack"]           = old_boss["Attack"]
      queued_dna_changes[new_boss_id]["Defense"]          = old_boss["Defense"]
      queued_dna_changes[new_boss_id]["Physical Defense"] = old_boss["Physical Defense"]
      queued_dna_changes[new_boss_id]["Magical Defense"]  = old_boss["Magical Defense"]
      
      if new_boss_id == 0x87 # Fake Trevor
        [0x88, 0x89].each do |other_boss_id| # Fake Grant and Sypha
          queued_dna_changes[other_boss_id]["HP"]               = old_boss["HP"]
          queued_dna_changes[other_boss_id]["MP"]               = old_boss["MP"]
          queued_dna_changes[other_boss_id]["SP"]               = old_boss["SP"]
          queued_dna_changes[other_boss_id]["AP"]               = old_boss["AP"]
          queued_dna_changes[other_boss_id]["EXP"]              = old_boss["EXP"]
          queued_dna_changes[other_boss_id]["Attack"]           = old_boss["Attack"]
          queued_dna_changes[other_boss_id]["Defense"]          = old_boss["Defense"]
          queued_dna_changes[other_boss_id]["Physical Defense"] = old_boss["Physical Defense"]
          queued_dna_changes[other_boss_id]["Magical Defense"]  = old_boss["Magical Defense"]
        end
      end
      
      if old_boss.name == "Wallman"
        # Don't copy Wallman's 9999 HP, use a more reasonable value instead.
        queued_dna_changes[new_boss_id]["HP"] = 4000
      end
      if new_boss.name == "Wallman"
        # Make sure Wallman always has 9999 HP.
        queued_dna_changes[new_boss_id]["HP"] = 9999
      end
    end
    
    queued_dna_changes.each do |boss_id, changes|
      boss = game.enemy_dnas[boss_id]
      
      changes.each do |attribute_name, new_value|
        boss[attribute_name] = new_value
      end
      
      boss.write_to_rom()
    end
  end
  
  def dos_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case new_boss.name
    when "Balore"
      has_left_door = boss_entity.room.doors.find{|d| d.direction == :left}
      has_right_door = boss_entity.room.doors.find{|d| d.direction == :right}
      
      if has_left_door && has_right_door
        # Balore has to be set as facing left OR right by the randomizer, he won't automatically face the direction the player entered from.
        return false
      end
    when "Zephyr"
      # If Zephyr spawns in a room that is 1 screen wide then either he or Soma will get stuck, regardless of what Zephyr's x pos is.
      if boss_entity.room.width < 2
        return false
      end
    end
    
    if old_boss.name == "Rahab" && ["Malphas", "Dmitrii", "Dario", "Gergoth", "Zephyr", "Paranoia", "Abaddon"].include?(new_boss.name)
      # These bosses will fall to below the water level in Rahab's room, which is a problem if the player doesn't have Rahab yet.
      return false
    end
    
    return true
  end
  
  def por_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    return true
  end
  
  def ooe_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    return true
  end
  
  def dos_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case old_boss.name
    when "Balore"
      if boss_entity.var_a == 2
        # Not actually Balore, this is the wall of ice blocks right before Balore.
        # We need to get rid of this because having this + a different boss besides Balore in the same room will load two different overlays into the same spot and crash the game.
        boss_entity.type = 0
        boss_entity.subtype = 0
        boss_entity.write_to_rom()
        return :skip
      end
    when "Paranoia"
      if boss_entity.var_a == 1
        # Mini-paranoia.
        return :skip
      end
    end
    
    case new_boss.name
    when "Flying Armor"
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0x50
    when "Balore"
      has_left_door = boss_entity.room.doors.find{|d| d.direction == :left}
      has_right_door = boss_entity.room.doors.find{|d| d.direction == :right}
      
      if has_right_door
        boss_entity.var_a = 1
        boss_entity.x_pos = 0x10
        boss_entity.y_pos = 0xB0
        
        if old_boss.name == "Puppet Master"
          boss_entity.x_pos += 0x90
        end
      else
        boss_entity.var_a = 0
        boss_entity.x_pos = 0xF0
        boss_entity.y_pos = 0xB0
      end
    when "Malphas"
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.var_b = 0
    when "Dmitrii"
      boss_entity.var_a = 0 # Boss rush Dmitrii, doesn't crash when there are no events.
    when "Dario"
      boss_entity.var_b = 0
    when "Puppet Master"
      boss_entity.x_pos = 0x100
      boss_entity.y_pos = 0x60
      
      boss_entity.var_a = 0
    when "Gergoth"
      unless old_boss_id == new_boss_id
        # Set Gergoth to boss rush mode, unless he's in his tower.
        boss_entity.var_a = 0
      end
      
      remove_flying_armor_event(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    when "Zephyr"
      # Don't put Zephyr inside the left or right walls. If he is either Soma or him will get stuck and soft lock the game.
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      
      # Boss rush Zephyr.
      boss_entity.var_a = 0
    when "Bat Company"
      remove_flying_armor_event(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    when "Paranoia"
      # If Paranoia spawns in Gergoth's tall tower, his position and the position of his mirrors can become disjointed.
      # This combination of x and y seems to be one of the least buggy.
      boss_entity.x_pos = 0x1F
      boss_entity.y_pos = 0x80
      
      boss_entity.var_a = 2
      
      remove_flying_armor_event(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    when "Aguni"
      boss_entity.var_a = 0
      boss_entity.var_b = 0
    when "Death"
      # If there are any candle's in Death's room, he will softlock the game when you kill him.
      # Why? I dunno.
      boss_entity.room.entities.each do |entity|
        if entity.is_special_object? && entity.subtype == 1 && entity.var_a != 0
          entity.type = 0
          entity.write_to_rom()
        end
      end
      
      remove_flying_armor_event(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    else
      boss_entity.var_a = 1
    end
  end
  
  def remove_flying_armor_event(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    if GAME == "dos" && boss_entity.room.room_index == 0xB && boss_entity.room.sector_index == 0
      # If certain bosses are placed in Flying Armor's room the game will softlock when you kill the boss.
      # This is because of the event with Yoko in Flying Armor's room, so remove the event.
      
      event = boss_entity.room.entities[6]
      event.type = 0
      event.write_to_rom()
    end
  end
  
  def por_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case old_boss.name
    when "Behemoth"
      if boss_entity.var_b == 2
        # Scripted Behemoth that chases you down the hallway.
        return :skip
      end
    end
    
    case new_boss.name
    when "Stella"
      boss_entity.var_a = 0 # Just Stella, we don't want Stella&Loretta.
    when "Balore", "Gergoth", "Zephyr", "Aguni", "Abaddon"
      dos_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    end
  end
  
  def ooe_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case old_boss.name
    when "Giant Skeleton"
      if boss_entity.var_a == 0
        # Non-boss version of the giant skeleton.
        return :skip
      elsif new_boss.name != "Giant Skeleton"
        boss_entity.room.entities.each do |entity|
          if entity.type == 2 && entity.subtype == 0x3E && entity.var_a == 1
            # Searchlights in Giant Skeleton's boss room. These will soft lock the game if Giant Skeleton isn't here, so we need to tweak it a bit.
            entity.var_a = 0
            entity.write_to_rom()
          end
        end
      end
    end
    
    case new_boss.name
    when "Wallman"
      # We don't want Wallman to be offscreen because then he's impossible to defeat.
      boss_entity.x_pos = 0xCC
      boss_entity.y_pos = 0xAF
    end
  end
end
