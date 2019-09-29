
module BossRandomizer
  def randomize_bosses
    verbose = false
    
    puts "Shuffling bosses:" if verbose
    
    if GAME == "dos"
      # The Aguni placed by the boss randomizer does not require Paranoia to reach.
      checker.remove_aguni_paranoia_requirement()
    end
    
    dos_randomize_final_boss()
    
    boss_entities = []
    game.each_room do |room|
      boss_entities_for_room = room.entities.select do |entity|
        if !entity.is_boss?
          next
        end
        boss_id = entity.subtype
        if !RANDOMIZABLE_BOSS_IDS.include?(boss_id)
          next
        end
        
        boss = game.enemy_dnas[boss_id]
        if GAME == "por" && boss.name == "Stella" && entity.var_a == 1
          # Don't randomize the Stella who initiates the sisters fight (in either Master's Keep or Nest of Evil).
          next
        end
        if GAME == "por" && boss.name == "The Creature" && entity.var_a == 0
          # Don't randomize the common enemy version of The Creature.
          next
        end
        
        true
      end
      boss_entities += boss_entities_for_room
    end
    
    remove_boss_cutscenes()
    
    if GAME == "dos"
      # Turn the throne room Dario entity into Aguni so the boss randomizer logic works.
      throne_room_dario = game.areas[0].sectors[9].rooms[1].entities[6]
      throne_room_dario.subtype = 0x70
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
    # Print all swaps that work.
    #boss_swaps_that_work.each do |old_boss_id, valid_new_boss_ids|
    #  old_boss = game.enemy_dnas[old_boss_id]
    #  puts "Boss %02X (#{old_boss.name}) can be swapped with:" % [old_boss_id]
    #  valid_new_boss_ids.each do |new_boss_id|
    #    new_boss = game.enemy_dnas[new_boss_id]
    #    puts "  Boss %02X (#{new_boss.name})" % [new_boss_id]
    #  end
    #end
    
    remaining_boss_ids = RANDOMIZABLE_BOSS_IDS.dup
    queued_dna_changes = Hash.new{|h, k| h[k] = {}}
    already_randomized_bosses = {}
    if GAME == "dos"
      @original_boss_seals = {}
      (0..0x11).each do |boss_index|
        seal_index = game.fs.read(MAGIC_SEAL_FOR_BOSS_LIST_START+boss_index*4, 4).unpack("V").first
        @original_boss_seals[boss_index] = seal_index
      end
    end
    
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
          #puts "BOSS %02X FAILED!" % old_boss_id
          next
        end
        
        if possible_boss_ids_for_this_boss.length > 1
          # Don't allow the boss to be in its vanilla location unless that's the only valid option left.
          possible_boss_ids_for_this_boss -= [old_boss_id]
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
      
      puts "  Replacing boss %02X (#{old_boss.name}) with boss %02X (#{new_boss.name})" % [old_boss_id, new_boss_id] if verbose
      
      boss_entity.subtype = new_boss_id
      remaining_boss_ids.delete(new_boss_id)
      remaining_boss_ids.delete(old_boss_id)
      
      boss_entity.write_to_rom()
      
      already_randomized_bosses[old_boss_id] = new_boss_id
      already_randomized_bosses[new_boss_id] = old_boss_id
      
      update_boss_doors(old_boss_id, new_boss_id, boss_entity)
      
      # Give the new boss the old boss's soul so progression still works.
      queued_dna_changes[new_boss_id]["Soul"] = old_boss["Soul"]
      if old_boss["Soul"] == 0xFF
        # Some bosses such as Flying Armor won't open the boss doors until the player gets their soul drop.
        # So we have to make sure no bosses have no soul drop (FF). Just give them a non-progress soul so they drop something.
        non_progression_souls = SKILL_GLOBAL_ID_RANGE.to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        queued_dna_changes[new_boss_id]["Soul"] = non_progression_souls.sample(random: rng) - SKILL_GLOBAL_ID_RANGE.begin
      end
      
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
      coll = get_room_collision(boss_entity.room)
      (0x40..0xC0).each do |x|
        # If the floor is 2 tiles high instead of 1, the player won't have room to crouch under Balore' huge laser.
        if coll[x,0xA0].is_solid?
          return false
        end
      end
    when "Puppet Master"
      # If Puppet Master is in a room less than 2 screens wide he can teleport the player out of bounds.
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
    case new_boss.name
    when "Behemoth"
      if boss_entity.room.width < 2
        # Behemoth hits the player the instant they enter the room if it's only 1 screen wide.
        return false
      end
    when "Legion"
      if boss_entity.room.width < 2
        return false
      end
    when "Dagon"
      if old_boss.name == "Legion"
        # Legion's strange room won't work with Dagon.
        return false
      end
    when "Werewolf"
      if old_boss.name == "Brauner"
        # Brauner's room uses up too many GFX pages because of the portrait to the throne room, so Werewolf can't load in.
        return false
      end
    when "Medusa"
      if boss_entity.room.width < 2
        return false
      end
    when "Brauner"
      if boss_entity.room.width < 2
        return false
      end
    end
    
    return true
  end
  
  def ooe_check_boss_works_in_room(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    case new_boss.name
    when "Maneater"
      # Maneater needs a wide room or his boss orb will be stuck inside the wall.
      if boss_entity.room.width < 2
        return false
      end
    when "Goliath"
      # Goliath never attacks the player in a 1x1 room. (Also the intro cutscene can make the player take unavoidable damage.)
      if boss_entity.room.width < 2
        return false
      end
    when "Blackmore"
      # Blackmore needs a wide room.
      if boss_entity.room.width < 2
        return false
      end
    end
    
    return true
  end
  
  def dos_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    new_boss_index = BOSS_ID_TO_BOSS_INDEX[new_boss_id] || 0
    
    case old_boss.name
    when "Balore"
      if boss_entity.var_a == 2
        # Not actually Balore, this is the wall of ice blocks right before Balore.
        # We need to get rid of this because having this + a different boss besides Balore in the same room will load two different overlays into the same spot and crash the game.
        boss_entity.type = 0
        boss_entity.write_to_rom()
        return :skip
      else
        # Update the entity hider so the common enemies in the room don't appear until the randomized boss is dead.
        entity_hider = game.entity_by_str("00-02-06_03")
        entity_hider.subtype = new_boss_index
        entity_hider.write_to_rom()
      end
    when "Dmitrii"
      # Update the entity hider so the common enemy in the room doesn't appear until the randomized boss is dead.
      entity_hider = game.entity_by_str("00-04-10_08")
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
    when "Gergoth"
      if GAME == "dos" && boss_entity.room.sector_index == 5
        # Condemned Tower. Replace the boss death flag checked by the floors of the tower so they check the new boss instead.
        game.fs.replace_hardcoded_bit_constant(0x0219EF44, new_boss_index)
        
        # Update the entity hider so the common enemies in the room don't appear until the randomized boss is dead.
        entity_hider = game.entity_by_str("00-05-07_14")
        entity_hider.subtype = new_boss_index
        entity_hider.write_to_rom()
      end
    when "Paranoia"
      if boss_entity.var_a == 1
        # Mini-Paranoia. Remove him since he doesn't work properly when Paranoia is randomized.
        boss_entity.type = 0
        boss_entity.write_to_rom()
        
        # And remove Mini-Paranoia's boss doors.
        inside_boss_door_right = game.entity_by_str("00-01-20_03")
        inside_boss_door_right.type = 0
        inside_boss_door_right.write_to_rom()
        outside_boss_door = game.entity_by_str("00-01-22_00")
        outside_boss_door.type = 0
        outside_boss_door.write_to_rom()
        # And change the boss door connecting Mini-Paranoia's room to Paranoias to not require killing a boss to open.
        inside_boss_door_left = game.entity_by_str("00-01-20_04")
        inside_boss_door_left.var_a = 0
        inside_boss_door_left.write_to_rom()
        
        return :skip
      end
    end
    
    case new_boss.name
    when "Flying Armor"
      boss_entity.var_a = 0 # Boss rush
      boss_entity.var_b = 0 # Boss rush
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0x50
    when "Balore"
      # Defaults to right-facing Balore.
      # But Balore's code has been modified so that he will face left and reposition himself if the player comes from the left.
      boss_entity.var_a = 1
      boss_entity.var_b = 0
      boss_entity.x_pos = 0x10
      boss_entity.y_pos = 0xB0
      
      if old_boss.name == "Puppet Master"
        # Puppet Master's room's left wall is farther to the right than most.
        boss_entity.x_pos += 0x90
      end
    when "Malphas"
      boss_entity.var_a = 0
      boss_entity.var_b = 0 # Normal
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
    when "Dmitrii"
      boss_entity.var_a = 0 # Boss rush Dmitrii, doesn't crash when there are no events.
      boss_entity.var_b = 0
    when "Dario"
      boss_entity.var_a = 0
      boss_entity.var_b = 0 # Normal (not with Aguni)
    when "Puppet Master"
      boss_entity.var_a = 1 # Normal
      boss_entity.var_b = 0
      
      if old_boss.name == "Puppet Master"
        # Puppet Master's in his original room.
        boss_entity.x_pos = 0x148
        boss_entity.y_pos = 0x60
      else
        # Not in his original room, so the left edge isn't missing.
        # First center him in the room.
        boss_entity.x_pos = 0x100
        boss_entity.y_pos = 0x60
        
        if old_boss.name == "Rahab"
          # Move Puppet Master down a bit so the player can reach him and his iron maidens easier from the water.
          boss_entity.y_pos = 0x70
        end
        
        # Also update a hardcoded position for his limbs to appear at.
        game.fs.load_overlay(25)
        game.fs.write(0x023052B0, [boss_entity.x_pos, boss_entity.y_pos].pack("vv"))
        
        # And the hardcoded position for his iron maidens to appear at.
        game.fs.write(0x02305350, [boss_entity.x_pos+0x68, boss_entity.y_pos-0x38].pack("vv"))
        game.fs.write(0x02305354, [boss_entity.x_pos+0x68, boss_entity.y_pos+0x38].pack("vv"))
        game.fs.write(0x02305358, [boss_entity.x_pos-0x68, boss_entity.y_pos-0x38].pack("vv"))
        game.fs.write(0x0230535C, [boss_entity.x_pos-0x68, boss_entity.y_pos+0x38].pack("vv"))
        # And the platforms under the upper iron maidens.
        game.fs.write(0x023052E4, [boss_entity.x_pos+0x68, boss_entity.y_pos-0x18].pack("vv"))
        game.fs.write(0x023052E8, [boss_entity.x_pos-0x68, boss_entity.y_pos-0x18].pack("vv"))
        # And the positions Soma is teleported to.
        game.fs.write(0x02305370, [boss_entity.x_pos+0x68, boss_entity.y_pos-0x38+0x17].pack("vv"))
        game.fs.write(0x02305374, [boss_entity.x_pos+0x68, boss_entity.y_pos+0x38+0x17].pack("vv"))
        game.fs.write(0x02305378, [boss_entity.x_pos-0x68, boss_entity.y_pos-0x38+0x17].pack("vv"))
        game.fs.write(0x0230537C, [boss_entity.x_pos-0x68, boss_entity.y_pos+0x38+0x17].pack("vv"))
        # And the positions of the blood created when Soma is damaged by the iron maidens.
        game.fs.write(0x02305390, [boss_entity.x_pos+0x68, boss_entity.y_pos-0x38+0x14].pack("vv"))
        game.fs.write(0x02305394, [boss_entity.x_pos+0x68, boss_entity.y_pos+0x38+0x14].pack("vv"))
        game.fs.write(0x02305398, [boss_entity.x_pos-0x68, boss_entity.y_pos-0x38+0x14].pack("vv"))
        game.fs.write(0x0230539C, [boss_entity.x_pos-0x68, boss_entity.y_pos+0x38+0x14].pack("vv"))
        
        # And remove the code that usually sets the minimum screen scrolling position to hide the missing left side of the screen.
        game.fs.write(0x022FFC1C, [0xE1A00000].pack("V")) # nop (for when he's alive)
        game.fs.write(0x022FFA40, [0xE1A00000].pack("V")) # nop (for after he's dead)
      end
    when "Gergoth"
      if old_boss_id == new_boss_id && GAME == "dos"
        # Normal Gergoth since he's in his tower.
        boss_entity.var_a = 1
      else
        # Set Gergoth to boss rush mode.
        boss_entity.var_a = 0
      end
      boss_entity.var_b = 0
    when "Zephyr"
      # Center him in the room.
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      
      if boss_entity.room.width < 2
        # Small room, so we need boss rush Zephyr. Normal Zephyr's intro cutscene doesn't work unless the room is 2 screens tall or more.
        boss_entity.var_a = 0
      else
        # Normal Zephyr, with the cutscene.
        boss_entity.var_a = 1
      end
      boss_entity.var_b = 0
    when "Bat Company"
      boss_entity.var_a = 1 # Normal
      boss_entity.var_b = 0
    when "Paranoia"
      boss_entity.var_a = 2 # Normal
      boss_entity.var_b = 0
      
      # If Paranoia spawns in Gergoth's tall tower, his position and the position of his mirrors can become disjointed.
      # This combination of x and y seems to be one of the least buggy.
      boss_entity.x_pos = 0x1F
      boss_entity.y_pos = 0x80
    when "Aguni"
      boss_entity.var_a = 0
      boss_entity.var_b = 0
    when "Death"
      boss_entity.var_a = 1 # Normal
      boss_entity.var_b = 1 # Normal
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0x50
      
      # If there are any extra objects in Death's room, he will softlock the game when you kill him.
      # That's because Death's GFX takes up so much space that there's barely any room for his magic seal's GFX to be loaded.
      # So remove any candles in the room, since they're not necessary.
      boss_entity.room.entities.each do |entity|
        if entity.is_special_object? && entity.subtype == 1 && entity.var_a != 0
          entity.type = 0
          entity.write_to_rom()
        end
      end
    when "Abaddon"
      boss_entity.var_a = 1 # Normal
      boss_entity.var_b = 0
      
      # Abaddon's locusts always appear on the top left screen, so make sure he's there as well.
      boss_entity.x_pos = 0x80
      boss_entity.y_pos = 0xB0
    end
  end
  
  def por_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    new_boss_index = BOSS_ID_TO_BOSS_INDEX[new_boss_id] || 0
    
    case old_boss.name
    when "Dullahan"
      @boss_id_for_each_portrait[:portrait_city_of_haze] = new_boss_id
    when "Behemoth"
      if boss_entity.var_b == 2
        # Scripted Behemoth that chases you down the hallway.
        return :skip
      end
    when "Astarte"
      @boss_id_for_each_portrait[:portrait_sandy_grave] = new_boss_id
    when "Legion"
      @boss_id_for_each_portrait[:portrait_nation_of_fools] = new_boss_id
      
      # Legion's horizontal boss door is hardcoded to check Legion's boss death flag.
      # Update these checks to check the updated boss death flag.
      game.fs.load_overlay(98)
      game.fs.replace_hardcoded_bit_constant(0x022E8B94, new_boss_index)
      game.fs.replace_hardcoded_bit_constant(0x022E888C, new_boss_index)
      
      if new_boss.name != "Legion" && boss_entity.room.room_str == "05-02-0C"
        # The big Nation of Fools boss room for Legion can be entered from multiple angles, but the boss should only activate when entered from the top.
        # In vanilla Legion is coded to not appear until you get the item in the center, but other bosses are not coded to do that.
        # So instead we need to use an entity hider to hide the boss entity under normal circumstances.
        # We modify the horizontal boss door's create code to set a flag that tells that entity hider to stop hiding the entity when the player enters from the top.
        # The reason this works is because the game engine calls the create code for an entity while it's still in the middle of reading the entity list. So we have a chance to set the flag before the engine gets to the entity hider and checks that condition.
        
        # Add an entity hider that hides the boss when the flag for being in a boss fight is NOT set.
        entity_hider = boss_entity.room.add_new_entity()
        entity_hider.type = 8 # Entity hider
        entity_hider.var_a = 3 # Check if the flag for being in a boss fight is set.
        entity_hider.byte_8 = 1 # Hide 1 entity
        # Reorder it so the entity hider comes before the boss (entity index 2).
        boss_entity.room.entities.delete(entity_hider)
        boss_entity.room.entities.insert(2, entity_hider)
        boss_entity.room.write_entities_to_rom()
        
        # Originally this line set global game flag 01. Change it to set both 01 and 02, since 02 is the flag for being in a boss fight.
        game.fs.load_overlay(98)
        game.fs.replace_arm_shifted_immediate_integer(0x022E88E4, 0x03)
      end
    when "Dagon"
      @boss_id_for_each_portrait[:portrait_forest_of_doom] = new_boss_id
      
      if new_boss.name != "Dagon"
        # If Dagon's not in his own room, there won't be any water there, so you can't get out of the room without griffon wing/owl morph.
        # So add a platform to Dagon's room that moves up and down to prevent this.
        platform = boss_entity.room.add_new_entity()
        platform.type = SPECIAL_OBJECT_ENTITY_TYPE
        platform.subtype = 0x3F
        platform.x_pos = 0x80
        platform.y_pos = 0x80
        platform.write_to_rom()
      end
    when "The Creature"
      @boss_id_for_each_portrait[:portrait_dark_academy] = new_boss_id
    when "Werewolf"
      @boss_id_for_each_portrait[:portrait_13th_street] = new_boss_id
    when "Medusa"
      @boss_id_for_each_portrait[:portrait_burnt_paradise] = new_boss_id
    when "Mummy Man"
      @boss_id_for_each_portrait[:portrait_forgotten_city] = new_boss_id
    when "Brauner"
      @boss_id_inside_studio_portrait = new_boss_id
      
      # Modify the entity hiders in Brauner's room that make the post-Brauner cutscene appear to check the new boss.
      entity_hider = game.entity_by_str("0B-00-00_04")
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
      entity_hider = game.entity_by_str("0B-00-00_08")
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
      # Modify the entity hiders that swap the studio portrait object after Brauner is dead to instead check the new boss.
      entity_hider = game.entity_by_str("00-0B-00_05")
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
      entity_hider = game.entity_by_str("00-0B-00_07")
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
    end
    
    case new_boss.name
    when "Dullahan"
      boss_entity.var_a = 1 # Normal with intro, not boss rush
      boss_entity.var_b = 0
    when "Behemoth"
      boss_entity.var_a = 1 # Stays dead when killed
      boss_entity.var_b = 0 # Normal
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      
      # TODO: Behemoth can be undodgeable without those jumpthrough platforms in the room, so add those
    when "Keremet"
      boss_entity.var_a = 1 # Normal
      boss_entity.var_b = 0
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0xB0
    when "Astarte"
      boss_entity.var_a = 0
      boss_entity.var_b = 0
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0xB0
    when "Legion"
      if old_boss.name == "Legion"
        boss_entity.var_a = 1 # Normal
        
        boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
        boss_entity.y_pos = 0x150
      else
        boss_entity.var_a = 0 # Boss rush
        
        boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
        boss_entity.y_pos = 0xB0
      end
      boss_entity.var_b = 0
    when "Dagon"
      boss_entity.var_a = 1 # Normal, with intro
      boss_entity.var_b = 0
      
      if boss_entity.room.height == 1
        # Dagon's water level maximum would normally be at the Y pos (0x48*room_height).
        # But for rooms that are only 1 screen tall, that would make the water fill up too slowly to dodge Dagon's water spitting attack.
        # So in this case change the maximum water level Y position to -0x30, which puts it at the some position relative to Dagon as it would be in vanilla.
        game.fs.load_overlay(59)
        game.fs.write(0x022DB854, [0xE3E0202F].pack("V")) # mov r2, -30h
      end
    when "Death"
      boss_entity.var_a = 0 # Solo Death (not with Dracula)
      boss_entity.var_b = 0 # Starts fighting immediately, not waiting for cutscene to finish
    when "Stella"
      boss_entity.var_a = 0 # Just Stella, we don't want Stella&Loretta.
      boss_entity.var_b = 0 # Boss rush.
    when "The Creature"
      boss_entity.var_a = 1 # Boss version, not the common enemy version
      boss_entity.var_b = 0
    when "Werewolf"
      boss_entity.var_a = 1 # Normal version with intro, not boss rush. Stays dead when boss death flag is set.
      boss_entity.var_b = 0
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
    when "Mummy Man"
      boss_entity.var_a = 1 # Normal version with intro.
      boss_entity.var_b = 0
      
      boss_entity.y_pos = boss_entity.room.height * SCREEN_HEIGHT_IN_PIXELS - 0x2C
    when "Brauner"
      boss_entity.var_a = 0 # Boss rush Brauner, doesn't try to reload the room when he dies.
      boss_entity.var_b = 0 # Don't flash the screen white
      
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0xB0
    end
  end
  
  def ooe_adjust_randomized_boss(boss_entity, old_boss_id, new_boss_id, old_boss, new_boss)
    new_boss_index = BOSS_ID_TO_BOSS_INDEX[new_boss_id] || 0
    
    case old_boss.name
    when "Giant Skeleton"
      if boss_entity.var_a == 0
        # Non-boss version of the giant skeleton.
        return :skip
      elsif new_boss.name != "Giant Skeleton"
        boss_entity.room.entities.each do |entity|
          if entity.type == 2 && entity.subtype == 0x3E && entity.var_a == 1
            # Searchlights in Giant Skeleton's boss room. These will soft lock the game if Giant Skeleton isn't here, so we need to remove them.
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
    when "Albus"
      # Fix the cutscene before the boss fight leaving the screen faded out to white forever.
      game.fs.load_overlay(60)
      game.fs.write(0x022C2494, [0xE3A01010].pack("V")) # mov r1, 10h (Number of frames for the fade in to take)
      game.fs.write(0x022C2494, [0xE3A02010].pack("V")) # mov r2, 10h (Make the fade in start at white since that's what the fade out left it at)
      
      # Change the X pos you get put at by the cutscene right before the boss.
      # Originally it put you at X pos 0xC0, but that could cause you to immediately take unavoidable damage from big bosses.
      game.fs.load_overlay(60)
      game.fs.write(0x022C24E4, [0x80].pack("C"))
      
      # Update the boss death flag checked by the entity hider so the cutscene after the boss triggers when the randomized boss is dead, instead of Albus.
      entity_hider = boss_entity.room.entities[5]
      entity_hider.subtype = new_boss_index
      entity_hider.write_to_rom()
    when "Barlowe"
      # Barlowe's boss room has Ecclesia doors instead of regular doors.
      # We want it to have a normal boss door so that it sets the "in a boss fight" flag when you enter the room.
      # But we only want the normal boss door to appear when the fight is active - not before the story has progressed that far.
      # So we make use of the boss door in the room that usually only appears in boss rush.
      # By changing the boss rush entity hider to hide 2 entities instead of 3, it no longer hides the boss door.
      # But there's an earlier entity hider in the list that still hides it before the story has progressed to the Barlowe fight.
      boss_rush_entity_hider = boss_entity.room.entities[8]
      boss_rush_entity_hider.byte_8 = 2
      boss_rush_entity_hider.write_to_rom()
      
      # Fix the cutscene before the boss fight leaving the screen faded out to white forever.
      game.fs.load_overlay(42)
      game.fs.write(0x022C5FDC, [0xE3A01010].pack("V")) # mov r1, 10h (Number of frames for the fade in to take)
      game.fs.write(0x022C5FEC, [0xE3A02010].pack("V")) # mov r2, 10h (Make the fade in start at white since that's what the fade out left it at)
      
      # Change the X pos you get put at by the cutscene right before the boss.
      # Originally it kept whatever X pos the player was at when the cutscene finished, but depending on what the randomized boss isand when the player skips the cutscene, that could cause you to immediately take unavoidable damage from big bosses.
      game.fs.load_overlay(42)
      game.fs.write(0x022C6054, [0xE3A03080].pack("V")) # mov r3, 80h
      
      # Fix the cutscene after the boss so that it knows to start when the randomized boss is dead, instead of Barlowe.
      game.fs.load_overlay(42)
      game.fs.replace_hardcoded_bit_constant(0x0223784C, new_boss_index)
      # And make it so the NPC Barlowe no longer spawns after the randomized boss is dead.
      game.fs.replace_hardcoded_bit_constant(0x0223790C, new_boss_index)
    end
    
    case new_boss.name
    when "Arthroverta"
      # Add two magnes points to rooms with Arthroverta in them to help dodging.
      magnes_point_1 = boss_entity.room.add_new_entity()
      magnes_point_1.type = SPECIAL_OBJECT_ENTITY_TYPE
      magnes_point_1.subtype = 1
      magnes_point_1.x_pos = 0x40
      magnes_point_1.y_pos = 0x28
      magnes_point_1.write_to_rom()
      
      magnes_point_2 = boss_entity.room.add_new_entity()
      magnes_point_2.type = SPECIAL_OBJECT_ENTITY_TYPE
      magnes_point_2.subtype = 1
      magnes_point_2.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS - 0x40
      magnes_point_2.y_pos = 0x28
      magnes_point_2.write_to_rom()
    when "Giant Skeleton"
      boss_entity.var_a = 1 # Boss version of the Giant Skeleton
      boss_entity.var_b = 0 # Faces the player when they enter the room.
      
      # The boss version of the Giant Skeleton doesn't wake up until the searchlight is on him, but there's no searchlight in other boss rooms.
      # So we modify the line of code that checks if he should wake up to use the code for the common enemy Giant Skeleton instead.
      game.fs.write(0x02277EFC, [0xE3A01000].pack("V"))
      
      # Update the positions of spawned entities in case the room size is different.
      game.fs.replace_arm_shifted_immediate_integer(0x02279328, boss_entity.x_pos*0x1000) # No damage blue chest X pos
    when "Maneater"
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0xB0
    when "Rusalka"
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0xA0
      
      # Update the positions of spawned entities in case the room size is different.
      game.fs.load_overlay(27)
      game.fs.replace_arm_shifted_immediate_integer(0x022BB628, boss_entity.x_pos*0x1000) # No damage blue chest X pos
      
      # TODO: rusalka (in barlowe's room at least) doesn't play all sound effects, and her splash attack is invisible.
    when "Gravedorcus"
      # Gravedorcus normally crashes because it calls functions in Oblivion Ridge's sector overlay.
      # It's possible to avoid the crashes by replacing all calls in the missing sector overlay with "mov r0, 0h".
      # These are the known places Gravedorcus makes calls like that:
      # 0x022BA234
      # 0x022BA23C
      # 0x022BA270
      # 0x022BA278
      # 0x022B8400
      # 0x022B8430
      # 0x022B954C
      # 0x022B9554
      # However Gravedorcus constantly goes offscreen in any boss room besides its own because the room isn't wide enough, so it's not the most interesting boss to randomize.
    when "Albus"
      if !["Albus", "Barlowe"].include?(old_boss.name)
        # We don't want Albus to reload the room when he dies in most boss rooms.
        # Only for Albus or Barlowe's rooms since those have a cutscene that needs to play after it.
        game.fs.load_overlay(36)
        game.fs.write(0x022B8DB4, [0xEA000008].pack("V")) # "b 022B8DDCh" Always jump to the code he would use in Albus/boss rush mode
      end
    when "Barlowe"
      if !["Albus", "Barlowe"].include?(old_boss.name)
        # We don't want Barlowe to reload the room when he dies in most boss rooms.
        # Only for Albus or Barlowe's rooms since those have a cutscene that needs to play after it.
        game.fs.load_overlay(37)
        game.fs.write(0x022B8230, [0xEA00000D].pack("V")) # "b 022B826Ch" Always jump to the code he would use in Albus mode
      end
    when "Wallman"
      # We don't want Wallman to be offscreen because then he's impossible to defeat.
      boss_entity.x_pos = 0xCC
      boss_entity.y_pos = 0xAF
    when "Blackmore"
      # Blackmore needs to be in this position or he becomes very aggressive and corners the player up against the wall.
      boss_entity.x_pos = 0x100
      boss_entity.y_pos = 0xA0
    when "Death"
      boss_entity.x_pos = boss_entity.room.width * SCREEN_WIDTH_IN_PIXELS / 2
      boss_entity.y_pos = 0x70
      
      # Update the positions of spawned entities in case the room size is different.
      game.fs.load_overlay(25)
      game.fs.replace_arm_shifted_immediate_integer(0x022BBCB0, boss_entity.x_pos*0x1000) # Boss orb X pos
      game.fs.replace_arm_shifted_immediate_integer(0x022BC2D8, boss_entity.x_pos*0x1000) # No damage blue chest X pos
      
      if old_boss.name != "Death"
        # Death knows when to come out of the background by checking the relative scroll positions of two of the background layers.
        # But when placed into a room that doesn't scroll the same as his vanilla room he will never come out of the background, softlocking the game.
        # So remove the background scrolling requirement and have him immediately come out of the background.
        game.fs.load_overlay(25)
        game.fs.write(0x022BBD68, [0xE1A00000].pack("V")) # nop
      end
    when "Jiang Shi"
      unless old_boss.name == "Jiang Shi"
        # Jiang Shi needs a special object in his room for the boss doors to open since he doesn't die.
        room = boss_entity.room
        door_opener = Entity.new(room, room.fs)
        
        door_opener.y_pos = 0x80
        door_opener.type = 2
        door_opener.subtype = 0x24
        door_opener.var_a = 1
        
        room.entities << door_opener
        room.write_entities_to_rom()
      end
    end
  end
  
  DOS_FINAL_BOSS_TELEPORT_DATA = {
    :menace => [0xA, 0, 2, 0x80, 0xA0].pack("CCvvv"),
    :somacula => [0x10, 0, 2, 0x1A0, 0xB0].pack("CCvvv"),
  }
  
  def dos_set_soma_mode_final_boss(final_boss_name)
    return unless GAME == "dos"
    
    final_boss_tele_data = DOS_FINAL_BOSS_TELEPORT_DATA[final_boss_name]
    if final_boss_tele_data.nil?
      raise "Invalid final boss name: #{final_boss_name}"
    end
    
    game.fs.write(0x0222BE14, final_boss_tele_data)
  end
  
  # Menace doesn't appear in Julius mode.
  #def dos_set_julius_mode_final_boss(final_boss_name)
  #  return unless GAME == "dos"
  #  
  #  final_boss_tele_data = DOS_FINAL_BOSS_TELEPORT_DATA[final_boss_name]
  #  if final_boss_tele_data.nil?
  #    raise "Invalid final boss name: #{final_boss_name}"
  #  end
  #  
  #  game.fs.write(0x0222BE1C, final_boss_tele_data)
  #end
  
  def dos_randomize_final_boss
    return unless GAME == "dos"
    
    soma_mode_final_boss = [:menace, :somacula].sample(random: rng)
    dos_set_soma_mode_final_boss(soma_mode_final_boss)
    
    #julius_mode_final_boss = [:menace, :somacula].sample(random: rng)
    #dos_set_julius_mode_final_boss(julius_mode_final_boss)
  end
  
  def update_boss_doors(old_boss_id, new_boss_id, boss_entity)
    # Update the boss doors for the new boss
    old_boss_index = BOSS_ID_TO_BOSS_INDEX[old_boss_id] || 0
    new_boss_index = BOSS_ID_TO_BOSS_INDEX[new_boss_id] || 0
    rooms_to_check = [boss_entity.room]
    rooms_to_check += boss_entity.room.connected_rooms
    rooms_to_check.each do |room|
      room.entities.each do |entity|
        if entity.type == 0x02 && entity.subtype == BOSS_DOOR_SUBTYPE && entity.var_b == old_boss_index
          entity.var_b = new_boss_index
          
          entity.write_to_rom()
        end
      end
    end
    
    if GAME == "dos"
      # Make the boss door use the same seal as the boss that was originally in this position so progression isn't affected.
      original_boss_door_seal = @original_boss_seals[old_boss_index]
      game.fs.write(MAGIC_SEAL_FOR_BOSS_LIST_START+new_boss_index*4, [original_boss_door_seal].pack("V"))
    end
  end
  
  def remove_boss_cutscenes
    # Boss cutscenes usually don't work without the original boss.
    
    obj_subtypes_to_remove = case GAME
    when "dos"
      [0x61, 0x63, 0x64, 0x69]
    when "por"
      [0x9A, 0x9D, 0xA0]
    when "ooe"
      []
    end
    
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_special_object? && obj_subtypes_to_remove.include?(entity.subtype)
          entity.type = 0
          entity.write_to_rom()
        end
      end
    end
    
    if GAME == "dos"
      dmitriis_malachi = game.areas[0].sectors[4].rooms[0x10].entities[6]
      dmitriis_malachi.type = 0
      dmitriis_malachi.write_to_rom()
    end
  end
end
