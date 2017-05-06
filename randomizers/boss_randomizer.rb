
module BossRandomizer
  def randomize_bosses
    shuffled_boss_ids = RANDOMIZABLE_BOSS_IDS.shuffle(random: rng)
    queued_dna_changes = Hash.new{|h, k| h[k] = {}}
    
    shuffled_boss_ids.each_with_index do |new_boss_id, i|
      old_boss_id = RANDOMIZABLE_BOSS_IDS[i]
      old_boss = game.enemy_dnas[old_boss_id]
      
      # Make the new boss have the stats of the old boss so it fits in at this point in the game.
      queued_dna_changes[new_boss_id]["HP"]               = old_boss["HP"]
      queued_dna_changes[new_boss_id]["MP"]               = old_boss["MP"]
      queued_dna_changes[new_boss_id]["SP"]               = old_boss["SP"]
      queued_dna_changes[new_boss_id]["EXP"]              = old_boss["EXP"]
      queued_dna_changes[new_boss_id]["Attack"]           = old_boss["Attack"]
      queued_dna_changes[new_boss_id]["Defense"]          = old_boss["Defense"]
      queued_dna_changes[new_boss_id]["Physical Defense"] = old_boss["Physical Defense"]
      queued_dna_changes[new_boss_id]["Magical Defense"]  = old_boss["Magical Defense"]
    end
    
    boss_entities = []
    game.each_room do |room|
      boss_entities += room.entities.select{|e| e.is_boss? && RANDOMIZABLE_BOSS_IDS.include?(e.subtype)}
    end
    
    boss_entities.each do |boss_entity|
      old_boss_id = boss_entity.subtype
      boss_index = RANDOMIZABLE_BOSS_IDS.index(old_boss_id)
      new_boss_id = shuffled_boss_ids[boss_index]
      old_boss = game.enemy_dnas[old_boss_id]
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
      
      boss_entity.subtype = new_boss_id
      
      boss_entity.write_to_rom()
      
      # Update the boss doors for the new boss
      new_boss_door_var_b = BOSS_ID_TO_BOSS_DOOR_VAR_B[new_boss_id] || 0
      ([boss_entity.room] + boss_entity.room.connected_rooms).each do |room|
        room.entities.each do |entity|
          if entity.type == 0x02 && entity.subtype == BOSS_DOOR_SUBTYPE
            entity.var_b = new_boss_door_var_b
            
            entity.write_to_rom()
          end
        end
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
      boss_entity.x_pos = boss_entity.room.main_layer_width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 80
    when "Balore"
      boss_entity.x_pos = 16
      boss_entity.y_pos = 176
      
      if old_boss.name == "Puppet Master"
        boss_entity.x_pos += 144
      end
    when "Malphas"
      boss_entity.var_b = 0
    when "Dmitrii"
      boss_entity.var_a = 0 # Boss rush Dmitrii, doesn't crash when there are no events.
    when "Dario"
      boss_entity.var_b = 0
    when "Puppet Master"
      boss_entity.x_pos = 256
      boss_entity.y_pos = 96
      
      boss_entity.var_a = 0
    when "Gergoth"
      unless old_boss_id == new_boss_id
        # Set Gergoth to boss rush mode, unless he's in his tower.
        boss_entity.var_a = 0
      end
    when "Zephyr"
      # Don't put Zephyr inside the left or right walls. If he is either Soma or him will get stuck and soft lock the game.
      boss_entity.x_pos = 256
      
      # TODO: If Zephyr spawns in a room that is 1 screen wide then either he or Soma will get stuck, regardless of what Zephyr's x pos is. Need to make sure Zephyr only spawns in rooms 2 screens wide or wider.
      # also if zephyr spawns inside rahab's room you can't reach him until you have rahab's soul.
    when "Paranoia"
      # If Paranoia spawns in Gergoth's tall tower, his position and the position of his mirrors can become disjointed.
      # This combination of x and y seems to be one of the least buggy.
      boss_entity.x_pos = 0x1F
      boss_entity.y_pos = 0x80
      
      boss_entity.var_a = 2
      
      if boss_entity.room.room_index == 0xB && boss_entity.room.sector_index == 0
        # If Paranoia is placed in Flying Armor's room the game will softlock when you kill him.
        # This is because of the event with Yoko in Flying Armor's room, so remove the event.
        
        event = boss_entity.room.entities[6]
        event.type = 0
        event.write_to_rom()
      end
    when "Aguni"
      boss_entity.var_a = 0
      boss_entity.var_b = 0
    when "Death"
      # TODO: when you kill death in a room besides his own, he just freezes up, soft locking the game.
    else
      boss_entity.var_a = 1
    end
  end
  
  def por_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case old_boss.name
    when "Behemoth"
      if boss_entity.var_b == 0x02
        # Scripted Behemoth that chases you down the hallway.
        return :skip
      end
    end
    
    if (0x81..0x84).include?(new_boss_id)
      dos_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    end
    
    case new_boss.name
    when "Stella"
      boss_entity.var_a = 0 # Just Stella, we don't want Stella&Loretta.
    end
  end
  
  def ooe_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case old_boss.name
    when "Brachyura"
      boss_entity.x_pos = 0x0080
      boss_entity.y_pos = 0x0A20
    when "Giant Skeleton"
      if boss_entity.var_a == 0
        # Non-boss version of the giant skeleton.
        return :skip
      end
    when "Wallman"
      # Don't copy Wallman's 9999 HP, use a more reasonable value instead.
      new_boss["HP"] = 4000
      new_boss.write_to_rom()
    end
    
    if new_boss.name != "Giant Skeleton"
      boss_entity.room.entities.each do |entity|
        if entity.type == 0x02 && entity.subtype == 0x3E && entity.var_a == 0x01
          # Searchlights in Giant Skeleton's boss room. These will soft lock the game if Giant Skeleton isn't here, so we need to tweak it a bit.
          entity.var_a = 0x00
          entity.write_to_rom()
        end
      end
    end
    
    case new_boss.name
    when "Wallman"
      # We don't want Wallman to be offscreen because then he's impossible to defeat.
      boss_entity.x_pos = 0xCC
      boss_entity.y_pos = 0xAF
      
      # Make sure Wallman always has 9999 HP.
      new_boss["HP"] = 9999
      new_boss.write_to_rom()
    end
  end
end
