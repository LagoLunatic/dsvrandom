
module PickupRandomizer
  def randomize_pickups_completably
    spoiler_log.puts "Randomizing pickups:"
    
    case GAME
    when "dos"
      checker.add_item(0x3D) # seal 1
      
      if options[:unlock_boss_doors]
        checker.add_item(0x3E) # seal 2
        checker.add_item(0x3F) # seal 3
        checker.add_item(0x40) # seal 4
        checker.add_item(0x41) # seal 5
      end
      
      # For DoS we sometimes need pickup flags for when a soul candle gets randomized into something that's not a soul candle.
      # Flags 7A-7F are unused in the base game but still work, so use those.
      @unused_picked_up_flags = (0x7A..0x7F).to_a
    when "por"
      checker.add_item(0x1AD) # call cube
      
      if options[:dont_randomize_change_cube]
        checker.add_item(0x1AC) # change cube
        change_entity_location_to_pickup_global_id("00-00-01_01", 0x1AC)
      else
        # If the player doesn't start with change cube, give them skill cube instead so they can still use Charlotte's spells.
        checker.add_item(0x1AE) # skill cube
        change_entity_location_to_pickup_global_id("00-00-01_01", 0x1AE)
      end
      
      # In the corridor where Behemoth chases you, change the code of the platform to not permanently disappear.
      # This is so the player can't get stuck if they miss an important item up there.
      game.fs.load_overlay(79)
      game.fs.write(0x022EC638, [0xEA000003].pack("V"))
      
      # We don't need spare pickup flags for PoR.
      @unused_picked_up_flags = []
    when "ooe"
      checker.add_item(0x6F) # lizard tail
      checker.add_item(0x72) # glyph union
      checker.add_item(0x1E) # torpor. the player will get enough of these as it is
      
      # For OoE we sometimes need pickup flags for when a glyph statue gets randomized into something that's not a glyph statue.
      # Flags 12F-149 are unused in the base game but still work, so use those.
      @unused_picked_up_flags = (0x12F..0x149).to_a
      
      # Give the player the glyph sleeve in Ecclesia like in hard mode.
      # To do this just get rid of the entity hider that hides it on normal mode.
      entity_hider = game.areas[2].sectors[0].rooms[4].entities[6]
      entity_hider.type = 0
      entity_hider.write_to_rom()
      # But we also need to give the chest a unique flag, because it shares the flag with the one from Minera in normal mode.
      sleeve_chest = game.areas[2].sectors[0].rooms[4].entities[7]
      sleeve_chest.var_b = @unused_picked_up_flags.pop()
      # We also make sure the chest in Minera appears even on hard mode.
      entity_hider = game.areas[8].sectors[2].rooms[7].entities[1]
      entity_hider.type = 0
      entity_hider.write_to_rom()
      checker.add_item(0x73) # glyph sleeve
      
      # Glyph given by Barlowe. We randomize this, but only to a starter physical weapon glyph, not to any glyph.
      possible_starter_weapons = [0x01, 0x04, 0x07, 0x0A, 0x0D, 0x10, 0x13, 0x16]
      pickup_global_id = possible_starter_weapons.sample(random: rng)
      game.fs.load_overlay(42)
      game.fs.write(0x022C3980, [0xE3A01000].pack("V"))
      game.fs.write(0x022C3980, [pickup_global_id+1].pack("C"))
      checker.add_item(pickup_global_id)
      @ooe_starter_glyph_id = pickup_global_id # Tell the skill stat randomizer what the start glyph is so it doesn't randomize it
    end
    
    place_progression_pickups()
    
    if !checker.game_beatable?
      item_names = checker.current_items.map do |global_id|
        checker.defs.invert[global_id]
      end
      raise "Bug: Game is not beatable on this seed!\nThis error shouldn't happen.\nSeed: #{@seed}\n\nItems:\n#{item_names.join(", ")}"
    end
  end
  
  def place_progression_pickups
    previous_accessible_locations = []
    @locations_randomized_to_have_useful_pickups = []
    on_leftovers = false
    # First place progression pickups needed to beat the game.
    spoiler_log.puts "Placing main route progression pickups:"
    while true
      case GAME
      when "por"
        if !checker.current_items.include?(0x1B2) && checker.check_reqs([[:midentrance]])
          checker.add_item(0x1B2) # give lizard tail if the player has reached wind
        end
      end
      
      pickups_by_locations = checker.pickups_by_current_num_locations_they_access()
      pickups_by_usefulness = pickups_by_locations.select{|pickup, num_locations| num_locations > 0}
      if pickups_by_usefulness.any?
        max_usefulness = pickups_by_usefulness.values.max
        
        weights = pickups_by_usefulness.map do |pickup, usefulness|
          # Weight less useful pickups as being more likely to be chosen.
          weight = max_usefulness - usefulness + 1
          Math.sqrt(weight)
        end
        ps = weights.map{|w| w.to_f / weights.reduce(:+)}
        useful_pickups = pickups_by_usefulness.keys
        weighted_useful_pickups = useful_pickups.zip(ps).to_h
        pickup_global_id = weighted_useful_pickups.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
        
        weighted_useful_pickups_names = weighted_useful_pickups.map do |global_id, weight|
          "%.2f %s" % [weight, checker.defs.invert[global_id]]
        end
        #puts "Weighted less useful pickups: [" + weighted_useful_pickups_names.join(", ") + "]"
      elsif pickups_by_locations.any? && checker.game_beatable?
        # The player can access all locations.
        # So we just randomly place one progression pickup.
        
        if !on_leftovers
          spoiler_log.puts "Placing leftover progression pickups:"
          on_leftovers = true
        end
        
        pickup_global_id = pickups_by_locations.keys.sample(random: rng)
      elsif pickups_by_locations.any?
        # No locations can access new areas, but the game isn't beatable yet.
        # This means any new areas will need at least two new items to access.
        # So just place random pickup for now.
        
        pickup_global_id = pickups_by_locations.keys.sample(random: rng)
      else
        # All progression pickups placed.
        break
      end
      
      possible_locations = checker.get_accessible_locations()
      possible_locations -= @locations_randomized_to_have_useful_pickups
      
      if !options[:randomize_boss_souls]
        # If randomize boss souls option is off, don't allow putting random things in these locations.
        accessible_unused_boss_locations = possible_locations & checker.enemy_locations
        accessible_unused_boss_locations.each do |location|
          possible_locations.delete(location)
          @locations_randomized_to_have_useful_pickups << location
          
          # Also, give the player what this boss drops so the checker takes this into account.
          pickup_global_id = get_entity_skill_drop_by_entity_location(location)
          checker.add_item(pickup_global_id)
        end
        
        next if accessible_unused_boss_locations.length > 0
      end
      
      new_possible_locations = possible_locations - previous_accessible_locations.flatten
      
      new_possible_locations = filter_locations_valid_for_pickup(new_possible_locations, pickup_global_id)
      
      if new_possible_locations.empty?
        # No new locations, so select an old location.
        
        valid_previous_accessible_regions = previous_accessible_locations.map do |previous_accessible_region|
          possible_locations = previous_accessible_region.dup
          possible_locations -= @locations_randomized_to_have_useful_pickups
          
          possible_locations = filter_locations_valid_for_pickup(possible_locations, pickup_global_id)
          
          possible_locations = nil if possible_locations.empty?
          
          possible_locations
        end.compact
        
        if valid_previous_accessible_regions.empty?
          raise "Bug: Failed to find any spots to place pickup.\nSeed is #{@seed}."
        end
        
        if on_leftovers
          # Just placing a leftover progression pickup.
          # Weighted to be more likely to select locations you got access to later rather than earlier.
          
          i = 1
          weights = valid_previous_accessible_regions.map do |region|
            # Weight later accessible regions as more likely than earlier accessible regions
            weight = i
            i += 1
            weight
          end
          ps = weights.map{|w| w.to_f / weights.reduce(:+)}
          weighted_accessible_regions = valid_previous_accessible_regions.zip(ps).to_h
          previous_accessible_region = weighted_accessible_regions.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
          
          new_possible_locations = previous_accessible_region
        else
          # Placing a main route progression pickup, just not one that immediately opens up new areas.
          # Always place in the most recent accessible region.
          
          new_possible_locations = valid_previous_accessible_regions.last
        end
      else
        previous_accessible_locations << new_possible_locations
      end
      
      #p "new_possible_locations: #{new_possible_locations}"
      location = new_possible_locations.sample(random: rng)
      @locations_randomized_to_have_useful_pickups << location
      
      pickup_name = checker.defs.invert[pickup_global_id].to_s
      pickup_str = "pickup %04X (#{pickup_name})" % pickup_global_id
      location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
      area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
      if SECTOR_INDEX_TO_SECTOR_NAME[area_index]
        area_name = SECTOR_INDEX_TO_SECTOR_NAME[area_index][sector_index]
      else
        area_name = AREA_INDEX_TO_AREA_NAME[area_index]
      end
      is_enemy_str = checker.enemy_locations.include?(location) ? " (boss)" : ""
      is_event_str = checker.event_locations.include?(location) ? " (event)" : ""
      is_hidden_str = checker.hidden_locations.include?(location) ? " (hidden)" : ""
      spoiler_str = "Placing #{pickup_str} at #{location}#{is_enemy_str}#{is_event_str}#{is_hidden_str} (#{area_name})"
      spoiler_log.puts spoiler_str
      #puts spoiler_str
      
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
      
      checker.add_item(pickup_global_id)
    end
  end
  
  def place_non_progression_pickups
    remaining_locations = checker.all_locations.keys - @locations_randomized_to_have_useful_pickups
    remaining_locations.each_with_index do |location, i|
      if checker.enemy_locations.include?(location)
        # Boss
        pickup_global_id = get_unplaced_non_progression_skill()
      elsif ["dos", "por"].include?(GAME) && checker.event_locations.include?(location)
        # Event item
        pickup_global_id = get_unplaced_non_progression_item()
      elsif GAME == "ooe" && checker.event_locations.include?(location)
        # Event glyph
        pickup_global_id = get_unplaced_non_progression_skill()
      elsif GAME == "ooe"
        # Pickup
        case rng.rand
        when 0.00..0.02 # 2% chance to be money
          pickup_global_id = :money
        when 0.02..0.25 # 23% chance to be a max up
          pickup_global_id = [0x7F, 0x80, 0x81].sample(random: rng)
        when 0.25..0.50 # 25% chance to be a skill
          pickup_global_id = get_unplaced_non_progression_skill()
        when 0.50..1.00 # 50% chance to be an item
          pickup_global_id = get_unplaced_non_progression_item()
        end
      elsif GAME == "por"
        # Pickup
        case rng.rand
        when 0.00..0.02 # 2% chance to be money
          pickup_global_id = :money
        when 0.02..0.20 # 18% chance to be a max up
          pickup_global_id = [0x08, 0x09].sample(random: rng)
        when 0.20..0.45 # 25% chance to be a skill
          pickup_global_id = get_unplaced_non_progression_skill()
        when 0.45..1.00 # 55% chance to be an item
          pickup_global_id = get_unplaced_non_progression_item()
        end
      else # DoS
        # Pickup
        case rng.rand
        when 0.00..0.02 # 2% chance to be money
          pickup_global_id = :money
        when 0.02..0.15 # 13% chance to be a skill
          pickup_global_id = get_unplaced_non_progression_skill()
        when 0.15..1.00 # 85% chance to be an item
          pickup_global_id = get_unplaced_non_progression_item()
        end
      end
      
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
    end
  end
  
  def all_non_progression_pickups
    @all_non_progression_pickups ||= begin
      all_non_progression_pickups = PICKUP_GLOBAL_ID_RANGE.to_a - checker.all_progression_pickups
      
      all_non_progression_pickups -= FAKE_PICKUP_GLOBAL_IDS
      
      all_non_progression_pickups
    end
  end
  
  def filter_locations_valid_for_pickup(locations, pickup_global_id)
    locations = locations.dup
    
    if ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # If the pickup is an item instead of a skill, don't let bosses drop it.
      locations -= checker.enemy_locations
    end
    
    if GAME == "dos" && SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Don't let events give you souls in DoS.
      locations -= checker.event_locations
    end
    if GAME == "ooe" && ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Don't let events give you items in OoE.
      locations -= checker.event_locations
    end
    if GAME == "ooe" && (0x6F..0x74).include?(pickup_global_id)
      # Don't let relics be inside breakable walls in OoE.
      # This is because they need to be inside a chest, and chests can't be hidden.
      locations -= checker.hidden_locations
    end
    
    locations
  end
  
  def get_unplaced_non_progression_pickup
    pickup_global_id = @unplaced_non_progression_pickups.sample(random: rng)
    
    if pickup_global_id.nil?
      #puts "RAN OUT OF PICKUPS"
      # Ran out of unplaced pickups, so place a duplicate instead.
      @unplaced_non_progression_pickups = all_non_progression_pickups().dup
      @unplaced_non_progression_pickups -= checker.current_items
      return get_unplaced_non_progression_pickup()
    end
    
    @unplaced_non_progression_pickups.delete(pickup_global_id)
    
    return pickup_global_id
  end
  
  def get_unplaced_non_progression_item
    unplaced_non_progression_items = @unplaced_non_progression_pickups.select do |pickup_global_id|
      ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
    end
    
    item_global_id = unplaced_non_progression_items.sample(random: rng)
    
    if item_global_id.nil?
      #puts "RAN OUT OF ITEMS"
      # Ran out of unplaced items, so place a duplicate instead.
      @unplaced_non_progression_pickups += all_non_progression_pickups().select do |pickup_global_id|
        ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      end
      @unplaced_non_progression_pickups -= checker.current_items
      return get_unplaced_non_progression_item()
    end
    
    @unplaced_non_progression_pickups.delete(item_global_id)
    
    return item_global_id
  end
  
  def get_unplaced_non_progression_skill
    unplaced_non_progression_skills = @unplaced_non_progression_pickups.select do |pickup_global_id|
      SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
    end
    
    skill_global_id = unplaced_non_progression_skills.sample(random: rng)
    
    if skill_global_id.nil?
      #puts "RAN OUT OF SKILLS"
      # Ran out of unplaced skills, so place a duplicate instead.
      @unplaced_non_progression_pickups += all_non_progression_pickups().select do |pickup_global_id|
        SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
      end
      @unplaced_non_progression_pickups -= checker.current_items
      return get_unplaced_non_progression_skill()
    end
    
    @unplaced_non_progression_pickups.delete(skill_global_id)
    
    return skill_global_id
  end
  
  def change_entity_location_to_pickup_global_id(location, pickup_global_id)
    location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
    area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
    
    room = game.areas[area_index].sectors[sector_index].rooms[room_index]
    entity = room.entities[entity_index]
    
    if checker.event_locations.include?(location)
      # Event with a hardcoded item/glyph.
      change_hardcoded_event_pickup(entity, pickup_global_id)
      return
    end
    
    if entity.type == 1
      # Boss
      
      item_type, item_index = game.get_item_type_and_index_by_global_id(pickup_global_id)
      
      if !PICKUP_SUBTYPES_FOR_SKILLS.include?(item_type)
        raise "Can't make boss drop required item"
      end
      
      if GAME == "dos" && entity.room.sector_index == 9 && entity.room.room_index == 1
        # Aguni. He's not placed in the room so we hardcode him.
        enemy_dna = game.enemy_dnas[0x70]
      else
        enemy_dna = game.enemy_dnas[entity.subtype]
      end
      
      case GAME
      when "dos"
        enemy_dna["Soul"] = item_index
      when "ooe"
        enemy_dna["Glyph"] = item_index + 1
      else
        raise "Boss soul randomizer is bugged for #{LONG_GAME_NAME}."
      end
      
      enemy_dna.write_to_rom()
    elsif GAME == "dos" || GAME == "por"
      if entity.is_pickup?
        picked_up_flag = entity.var_a
      end
      
      if picked_up_flag.nil?
        picked_up_flag = @unused_picked_up_flags.pop()
        
        if picked_up_flag.nil?
          raise "No picked up flag for this item, this error shouldn't happen"
        end
      end
      
      if pickup_global_id == :money
        if entity.is_hidden_pickup? || rng.rand <= 0.80 # 80% chance to be a money bag
          if entity.is_hidden_pickup?
            entity.type = 7
          else
            entity.type = 4
          end
          entity.subtype = 1
          entity.var_a = picked_up_flag
          entity.var_b = rng.rand(4..6) # 500G, 1000G, 2000G
        else # 20% chance to be a money chest
          entity.type = 2
          entity.subtype = 1
          if GAME == "dos"
            entity.var_a = 0x10
          else
            entity.var_a = rng.rand(0x0E..0x0F)
          end
          
          # We didn't use the picked up flag, so put it back
          @unused_picked_up_flags << picked_up_flag
        end
        
        entity.write_to_rom()
        return
      end
      
      item_type, item_index = game.get_item_type_and_index_by_global_id(pickup_global_id)
      
      if PICKUP_SUBTYPES_FOR_SKILLS.include?(item_type)
        case GAME
        when "dos"
          # Soul candle
          entity.type = 2
          entity.subtype = 1
          entity.var_a = 0
          entity.var_b = item_index
          
          # We didn't use the picked up flag, so put it back
          @unused_picked_up_flags << picked_up_flag
        when "por"
          # Skill
          unless entity.is_hidden_pickup?
            entity.type = 4
          end
          entity.subtype = item_type
          entity.var_a = picked_up_flag
          entity.var_b = item_index
        end
      else
        # Item
        unless entity.is_hidden_pickup?
          entity.type = 4
        end
        entity.subtype = item_type
        entity.var_a = picked_up_flag
        entity.var_b = item_index
      end
      
      entity.write_to_rom()
    elsif GAME == "ooe"
      if entity.is_item_chest?
        picked_up_flag = entity.var_b
      elsif entity.is_pickup?
        picked_up_flag = entity.var_a
      end
      
      if picked_up_flag.nil?
        picked_up_flag = @unused_picked_up_flags.pop()
        
        if picked_up_flag.nil?
          raise "No picked up flag for this item, this error shouldn't happen"
        end
      end
      
      if entity.is_glyph? && !entity.is_hidden_pickup?
        entity.y_pos += 0x20
      end
      
      if pickup_global_id == :money
        if entity.is_hidden_pickup?
          entity.type = 7
        else
          entity.type = 4
        end
        entity.subtype = 1
        entity.var_a = picked_up_flag
        entity.var_b = rng.rand(4..6) # 500G, 1000G, 2000G
        
        entity.write_to_rom()
        return
      end
      
      if (0x6F..0x74).include?(pickup_global_id)
        # Relic. Must go in a chest, if you leave it lying on the ground it won't autoequip.
        entity.type = 2
        entity.subtype = 0x16
        entity.var_a = pickup_global_id + 1
        entity.var_b = picked_up_flag
        
        entity.write_to_rom()
        return
      end
      
      if pickup_global_id >= 0x6F
        # Item
        if entity.is_hidden_pickup?
          entity.type = 7
          entity.subtype = 0xFF
          entity.var_a = picked_up_flag
          entity.var_b = pickup_global_id + 1
        else
          case rng.rand
          when 0.00..0.70
            # 70% chance for a red chest
            entity.type = 2
            entity.subtype = 0x16
            entity.var_a = pickup_global_id + 1
            entity.var_b = picked_up_flag
          when 0.70..0.95
            # 15% chance for an item on the ground
            entity.type = 4
            entity.subtype = 0xFF
            entity.var_a = picked_up_flag
            entity.var_b = pickup_global_id + 1
          else
            # 5% chance for a hidden blue chest
            entity.type = 2
            entity.subtype = 0x17
            entity.var_a = pickup_global_id + 1
            entity.var_b = picked_up_flag
          end
        end
      else
        # Glyph
        
        if entity.is_hidden_pickup?
          entity.type = 7
          entity.subtype = 2
          entity.var_a = picked_up_flag
          entity.var_b = pickup_global_id + 1
        else
          puzzle_glyph_ids = [0x1D, 0x1F, 0x20, 0x22, 0x24, 0x26, 0x27, 0x2A, 0x2B, 0x2F, 0x30, 0x31, 0x32, 0x46, 0x4E]
          if puzzle_glyph_ids.include?(pickup_global_id)
            # We need to make the glyphs that are part of a puzzle be free glyphs with a picked up flag.
            # We can't make these be glyph statues, because glyph statues use glyph_id+2 as the flag.
            # The puzzles are hardcoded to use the original glyph from that puzzle's glyph_id+2.
            # Since we can't easily changed the puzzle's hardcoded flag, we instead need to make sure that same flag is never used by anything else, namely a glyph statue with one of those puzzle glyphs inside it.
            entity.type = 4
            entity.subtype = 2
            entity.var_a = picked_up_flag
            entity.var_b = pickup_global_id + 1
          else
            # 50% chance for a glyph statue
            entity.type = 2
            entity.subtype = 2
            entity.var_a = 0
            entity.var_b = pickup_global_id + 1
            
            # We didn't use the picked up flag, so put it back
            @unused_picked_up_flags << picked_up_flag
          end
        end
      end
      
      if entity.is_glyph? && !entity.is_hidden_pickup?
        entity.y_pos -= 0x20
      end
      
      entity.write_to_rom()
    end
  end
  
  def get_entity_skill_drop_by_entity_location(location)
    location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
    area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
    
    room = game.areas[area_index].sectors[sector_index].rooms[room_index]
    entity = room.entities[entity_index]
    
    if entity.type != 1
      raise "Not an enemy: #{location}"
    end
    
    if GAME == "dos" && entity.room.sector_index == 9 && entity.room.room_index == 1
      # Aguni. He's not placed in the room so we hardcode him.
      enemy_dna = game.enemy_dnas[0x70]
    else
      enemy_dna = game.enemy_dnas[entity.subtype]
    end
    
    case GAME
    when "dos"
      skill_local_id = enemy_dna["Soul"]
    when "ooe"
      skill_local_id = enemy_dna["Glyph"] - 1
    else
      raise "Boss soul randomizer is bugged for #{LONG_GAME_NAME}."
    end
    skill_global_id = skill_local_id + SKILL_GLOBAL_ID_RANGE.begin
    
    return skill_global_id
  end
  
  def change_hardcoded_event_pickup(event_entity, pickup_global_id)
    case GAME
    when "dos"
      dos_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    when "por"
      por_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    when "ooe"
      ooe_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    end
  end
  
  def dos_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    event_entity.room.sector.load_necessary_overlay()
    
    if event_entity.subtype == 0x65 # Mina's Talisman
      item_type, item_index = game.get_item_type_and_index_by_global_id(pickup_global_id)
      # Item given when watching the event
      game.fs.write(0x021CB9F4, [item_type].pack("C"))
      game.fs.write(0x021CB9F8, [item_index].pack("C"))
      # Item name shown in the corner of the screen
      game.fs.write(0x021CBA08, [item_type].pack("C"))
      game.fs.write(0x021CBA0C, [item_index].pack("C"))
      # Item given when skipping the event
      game.fs.write(0x021CBC14, [item_type].pack("C"))
      game.fs.write(0x021CBC18, [item_index].pack("C"))
    end
  end
  
  def por_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    event_entity.room.sector.load_necessary_overlay()
  end
  
  def ooe_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    event_entity.room.sector.load_necessary_overlay()
    
    if event_entity.subtype == 0x8A # Magnes
      # Get rid of the event, turn it into a normal free glyph
      # We can't keep the event because it automatically equips Magnes even if the glyph it gives is not Magnes.
      # Changing what it equips would just make the event not work right, so we may as well remove it.
      picked_up_flag = @unused_picked_up_flags.pop()
      if picked_up_flag.nil?
        raise "No picked up flag for this item, this error shouldn't happen"
      end
      event_entity.type = 4
      event_entity.subtype = 2
      event_entity.var_a = picked_up_flag
      event_entity.var_b = pickup_global_id + 1
      event_entity.x_pos = 0x80
      event_entity.y_pos = 0x2B0
      event_entity.write_to_rom()
    elsif event_entity.subtype == 0x69 # Dominus Hatred
      game.fs.write(0x02230A7C, [pickup_global_id+1].pack("C"))
      game.fs.write(0x022C25D8, [pickup_global_id+1].pack("C"))
    elsif event_entity.subtype == 0x6F # Dominus Anger
      game.fs.write(0x02230A84, [pickup_global_id+1].pack("C"))
      game.fs.write(0x022C25DC, [pickup_global_id+1].pack("C"))
    elsif event_entity.subtype == 0x81 # Cerberus
      # Get rid of the event, turn it into a normal free glyph
      # We can't keep the event because it has special programming to always spawn them in order even if you get to the locations out of order.
      picked_up_flag = @unused_picked_up_flags.pop()
      if picked_up_flag.nil?
        raise "No picked up flag for this item, this error shouldn't happen"
      end
      event_entity.type = 4
      event_entity.subtype = 2
      event_entity.var_a = picked_up_flag
      event_entity.var_b = pickup_global_id + 1
      event_entity.x_pos = 0x80
      event_entity.y_pos = 0x60
      event_entity.write_to_rom()
      
      other_cerberus_events = event_entity.room.entities.select{|e| e.is_special_object? && [0x82, 0x83].include?(e.subtype)}
      other_cerberus_events.each do |event|
        # Delete these others, we don't want the events.
        event.type = 0
        event.write_to_rom()
      end
    else
      glyph_id_location = case event_entity.subtype
      when 0x2F # Luminatio
        0x022C4894
      when 0x3B # Pneuma
        0x022C28E8
      when 0x44 # Lapiste
        0x022C2CB0
      when 0x54 # Vol Umbra
        0x022C2FBC
      when 0x4C # Vol Fulgur
        0x022C2490
      when 0x52 # Vol Ignis
        0x0221F1A0
      when 0x47 # Vol Grando
        0x022C230C
      when 0x40 # Cubus
        0x022C31DC
      when 0x53 # Morbus
        0x022C2354
      when 0x76 # Dominus Agony
        0x022C25BC
      else
        return
      end
      
      game.fs.write(glyph_id_location, [pickup_global_id+1].pack("C"))
    end
  end
end
