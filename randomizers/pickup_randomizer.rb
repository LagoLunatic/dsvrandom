
module PickupRandomizer
  VILLAGER_NAME_TO_EVENT_FLAG = {
    :villagerjacob => 0x2A,
    :villagerabram => 0x2D,
    :villageraeon => 0x3C,
    :villagereugen => 0x38,
    :villagermonica => 0x4F,
    :villagerlaura => 0x32,
    :villagermarcel => 0x40,
    :villagerserge => 0x47,
    :villageranna => 0x4B,
    :villagerdaniela => 0x57,
    :villageririna => 0x53,
    :villagergeorge => 0x0D,
  }
  RANDOMIZABLE_VILLAGER_NAMES = VILLAGER_NAME_TO_EVENT_FLAG.keys
  
  PORTRAIT_NAME_TO_DATA = {
    :portraitcityofhaze => {subtype: 0x1A, var_a: 1, var_b: 0x1A},
    :portraitsandygrave => {subtype: 0x1A, var_a: 3, var_b: 0},
    :portraitnationoffools => {subtype: 0x1A, var_a: 5, var_b: 0x21},
    :portraitforestofdoom => {subtype: 0x1A, var_a: 7, var_b: 0},
    :portraitdarkacademy => {subtype: 0x76, var_a: 8, var_b: 0x46},
    :portraitburntparadise => {subtype: 0x76, var_a: 6, var_b: 0x20},
    :portraitforgottencity => {subtype: 0x76, var_a: 4, var_b: 0},
    :portrait13thstreet => {subtype: 0x76, var_a: 2, var_b: 7},
    :portraitnestofevil => {subtype: 0x86, var_a: 9, var_b: 0},
  }
  PORTRAIT_NAMES = PORTRAIT_NAME_TO_DATA.keys
  AREA_INDEX_TO_PORTRAIT_NAME = PORTRAIT_NAME_TO_DATA.map do |name, data|
    [data[:var_a], name]
  end.to_h
  PORTRAIT_NAME_TO_AREA_INDEX = PORTRAIT_NAME_TO_DATA.map do |name, data|
    [name, data[:var_a]]
  end.to_h
  PORTRAIT_NAME_TO_DEFAULT_ENTITY_LOCATION = {
    :portraitcityofhaze => "00-01-00_00",
    :portraitsandygrave => "00-04-12_00",
    :portraitnationoffools => "00-06-01_00",
    :portraitforestofdoom => "00-08-01_02",
    :portraitdarkacademy => "00-0B-00_04",
    :portraitburntparadise => "00-0B-00_03",
    :portraitforgottencity => "00-0B-00_01",
    :portrait13thstreet => "00-0B-00_02",
    :portraitnestofevil => "00-00-05_00",
  }
  
  def randomize_pickups_completably(&block)
    spoiler_log.puts "Randomizing pickups:"
    
    case GAME
    when "dos"
      checker.add_item(0x43) # knife
      checker.add_item(0x91) # casual clothes
      
      checker.add_item(0x3D) # seal 1
      
      if options[:unlock_boss_doors]
        checker.add_item(0x3E) # seal 2
        checker.add_item(0x3F) # seal 3
        checker.add_item(0x40) # seal 4
        checker.add_item(0x41) # seal 5
      end
    when "por"
      checker.add_item(0x61) # starting vampire killer
      checker.add_item(0x6C) # encyclopedia
      checker.add_item(0xAA) # casual clothes
      
      checker.add_item(0x1AD) # call cube
      
      if options[:dont_randomize_change_cube]
        checker.add_item(0x1AC) # change cube
        unless room_rando? # In room rando this item is placed in the player's starting room instead.
          change_entity_location_to_pickup_global_id("00-00-01_01", 0x1AC)
        end
      else
        # If the player doesn't start with change cube, give them skill cube instead so they can still use Charlotte's spells.
        checker.add_item(0x1AE) # skill cube
        unless room_rando? # In room rando this item is placed in the player's starting room instead.
          change_entity_location_to_pickup_global_id("00-00-01_01", 0x1AE)
        end
      end
      
      # In the corridor where Behemoth chases you, change the code of the platform to not permanently disappear.
      # This is so the player can't get stuck if they miss an important item up there.
      game.fs.load_overlay(79)
      game.fs.write(0x022EC638, [0xEA000003].pack("V"))
      
      # Room in Sandy Grave that has two overlapping Charm Necklaces.
      # We don't want these to overlap as the player could easily think it's just one item and not see the one beneath it.
      # Move one a bit to the left and the other a bit to the right. Also give one a different pickup flag.
      item_a = game.areas[3].sectors[0].rooms[0x13].entities[0]
      item_b = game.areas[3].sectors[0].rooms[0x13].entities[1]
      item_a.x_pos = 0x120
      item_b.x_pos = 0x140
      pickup_flag = get_unused_pickup_flag()
      item_b.var_a = pickup_flag
      use_pickup_flag(pickup_flag)
      item_a.write_to_rom()
      item_b.write_to_rom()
    when "ooe"
      checker.add_item(0xE6) # casual clothes
      checker.add_item(0x6F) # lizard tail
      checker.add_item(0x72) # glyph union
      
      checker.add_item(0x1E) # torpor. the player will get enough of these as it is
      
      # Give the player the glyph sleeve in Ecclesia like in hard mode.
      # To do this just get rid of the entity hider that hides it on normal mode.
      entity_hider = game.areas[2].sectors[0].rooms[4].entities[6]
      entity_hider.type = 0
      entity_hider.write_to_rom()
      # But we also need to give the chest a unique flag, because it shares the flag with the one from Minera in normal mode.
      sleeve_chest = game.areas[2].sectors[0].rooms[4].entities[7]
      pickup_flag = get_unused_pickup_flag()
      sleeve_chest.var_b = pickup_flag
      use_pickup_flag(pickup_flag)
      sleeve_chest.write_to_rom()
      # We also make sure the chest in Minera appears even on hard mode.
      entity_hider = game.areas[8].sectors[2].rooms[7].entities[1]
      entity_hider.type = 0
      entity_hider.write_to_rom()
      checker.add_item(0x73) # glyph sleeve
      
      # Room in the Final Approach that has two overlapping chests both containing diamonds.
      # We don't want these to overlap as the player could easily think it's just one item and not see the one beneath it.
      # Move one a bit to the left and the other a bit to the right. Also give one a different pickup flag.
      chest_a = game.areas[0].sectors[0xA].rooms[0xB].entities[1]
      chest_b = game.areas[0].sectors[0xA].rooms[0xB].entities[2]
      chest_a.x_pos = 0xE0
      chest_b.x_pos = 0x130
      pickup_flag = get_unused_pickup_flag()
      chest_b.var_b = pickup_flag
      use_pickup_flag(pickup_flag)
      chest_a.write_to_rom()
      chest_b.write_to_rom()
    end
    
    total_progression_pickups = checker.all_progression_pickups.length
    place_progression_pickups() do |progression_pickups_placed|
      percent_done = progression_pickups_placed.to_f / total_progression_pickups
      yield percent_done
    end
    
    if !checker.game_beatable?
      #if options[:randomize_rooms_map_friendly]
      #  # When debugging logic errors in map rando, output a list of what room strings were accessible at the end.
      #  File.open("./logs/accessed rooms debug #{GAME} #{seed}.txt", "w") do |f|
      #    for room_str in @rooms_by_progression_order_accessed
      #      f.puts(room_str)
      #    end
      #  end
      #  
      #  # And also output an image of the map with accessible rooms highlighted in red.
      #  unique_rooms_accessed = @rooms_by_progression_order_accessed.flatten.uniq
      #  game.areas.each_index do |area_index|
      #    map = game.get_map(area_index, 0)
      #    for tile in map.tiles
      #      if tile.sector_index.nil? || tile.room_index.nil?
      #        next
      #      end
      #      room_str_for_tile = "%02X-%02X-%02X" % [area_index, tile.sector_index, tile.room_index]
      #      if unique_rooms_accessed.include?(room_str_for_tile)
      #        tile.is_save = true
      #        tile.is_warp = false
      #        tile.is_entrance = false
      #      else
      #        tile.is_save = false
      #        tile.is_warp = false
      #        tile.is_entrance = false
      #      end
      #    end
      #    hardcoded_transition_rooms = (GAME == "dos" ? @transition_rooms : [])
      #    filename = "./logs/map debug #{GAME} area %02X #{seed}.png" % area_index
      #    renderer.render_map(map, scale=3, hardcoded_transition_rooms=hardcoded_transition_rooms).save(filename)
      #  end
      #end
      
      item_names = checker.current_items.map do |global_id|
        if global_id.is_a?(Symbol)
          global_id
        else
          checker.defs.invert[global_id]
        end
      end.compact
      raise "Bug: Game is not beatable on this seed!\nThis error shouldn't happen.\nSeed: #{@seed}\n\nItems:\n#{item_names.join(", ")}"
    end
    
    if GAME == "por" && options[:randomize_portraits]
      # Remove the extra portraits at the end of 13th Street, Forgotten City, Burnt Paradise, and Dark Academy.
      # (The one return portrait back to where you entered this portrait from is not removed, and is updated elsewhere in the code.)
      [
        "02-02-16_01",
        "02-02-16_03",
        "02-02-16_04",
        "04-01-07_02",
        "04-01-07_03",
        "04-01-07_04",
        "06-00-06_01",
        "06-00-06_02",
        "06-00-06_04",
        "08-00-08_01",
        "08-00-08_02",
        "08-00-08_03",
      ].each do |entity_str|
        portrait = game.entity_by_str(entity_str)
        portrait.type = 0
        portrait.write_to_rom()
      end
    end
  end
  
  def place_progression_pickups(&block)
    previous_accessible_locations = []
    @locations_randomized_to_have_useful_pickups = []
    @rooms_that_already_have_an_event = []
    progression_pickups_placed = 0
    total_progression_pickups = checker.all_progression_pickups.length
    on_leftovers = false
    @rooms_by_progression_order_accessed = []
    
    if GAME == "ooe" && options[:randomize_world_map_exits]
      initialize_world_map_exit_randomization_variables()
    end
    
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_special_object? && (0x5F..0x88).include?(entity.subtype)
          room_str = "%02X-%02X-%02X" % [room.area_index, room.sector_index, room.room_index]
          @rooms_that_already_have_an_event << room_str
          break
        end
      end
    end
    
    if GAME == "por" && options[:randomize_starting_room] && options[:randomize_portraits]
      starting_portrait_name = AREA_INDEX_TO_PORTRAIT_NAME[@starting_room.area_index]
      if starting_portrait_name
        # The starting room randomizer started the player in a portrait.
        # This is problematic because the portrait randomizer will traditionally never place a portrait back to Dracula's castle, making it inaccessible.
        # So we need to place the starting portrait at a random location in Dracula's Castle and register it with the logic.
        
        # First pick a random valid location.
        possible_portrait_locations = checker.all_locations.keys
        possible_portrait_locations = filter_locations_valid_for_pickup(possible_portrait_locations, starting_portrait_name)
        unused_room_strs = @unused_rooms.map{|room| room.room_str}
        possible_portrait_locations.reject! do |location|
          room_str = location[0,8]
          unused_room_strs.include?(room_str)
        end
        possible_portrait_locations.select! do |location|
          area_index = location[0,2].to_i(16)
          area_index == 0
        end
        starting_portrait_location_in_castle = possible_portrait_locations.sample(random: rng)
        
        # Then place the portrait.
        change_entity_location_to_pickup_global_id(starting_portrait_location_in_castle, starting_portrait_name)
        @locations_randomized_to_have_useful_pickups << starting_portrait_location_in_castle
      end
    end
    
    verbose = false
    
    # First place progression pickups needed to beat the game.
    spoiler_log.puts "Placing main route progression pickups:"
    on_first_item = true
    while true
      case GAME
      when "por"
        if !checker.current_items.include?(0x1B2) && checker.wind_accessible? && checker.vincent_accessible?
          checker.add_item(0x1B2) # give lizard tail if the player has reached wind
        end
      end
      
      
      if room_rando?
        possible_locations, accessible_doors = checker.get_accessible_locations_and_doors()
        
        accessible_rooms = accessible_doors.map{|door_str| door_str[0,8]}
        @rooms_by_progression_order_accessed << accessible_rooms
      else
        possible_locations = checker.get_accessible_locations()
      end
      possible_locations -= @locations_randomized_to_have_useful_pickups
      puts "Total possible locations: #{possible_locations.size}" if verbose
      
      
      pickups_by_locations = checker.pickups_by_current_num_locations_they_access()
      if starting_portrait_name
        # Don't place the starting portrait anywhere, it's already in Dracula's Castle.
        pickups_by_locations.delete(starting_portrait_name)
      end
      if GAME == "por" && options[:randomize_portraits] && (!room_rando? || !options[:rebalance_enemies_in_room_rando])
        # If portraits are randomized but we can't rebalance enemies, try to avoid placing late game portraits in the early game.
        if progression_pickups_placed < 5
          pickups_by_locations_filtered = pickups_by_locations.reject do |pickup, usefulness|
            [:portraitdarkacademy, :portraitburntparadise, :portraitforgottencity, :portrait13thstreet].include?(pickup)
          end
          if pickups_by_locations_filtered.any?
            pickups_by_locations = pickups_by_locations_filtered
          end
        end
      end
      pickups_by_usefulness = pickups_by_locations.select{|pickup, num_locations| num_locations > 0}
      currently_useless_pickups = pickups_by_locations.select{|pickup, num_locations| num_locations == 0}
      puts "Num useless pickups: #{currently_useless_pickups.size}" if verbose
      placing_currently_useless_pickup = false
      if pickups_by_usefulness.any?
        max_usefulness = pickups_by_usefulness.values.max
        
        weights = pickups_by_usefulness.map do |pickup, usefulness|
          # Weight less useful pickups as being more likely to be chosen.
          weight = max_usefulness - usefulness + 1
          weight = Math.sqrt(weight)
          if checker.preferences[pickup]
            weight *= checker.preferences[pickup]
          end
          weight
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
        # So just place a random pickup for now.
        
        valid_pickups = pickups_by_locations.keys
        
        if GAME == "ooe" && options[:randomize_villagers]
          valid_villagers = valid_pickups & RANDOMIZABLE_VILLAGER_NAMES
          if checker.albus_fight_accessible?
            if valid_villagers.any?
              # Once Albus is accessible, prioritize placing villagers over other pickups.
              valid_pickups = valid_villagers
            end
          else
            # Don't start placing villagers until Albus is accessible.
            valid_pickups -= RANDOMIZABLE_VILLAGER_NAMES
          end
          
          if valid_pickups.empty?
            # But if the only things left to place are villagers, we have no choice but to place them before Albus is accessible.
            valid_pickups = pickups_by_locations.keys
          end
        elsif GAME == "dos" && room_rando? && accessible_rooms.include?("00-06-00")
          # Player has access to the Subterranean Hell room with the huge spikes.
          # To get through this room you need either rahab and bone ark or rahab, puppet master, and skeleton ape.
          # The logic can have trouble placing the items necessary to get through this room, since skeleton ape and bone ark are useless everywhere else, and rahab is only useful in a handful of rooms - so if the player doesn't have access to any places that make rahab useful by itself, the randomizer might just try to place every other item, filling up all available item locations, and never place rahab.
          # So we add a special case here to 100% guaranteed place rahab (assuming the player has access to under 15 item locations). From there the randomizer can figure out that it should place bone ark or puppet master and skeleton ape.
          if valid_pickups.include?(0x145) && possible_locations.length < 15
            valid_pickups = [0x145] # Rahab
          end
        end
        
        pickup_global_id = valid_pickups.sample(random: rng)
        
        placing_currently_useless_pickup = true
        puts "Placing currently useless pickup." if verbose
      else
        # All progression pickups placed.
        break
      end
      
      pickup_name = checker.defs.invert[pickup_global_id].to_s
      puts "Trying to place #{pickup_name}" if verbose
      
      
      
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
      
      if !options[:randomize_villagers] && GAME == "ooe"
        # If randomize villagers option is off, don't allow putting random things in these locations.
        accessible_unused_villager_locations = possible_locations & checker.villager_locations
        accessible_unused_villager_locations.each do |location|
          possible_locations.delete(location)
          @locations_randomized_to_have_useful_pickups << location
          
          # Also, give the player this villager so the checker takes this into account.
          villager_name = get_villager_name_by_entity_location(location)
          checker.add_item(villager_name)
        end
        
        next if accessible_unused_villager_locations.length > 0
      end
      
      if !options[:randomize_portraits] && GAME == "por"
        # If randomize portraits option is off, don't allow putting random things in these locations.
        accessible_unused_portrait_locations = possible_locations & checker.portrait_locations
        accessible_unused_portrait_locations -= @portrait_locations_to_remove # Don't count removed portraits in short mode as portrait locations.
        accessible_unused_portrait_locations.each do |location|
          possible_locations.delete(location)
          @locations_randomized_to_have_useful_pickups << location
          
          # Also, give the player this portrait so the checker takes this into account.
          portrait_name = get_portrait_name_by_entity_location(location)
          checker.add_item(portrait_name)
        end
        
        next if accessible_unused_portrait_locations.length > 0
      end
      
      
      
      if GAME == "ooe" && options[:randomize_world_map_exits]
        # Randomize world map exits.
        randomized_any = randomize_accessible_world_map_exits(accessible_doors)
        
        if randomized_any
          # Redo this progression placement loop with the world map entrances now set.
          next
        end
      end
      
      
      
      new_possible_locations = possible_locations - previous_accessible_locations.flatten
      
      filtered_new_possible_locations = filter_locations_valid_for_pickup(new_possible_locations, pickup_global_id)
      puts "Filtered new possible locations: #{filtered_new_possible_locations.size}" if verbose
      puts "  " + filtered_new_possible_locations.join(", ") if verbose
      
      valid_previous_accessible_regions = previous_accessible_locations.map do |previous_accessible_region|
        possible_locations = previous_accessible_region.dup
        possible_locations -= @locations_randomized_to_have_useful_pickups
        
        possible_locations = filter_locations_valid_for_pickup(possible_locations, pickup_global_id)
        
        possible_locations = nil if possible_locations.empty?
        
        possible_locations
      end.compact
      
      possible_locations_to_choose_from = filtered_new_possible_locations.dup
      
      if placing_currently_useless_pickup
        # Place items that don't immediately open up new areas anywhere in the game, with no weighting towards later areas.
        
        valid_accessible_locations = previous_accessible_locations.map do |previous_accessible_region|
          possible_locations = previous_accessible_region.dup
          possible_locations -= @locations_randomized_to_have_useful_pickups
          
          possible_locations = filter_locations_valid_for_pickup(possible_locations, pickup_global_id)
          
          possible_locations = nil if possible_locations.empty?
          
          possible_locations
        end.compact.flatten
        
        valid_accessible_locations += filtered_new_possible_locations
        
        possible_locations_to_choose_from = valid_accessible_locations
      elsif filtered_new_possible_locations.empty? && valid_previous_accessible_regions.any?
        # No new locations, so select an old location.
        
        if on_leftovers
          # Just placing a leftover progression pickup.
          # Weighted to be more likely to select locations you got access to later rather than earlier.
          
          i = 1
          weights = valid_previous_accessible_regions.map do |region|
            # Weight later accessible regions as more likely than earlier accessible regions (exponential)
            weight = i**2
            i += 1
            weight
          end
          ps = weights.map{|w| w.to_f / weights.reduce(:+)}
          weighted_accessible_regions = valid_previous_accessible_regions.zip(ps).to_h
          previous_accessible_region = weighted_accessible_regions.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
          
          possible_locations_to_choose_from = previous_accessible_region
        else
          # Placing a main route progression pickup, just not one that immediately opens up new areas.
          # Always place in the most recent accessible region.
          
          possible_locations_to_choose_from = valid_previous_accessible_regions.last
          puts "No new locations, using previous accessible location, total available: #{valid_previous_accessible_regions.last.size}" if verbose
        end
      elsif filtered_new_possible_locations.empty? && valid_previous_accessible_regions.empty?
        # No new locations, but there's no old locations either.
        if on_first_item
          # If we're placing the very first item yet there's no accessible spots, then the room/map randomizer must have resulted in a bad start.
          # So we place the first progression item in the starting room.
          entity = @starting_room.add_new_entity()
          
          entity.x_pos = @starting_x_pos
          entity.y_pos = @starting_y_pos
          
          @coll = RoomCollision.new(@starting_room, game.fs)
          floor_y = coll.get_floor_y(entity, allow_jumpthrough: true)
          entity.y_pos = floor_y - 0x18
          
          location = "#{@starting_room.room_str}_%02X" % (@starting_room.entities.length-1)
          possible_locations_to_choose_from = [location]
        else
          possible_locations_to_choose_from = []
        end
      elsif filtered_new_possible_locations.size <= 5 && valid_previous_accessible_regions.last && valid_previous_accessible_regions.last.size >= 15
        # There aren't many new locations unlocked by the last item we placed.
        # But there are a lot of other locations unlocked by the one we placed before that.
        # So we give it a chance to put it in one of those last spots, instead of the new spots.
        # The chance is proportional to how few new locations there are. 1 = 70%, 2 = 60%, 3 = 50%, 4 = 40%, 5 = 30%.
        chance = 0.30 + (5-filtered_new_possible_locations.size)*10
        if rng.rand() <= chance
          possible_locations_to_choose_from = valid_previous_accessible_regions.last
          puts "Not many new locations, using previous accessible location, total available: #{valid_previous_accessible_regions.last.size}" if verbose
        end
      end
      
      previous_accessible_locations << new_possible_locations
      
      if possible_locations_to_choose_from.empty?
        item_names = checker.current_items.map do |global_id|
          checker.defs.invert[global_id]
        end.compact
        raise "Bug: Failed to find any spots to place pickup.\nSeed: #{@seed}\n\nItems:\n#{item_names.join(", ")}"
      end
      
      #puts "Possible locations: #{possible_locations_to_choose_from.join(", ")}" if verbose
      
      location = possible_locations_to_choose_from.sample(random: rng)
      @locations_randomized_to_have_useful_pickups << location
      if room_rando?
        checker.set_current_location_by_entity(location)
      end
      
      if RANDOMIZABLE_VILLAGER_NAMES.include?(pickup_global_id)
        # Villager
        pickup_str = "villager #{pickup_global_id}"
      elsif PORTRAIT_NAMES.include?(pickup_global_id)
        # Portrait
        pickup_str = "portrait #{pickup_global_id.to_s[8..-1]}" # Add a space between portrait and the area name
      else
        pickup_name = checker.defs.invert[pickup_global_id].to_s
        pickup_str = "pickup %04X (#{pickup_name})" % pickup_global_id
      end
      location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
      area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
      if SECTOR_INDEX_TO_SECTOR_NAME[area_index]
        area_name = SECTOR_INDEX_TO_SECTOR_NAME[area_index][sector_index]
      else
        area_name = AREA_INDEX_TO_AREA_NAME[area_index]
      end
      is_enemy_str = checker.enemy_locations.include?(location) ? " (boss)" : ""
      is_event_str = checker.event_locations.include?(location) ? " (event)" : ""
      is_easter_egg_str = checker.easter_egg_locations.include?(location) ? " (easter egg)" : ""
      is_hidden_str = checker.hidden_locations.include?(location) ? " (hidden)" : ""
      is_mirror_str = checker.mirror_locations.include?(location) ? " (mirror)" : ""
      spoiler_str = "  Placing #{pickup_str} at #{location}#{is_enemy_str}#{is_event_str}#{is_easter_egg_str}#{is_hidden_str}#{is_mirror_str} (#{area_name})"
      spoiler_log.puts spoiler_str
      puts spoiler_str if verbose
      
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
      
      checker.add_item(pickup_global_id)
      
      on_first_item = false
      
      if room_rando? && GAME == "ooe"
        if accessible_doors.include?("01-01-00_000") && !checker.current_items.include?(:villagernikolai)
          checker.add_item(:villagernikolai)
        end
        if accessible_doors.include?("11-00-08_000") && !checker.current_items.include?(:villagergeorge)
          checker.add_item(:villagergeorge)
        end
      end
      
      progression_pickups_placed += 1
      yield(progression_pickups_placed)
    end
    
    if room_rando? && false
      File.open("accessible_doors.txt", "w") do |f|
        accessible_doors.each do |accessible_door|
          f.puts accessible_door
        end
      end
    end
    
    if GAME == "ooe" && options[:randomize_world_map_exits]
      assert_all_world_map_entrances_and_exits_used()
    end
    
    spoiler_log.puts "All progression pickups placed successfully."
  end
  
  def place_non_progression_pickups
    remaining_locations = checker.get_accessible_locations() - @locations_randomized_to_have_useful_pickups
    remaining_locations.shuffle!(random: rng)
    
    # In room rando, some items may be unreachable.
    # We don't want the player to see these items in a different subroom and think the randomizer is bugged, so we delete them.
    inaccessible_remaining_locations = checker.all_locations.keys - @locations_randomized_to_have_useful_pickups - remaining_locations
    remove_inaccessible_items(inaccessible_remaining_locations)
    
    if GAME == "ooe"
      # Do event glyphs first. This is so they don't reuse a glyph already used by a glyph statue.
      # If the player got the one from the glyph statue first then the one in the event/puzzle wouldn't appear, breaking the event/puzzle.
      ooe_event_glyph_locations = remaining_locations.select{|location| checker.event_locations.include?(location)}
      ooe_event_glyph_locations.each do |location|
        pickup_global_id = get_unplaced_non_progression_skill()
        change_entity_location_to_pickup_global_id(location, pickup_global_id)
      end
      remaining_locations -= ooe_event_glyph_locations
    end
    
    chaos_ring_placed = false
    remaining_locations.each_with_index do |location, i|
      if checker.enemy_locations.include?(location)
        # Boss
        pickup_global_id = get_unplaced_non_progression_skill()
      elsif ["dos", "por"].include?(GAME) && (checker.event_locations.include?(location) || checker.easter_egg_locations.include?(location))
        # Event item
        pickup_global_id = get_unplaced_non_progression_item()
      elsif GAME == "ooe" && location == "08-02-06_01"
        # Tin man's strength ring blue chest. Can't be a glyph.
        pickup_global_id = get_unplaced_non_progression_item_that_can_be_an_arm_shifted_immediate()
      elsif GAME == "dos" && checker.mirror_locations.include?(location)
        # Soul candles shouldn't be placed in mirrors, as they will appear even outside the mirror.
        pickup_global_id = get_unplaced_non_progression_item()
      elsif GAME == "dos" && !chaos_ring_placed
        pickup_global_id = 0xCD
        chaos_ring_placed = true
      elsif GAME == "por" && !chaos_ring_placed
        pickup_global_id = 0x12C
        chaos_ring_placed = true
      else
        # Pickup
        
        # Select the type of pickup weighed by difficulty options.
        weights = {
          money: @difficulty_settings[:money_placement_weight],
          item: @difficulty_settings[:item_placement_weight],
        }
        if GAME == "por" || GAME == "ooe"
          weights[:max_up] = @difficulty_settings[:max_up_placement_weight]
        end
        case GAME
        when "dos"
          weights[:skill] = @difficulty_settings[:soul_candle_placement_weight]
        when "por"
          weights[:skill] = @difficulty_settings[:por_skill_placement_weight]
        when "ooe"
          weights[:skill] = @difficulty_settings[:glyph_placement_weight]
        end
        
        weighted_pickup_types = {}
        weights_sum = weights.values.reduce(:+)
        weights.each do |type, weight|
          weighted_pickup_types[type] = weight.to_f / weights_sum
        end
        
        random_pickup_type = weighted_pickup_types.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
        
        case random_pickup_type
        when :money
          pickup_global_id = :money
        when :max_up
          pickup_global_id = @max_up_items.sample(random: rng)
        when :skill
          pickup_global_id = get_unplaced_non_progression_skill()
        when :item
          if checker.hidden_locations.include?(location)
            # Don't let relics be inside breakable walls in OoE.
            # This is because they need to be inside a chest, and chests can't be hidden.
            pickup_global_id = get_unplaced_non_progression_item_except_ooe_relics()
          else
            pickup_global_id = get_unplaced_non_progression_item()
          end
        end
      end
      
      @used_non_progression_pickups << pickup_global_id
      
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
    end
  end
  
  def initialize_all_non_progression_pickups
    if !@all_non_progression_pickups.nil?
      raise "all_non_progression_pickups was initialized too early."
    end
    
    @all_non_progression_pickups = begin
      all_non_progression_pickups = PICKUP_GLOBAL_ID_RANGE.to_a - checker.all_progression_pickups
      
      all_non_progression_pickups -= NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
      
      all_non_progression_pickups -= @max_up_items
      
      if room_rando? || (GAME == "por" && options[:randomize_portraits])
        all_non_progression_pickups -= [MAGICAL_TICKET_GLOBAL_ID]
      end
      
      all_non_progression_pickups
    end
  end
  
  def filter_locations_valid_for_pickup(locations, pickup_global_id)
    locations = locations.dup
    
    if ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # If the pickup is an item instead of a skill, don't let bosses drop it.
      locations -= checker.enemy_locations
    end
    
    # Don't let progression items be in certain problematic locations. (This function is only called for progression items.)
    locations -= checker.no_progression_locations
    
    if GAME == "dos" && SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Don't let events give you souls in DoS.
      locations -= checker.event_locations
      locations -= checker.easter_egg_locations
      
      # Don't let soul candles be inside mirrors. They don't get hidden, and are accessible without Paranoia.
      locations -= checker.mirror_locations
      
      # Don't let soul candles be inside specific locations that can be broken without reaching them.
      locations -= checker.no_soul_locations
    end
    if GAME == "dos" && (0x3D..0x41).include?(pickup_global_id)
      # Magic seals can't be given by easter egg locations.
      locations -= checker.easter_egg_locations
    end
    if GAME == "ooe" && ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Don't let events give you items in OoE.
      locations -= checker.event_locations
    end
    if GAME == "ooe" && !ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Glyphs/villagers can't be in the special blue chest spawned by the searchlights when you kill a Tin Man.
      locations -= ["08-02-06_01"]
    end
    if GAME == "ooe" && (!pickup_global_id.is_a?(Integer) || !game.fs.check_integer_can_be_an_arm_shifted_immediate?(pickup_global_id))
      # The pickup ID is a hardcoded arm shifted immediate for the special blue chest spawned by the searchlights when you kill a Tin Man.
      locations -= ["08-02-06_01"]
    end
    if GAME == "ooe" && (0x6F..0x74).include?(pickup_global_id)
      # Don't let relics be inside breakable walls in OoE.
      # This is because they need to be inside a chest, and chests can't be hidden.
      locations -= checker.hidden_locations
    end
    if RANDOMIZABLE_VILLAGER_NAMES.include?(pickup_global_id)
      # Villagers can't be hidden, an event glyph, or a boss drop.
      locations -= checker.hidden_locations
      locations -= checker.event_locations
      locations -= checker.enemy_locations
      
      # Locations too close to the top of the room shouldn't be villagers, as the Torpor glyph would spawn above the screen and not be absorbable.
      locations_too_high_to_be_a_villager = ["00-05-07_01", "00-05-07_02", "00-05-08_02", "00-05-08_03", "00-05-0C_01", "00-06-09_00", "0D-00-04_00", "0D-00-0C_00"]
      locations -= locations_too_high_to_be_a_villager
      
      # Two villagers shouldn't be placed in the same room, or their events will conflict and not work correctly.
      locations.select! do |location|
        room_str = location[0,8]
        !@rooms_that_already_have_an_event.include?(room_str)
      end
    end
    if PORTRAIT_NAMES.include?(pickup_global_id)
      bad_portrait_locations = [
        "05-02-0C_01", # Legion's room. If a portrait gets placed here the player won't be able to activate Legion because using a portrait doesn't set the pickup flag Legion checks.
        
        "05-01-13_00", # This location overlaps a ring of flaming skulls that would damage the player on return.
        "06-01-0D_02", # This location overlaps a ring of flaming skulls that would damage the player on return.
      ]
      
      locations.select! do |location|
        !bad_portrait_locations.include?(location)
      end
    end
    if GAME == "ooe" && SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
      # Don't put progression glyph in certain locations where the player could easily get them early.
      locations -= checker.no_glyph_locations
    end
    
    locations
  end
  
  def get_unplaced_non_progression_pickup(valid_ids: PICKUP_GLOBAL_ID_RANGE.to_a)
    valid_possible_items = @unplaced_non_progression_pickups.select do |pickup_global_id|
      valid_ids.include?(pickup_global_id)
    end
    
    pickup_global_id = valid_possible_items.sample(random: rng)
    
    if pickup_global_id.nil?
      # Ran out of unplaced pickups, so place a duplicate instead.
      @unplaced_non_progression_pickups += all_non_progression_pickups().select do |pickup_global_id|
        valid_ids.include?(pickup_global_id)
      end
      @unplaced_non_progression_pickups -= checker.current_items
      
      # If a glyph has already been placed as an event glyph, do not place it again somewhere.
      # If the player gets one from a glyph statue first, then the one in the event/puzzle won't appear.
      @unplaced_non_progression_pickups -= @glyphs_placed_as_event_glyphs
      
      return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
    end
    
    @unplaced_non_progression_pickups.delete(pickup_global_id)
    @used_non_progression_pickups << pickup_global_id
    
    return pickup_global_id
  end
  
  def get_unplaced_non_progression_item
    return get_unplaced_non_progression_pickup(valid_ids: ITEM_GLOBAL_ID_RANGE.to_a)
  end
  
  def get_unplaced_non_progression_item_that_can_be_an_arm_shifted_immediate
    valid_ids = ITEM_GLOBAL_ID_RANGE.to_a
    valid_ids.select!{|item_id| game.fs.check_integer_can_be_an_arm_shifted_immediate?(item_id+1)}
    return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
  end
  
  def get_unplaced_non_progression_skill
    return get_unplaced_non_progression_pickup(valid_ids: SKILL_GLOBAL_ID_RANGE.to_a)
  end
  
  def get_unplaced_non_progression_item_except_ooe_relics
    valid_ids = ITEM_GLOBAL_ID_RANGE.to_a
    if GAME == "ooe"
      valid_ids -= (0x6F..0x74).to_a
    end
    return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
  end
  
  def get_unplaced_non_progression_projectile_glyph
    projectile_glyph_ids = (0x16..0x18).to_a + (0x1C..0x32).to_a + (0x34..0x36).to_a
    return get_unplaced_non_progression_pickup(valid_ids: projectile_glyph_ids)
  end
  
  def get_unplaced_non_progression_pickup_for_enemy_drop
    valid_ids = PICKUP_GLOBAL_ID_RANGE.to_a - ITEMS_WITH_OP_HARDCODED_EFFECT
    return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
  end
  
  def get_unplaced_non_progression_item_for_enemy_drop
    valid_ids = ITEM_GLOBAL_ID_RANGE.to_a - ITEMS_WITH_OP_HARDCODED_EFFECT
    return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
  end
  
  def get_unplaced_non_progression_item_except_ooe_relics_for_enemy_drop
    valid_ids = ITEM_GLOBAL_ID_RANGE.to_a - ITEMS_WITH_OP_HARDCODED_EFFECT
    if GAME == "ooe"
      valid_ids -= (0x6F..0x74).to_a
    end
    return get_unplaced_non_progression_pickup(valid_ids: valid_ids)
  end
  
  def get_entity_by_location_str(location)
    location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
    area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
    
    room = game.areas[area_index].sectors[sector_index].rooms[room_index]
    entity = room.entities[entity_index]
    
    return entity
  end
  
  def change_entity_location_to_pickup_global_id(location, pickup_global_id)
    entity = get_entity_by_location_str(location)
    
    if checker.event_locations.include?(location) || checker.easter_egg_locations.include?(location)
      # Event with a hardcoded item/glyph.
      change_hardcoded_event_pickup(entity, pickup_global_id)
      return
    end
    
    if GAME == "ooe" && location == "08-02-06_01" # Strength Ring blue chest spawned by the searchlights after you kill the Tin Man
      if entity.var_a != 2
        raise "Searchlights are not of type 2 (Tin Man spawn)"
      end
      
      game.fs.replace_arm_shifted_immediate_integer(0x022A194C, pickup_global_id+1)
    elsif RANDOMIZABLE_VILLAGER_NAMES.include?(pickup_global_id)
      # Villager
      
      if GAME != "ooe"
        raise "Tried to place villager in #{GAME}"
      end
      
      room_str = location[0,8]
      @rooms_that_already_have_an_event << room_str
      
      entity.type = 2
      entity.subtype = 0x89
      entity.var_a = VILLAGER_NAME_TO_EVENT_FLAG[pickup_global_id]
      entity.var_b = 0
      
      entity.write_to_rom()
      
      if pickup_global_id == :villageranna
        # Anna must have Tom in her room, or her event will crash the game.
        room = entity.room
        cat = Entity.new(room, room.fs)
        
        cat.x_pos = entity.x_pos
        cat.y_pos = entity.y_pos
        cat.type = 2
        cat.subtype = 0x3F
        cat.var_a = 3
        cat.var_b = 1
        
        room.entities << cat
        room.write_entities_to_rom()
        
        # Remove the Tom in Anna's original room since he's not needed there.
        original_cat = game.areas[7].sectors[0].rooms[6].entities[2]
        original_cat.type = 0
        original_cat.write_to_rom()
      end
    elsif PORTRAIT_NAMES.include?(pickup_global_id)
      # Portrait
      
      if GAME != "por"
        raise "Tried to place portrait in #{GAME}"
      end
      
      portrait_data = PORTRAIT_NAME_TO_DATA[pickup_global_id]
      entity.type = 2
      entity.subtype = portrait_data[:subtype]
      entity.var_a = portrait_data[:var_a]
      entity.var_b = portrait_data[:var_b]
      
      # Move the portrait to a short distance above the closest floor so it looks good and is enterable.
      coll = RoomCollision.new(entity.room, game.fs)
      floor_y = coll.get_floor_y(entity, allow_jumpthrough: true)
      entity_original_y_pos = entity.y_pos
      entity.y_pos = floor_y - 0x50 # Portraits should float 5 tiles off the ground.
      
      entity.write_to_rom()
      
      
      curr_area_index = entity.room.area_index
      curr_sector_index = entity.room.sector_index
      curr_room_index = entity.room.room_index
      
      # Find the return portrait.
      dest_area_index = entity.var_a
      dest_sector_index = (entity.var_b & 0x3C0) >> 6
      dest_room_index = entity.var_b & 0x3F
      dest_room = game.areas[dest_area_index].sectors[dest_sector_index].rooms[dest_room_index]
      dest_portrait = dest_room.entities.find{|entity| entity.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(entity.subtype)}
      return_portraits = [dest_portrait]
      
      # Update the list of x/y positions the player returns at in the por_distinct_return_portrait_positions patch.
      return_x = entity.x_pos
      return_y = floor_y
      game.fs.write(0x02309010+dest_area_index*4, [return_x, return_y].pack("vv"))
      
      # If there's a small breakable wall containing this portrait we remove it.
      # Not only does the breakable wall not hide the portrait, but when the player returns they would be put out of bounds by it.
      breakable_wall_x_range = (entity.x_pos-8..entity.x_pos+8)
      breakable_wall_y_range = (entity_original_y_pos-8..entity_original_y_pos+8)
      breakable_wall_entity = entity.room.entities.find do |e|
        e.is_special_object? && e.subtype == 0x3B && breakable_wall_x_range.include?(e.x_pos) && breakable_wall_y_range.include?(e.y_pos)
      end
      if breakable_wall_entity
        breakable_wall_entity.type = 0
        breakable_wall_entity.write_to_rom()
      end
      
      # Also update the bonus return portrait at the end of some areas.
      case dest_area_index
      when 2 # 13th Street
        return_portraits << game.entity_by_str("02-02-16_02")
      when 4 # Forgotten City
        return_portraits << game.entity_by_str("04-01-07_01")
      when 6 # Burnt Paradise
        return_portraits << game.entity_by_str("06-00-06_03")
      when 8 # Dark Academy
        return_portraits << game.entity_by_str("08-00-08_04")
      end
      
      return_portraits.each do |return_portrait|
        return_portrait.var_a = curr_area_index
        return_portrait.var_b = ((curr_sector_index & 0xF) << 6) | (curr_room_index & 0x3F)
        return_portrait.subtype = case curr_area_index
        when 1, 3, 5, 7 # City of Haze, Sandy Grave, Nation of Fools, or Forest of Doom.
          0x1A
        when 2, 4, 6, 8 # 13th Street, Forgotten City, Burnt Paradise, or Dark Academy.
          0x76
        when 0, 9 # Dracula's Castle or Nest of Evil.
          if [2, 4, 6, 8].include?(dest_area_index)
            # Use the alt portrait frame when returning to Dracula's Castle from 13th Street, Forgotten City, Burnt Paradise, or Dark Academy.
            0x87
          else
            0x86
          end
        else
          puts "Unknown area to portrait into: %02X" % curr_area_index
        end
        
        # Set highest bit of var B to indicate that this is a return portrait to the por_distinct_return_portrait_positions patch.
        return_portrait.var_b = 0x8000 | return_portrait.var_b
        
        return_portrait.write_to_rom()
        
        if room_rando?
          # Tell the room rando logic about this return portrait.
          checker.add_return_portrait(return_portrait.room.room_str, location)
        end
      end
      
      
      if dest_area_index == 7 # Forest of Doom
        # Remove the event from the original Forest of Doom portrait room since the portrait is no longer there.
        forest_event = game.entity_by_str("00-08-01_03")
        forest_event.type = 0
        forest_event.write_to_rom()
      end
    elsif entity.type == 1
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
        enemy_dna["Glyph"] = pickup_global_id + 1
      else
        raise "Boss soul randomizer is bugged for #{LONG_GAME_NAME}."
      end
      
      enemy_dna.write_to_rom()
    elsif GAME == "dos" || GAME == "por"
      if GAME == "por" && location == "05-02-0C_01"
        # Cog's location. We always make this location use pickup flag 0x10 since Legion is hardcoded to check that flag, not whether you own the cog.
        pickup_flag = 0x10
        is_cog = true
      else
        pickup_flag = get_unused_pickup_flag_for_entity(entity)
        is_cog = false
      end
      
      if pickup_global_id == :money
        if entity.is_hidden_pickup? || is_cog || rng.rand <= 0.80
          # 80% chance to be a money bag
          # Hidden pickups have to be a bag since chests can't be hidden in a wall.
          # The cog location has to be a bag since chests can't have a pickup flag so they wouldn't be able to activate legion.
          if entity.is_hidden_pickup?
            entity.type = 7
          else
            entity.type = 4
          end
          entity.subtype = 1
          entity.var_a = pickup_flag
          use_pickup_flag(pickup_flag)
          entity.var_b = rng.rand(4..6) # 500G, 1000G, 2000G
        else
          # 20% chance to be a money chest
          entity.type = 2
          entity.subtype = 1
          if GAME == "dos"
            entity.var_a = 0x10
          else
            entity.var_a = [0xE, 0xF, 0x12].sample(random: rng)
          end
          
          # We didn't use the pickup flag, so put it back
          @unused_pickup_flags << pickup_flag
        end
        
        entity.write_to_rom()
        return
      end
      
      # Make sure Chaos/Magus Ring isn't easily available.
      if GAME == "dos" && pickup_global_id == 0xCD # Chaos Ring
        entity.type = 2
        entity.subtype = 0x4C # All-souls-owned item
        entity.var_a = pickup_flag
        use_pickup_flag(pickup_flag)
        entity.var_b = pickup_global_id + 1
        
        entity.write_to_rom()
        return
      elsif GAME == "por" && pickup_global_id == 0x12C # Magus Ring
        entity.type = 6 # All-quests-complete item
        entity.subtype = 7
        entity.var_a = pickup_flag
        use_pickup_flag(pickup_flag)
        entity.var_b = 6
        
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
          
          # We didn't use the pickup flag, so put it back
          @unused_pickup_flags << pickup_flag
        when "por"
          # Skill
          if entity.is_hidden_pickup?
            entity.type = 7
          else
            entity.type = 4
          end
          entity.subtype = item_type
          entity.var_a = pickup_flag
          use_pickup_flag(pickup_flag)
          entity.var_b = item_index
        end
      else
        # Item
        if entity.is_hidden_pickup?
          entity.type = 7
        else
          entity.type = 4
        end
        entity.subtype = item_type
        entity.var_a = pickup_flag
        use_pickup_flag(pickup_flag)
        entity.var_b = item_index
      end
      
      entity.write_to_rom()
    elsif GAME == "ooe"
      pickup_flag = get_unused_pickup_flag_for_entity(entity)
      
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
        entity.var_a = pickup_flag
        use_pickup_flag(pickup_flag)
        entity.var_b = rng.rand(4..6) # 500G, 1000G, 2000G
        
        entity.write_to_rom()
        return
      end
      
      if (0x6F..0x74).include?(pickup_global_id)
        # Relic. Must go in a chest, if you leave it lying on the ground it won't autoequip.
        entity.type = 2
        entity.subtype = 0x16
        entity.var_a = pickup_global_id + 1
        entity.var_b = pickup_flag
        use_pickup_flag(pickup_flag)
        
        entity.write_to_rom()
        return
      end
      
      if pickup_global_id >= 0x6F
        # Item
        if entity.is_hidden_pickup?
          entity.type = 7
          entity.subtype = 0xFF
          entity.var_a = pickup_flag
          use_pickup_flag(pickup_flag)
          entity.var_b = pickup_global_id + 1
        else
          case rng.rand
          when 0.00..0.70
            # 70% chance for a red chest
            entity.type = 2
            entity.subtype = 0x16
            entity.var_a = pickup_global_id + 1
            entity.var_b = pickup_flag
            use_pickup_flag(pickup_flag)
          when 0.70..0.95
            # 15% chance for an item on the ground
            entity.type = 4
            entity.subtype = 0xFF
            entity.var_a = pickup_flag
            use_pickup_flag(pickup_flag)
            entity.var_b = pickup_global_id + 1
          else
            # 5% chance for a hidden blue chest
            entity.type = 2
            entity.subtype = 0x17
            entity.var_a = pickup_global_id + 1
            entity.var_b = pickup_flag
            use_pickup_flag(pickup_flag)
          end
        end
      else
        # Glyph
        
        if entity.is_hidden_pickup?
          entity.type = 7
          entity.subtype = 2
          entity.var_a = pickup_flag
          use_pickup_flag(pickup_flag)
          entity.var_b = pickup_global_id + 1
        else
          puzzle_glyph_ids = [0x1D, 0x1F, 0x20, 0x22, 0x24, 0x26, 0x27, 0x2A, 0x2B, 0x2F, 0x30, 0x31, 0x32, 0x46, 0x4E]
          if puzzle_glyph_ids.include?(pickup_global_id)
            # Free glyph
            entity.type = 4
            entity.subtype = 2
            entity.var_a = pickup_flag
            use_pickup_flag(pickup_flag)
            entity.var_b = pickup_global_id + 1
          else
            # Glyph statue
            entity.type = 2
            entity.subtype = 2
            entity.var_a = 0
            entity.var_b = pickup_global_id + 1
            
            # We didn't use the pickup flag, so put it back
            @unused_pickup_flags << pickup_flag
          end
        end
      end
      
      if entity.is_glyph? && !entity.is_hidden_pickup?
        entity.y_pos -= 0x20
      end
      
      entity.write_to_rom()
    end
  end
  
  def remove_inaccessible_items(inaccessible_remaining_locations)
    inaccessible_remaining_locations.each do |location|
      entity = get_entity_by_location_str(location)
      
      if checker.event_locations.include?(location) || entity.type == 1
        # Don't delete inaccessible events/bosses, just in case.
        next
      end
      
      entity.type = 0
      entity.write_to_rom()
    end
  end
  
  def get_unused_pickup_flag_for_entity(entity)
    if entity.is_item_chest?
      pickup_flag = entity.var_b
    elsif entity.is_pickup?
      pickup_flag = entity.var_a
    elsif GAME == "dos" && entity.is_special_object? && entity.subtype == 0x4D # Easter egg item
      pickup_flag = entity.var_b
    elsif GAME == "dos" && entity.is_special_object? && entity.subtype == 0x4C # All-souls-obtained item
      pickup_flag = entity.var_a
    end
    
    if GAME == "ooe" && (0..0x51).include?(pickup_flag)
      # In OoE, these pickup flags are used by glyph statues automatically and we can't control those.
      # Therefore we need to reassign pickups that were free glyphs in the original game a new pickup flag, so it doesn't conflict with where those glyphs (Rapidus Fio and Volaticus) got moved to when randomized.
      pickup_flag = nil
    end
    
    if pickup_flag.nil? || @used_pickup_flags.include?(pickup_flag)
      pickup_flag = @unused_pickup_flags.pop()
      
      if pickup_flag.nil?
        raise "No pickup flag for this item, this error shouldn't happen"
      end
    end
    
    return pickup_flag
  end
  
  def get_unused_pickup_flag()
    pickup_flag = @unused_pickup_flags.pop()
    
    if pickup_flag.nil?
      raise "No pickup flag for this item, this error shouldn't happen"
    end
    
    return pickup_flag
  end
  
  def use_pickup_flag(pickup_flag)
    @used_pickup_flags << pickup_flag
    @unused_pickup_flags -= @used_pickup_flags
  end
  
  def get_entity_skill_drop_by_entity_location(location)
    entity = get_entity_by_location_str(location)
    
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
  
  def get_villager_name_by_entity_location(location)
    entity = get_entity_by_location_str(location)
    
    if GAME == "ooe" && entity.type == 2 && [0x89, 0x6D].include?(entity.subtype)
      villager_name = VILLAGER_NAME_TO_EVENT_FLAG.invert[entity.var_a]
      return villager_name
    else
      raise "Not a villager: #{location}"
    end
  end
  
  def get_portrait_name_by_entity_location(location)
    entity = get_entity_by_location_str(location)
    
    if GAME == "por" && entity.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(entity.subtype)
      portrait_name = AREA_INDEX_TO_PORTRAIT_NAME[entity.var_a]
      return portrait_name
    else
      raise "Not a portrait: #{location}"
    end
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
      
      if (0x3D..0x41).include?(pickup_global_id)
        # Magic seal. These need to call a different function to be properly given.
        
        seal_index = pickup_global_id - 0x3D
        # Seal given when watching the event
        game.fs.write(0x021CB9F4, [seal_index].pack("C"))
        game.fs.write(0x021CB9FC, [0xEB006ECF].pack("V")) # Call func 021E7540
        # Seal given when skipping the event
        game.fs.write(0x021CBC14, [seal_index].pack("C"))
        game.fs.write(0x021CBC1C, [0xEB006E47].pack("V")) # Call func 021E7540
      else
        # Regular item.
        
        # Item given when watching the event
        game.fs.write(0x021CB9F4, [item_type].pack("C"))
        game.fs.write(0x021CB9F8, [item_index].pack("C"))
        # Item given when skipping the event
        game.fs.write(0x021CBC14, [item_type].pack("C"))
        game.fs.write(0x021CBC18, [item_index].pack("C"))
      end
      
      # Item name shown in the corner of the screen when watching the event.
      game.fs.write(0x021CBA08, [item_type].pack("C"))
      game.fs.write(0x021CBA0C, [item_index].pack("C"))
      # Also display the item's name in the corner when skipping the event.
      # We add a few new lines of code in free space for this.
      code = [0xE3A00000, 0xE3A010F0, 0xEBFDB6FD, 0xE1A00005, 0xEA042E64]
      game.fs.write(0x020C027C, code.pack("V*"))
      game.fs.write(0x020C027C, [pickup_global_id+1].pack("C"))
      game.fs.write(0x021CBC20, [0xEAFBD195].pack("V"))
    elsif event_entity.subtype == 0x4D # Easter egg item
      # Change what item is actually placed into your inventory when you get the easter egg.
      easter_egg_index = event_entity.var_a
      game.fs.write(0x0222BE34 + easter_egg_index*0xC, [pickup_global_id+1].pack("v"))
      
      # Update the pickup flag.
      pickup_flag = get_unused_pickup_flag_for_entity(event_entity)
      event_entity.var_b = pickup_flag
      use_pickup_flag(pickup_flag)
      
      # Make the easter egg special object use the same palette list as actual item icons, since that gives access to all 3 icon palettes, while the actual object's palette only has the first.
      sprite_info = SpecialObjectType.new(0x4D, game.fs).extract_gfx_and_palette_and_sprite_from_create_code
      item = game.items[pickup_global_id]
      icon_palette_pointer = 0x022C4684
      game.fs.write(0x021AF5CC, [icon_palette_pointer].pack("V"))
      icon_palette_index = (item["Icon"] & 0xFF00) >> 8
      sprite = sprite_info.sprite
      sprite.frames[easter_egg_index].parts.first.palette_index = icon_palette_index
      sprite.write_to_rom()
      
      # Now update the actual item visual on the object's GFX page so it visually shows the correct item.
      sprite_info = SpecialObjectType.new(0x4D, game.fs).extract_gfx_and_palette_and_sprite_from_create_code # We extract sprite info again to get the updated palette pointer after we changed it.
      gfx = sprite_info.gfx_pages.first
      palettes = renderer.generate_palettes(sprite_info.palette_pointer, 16)
      chunky_image = renderer.render_gfx_page(gfx.file, palettes[icon_palette_index], gfx.canvas_width)
      new_icon = renderer.render_icon_by_item(item)
      x_offset = 16*easter_egg_index
      y_offset = 0
      chunky_image.replace!(new_icon, x_offset, y_offset)
      renderer.save_gfx_page(chunky_image, gfx, sprite_info.palette_pointer, 16, icon_palette_index)
    end
  end
  
  def por_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    event_entity.room.sector.load_necessary_overlay()
  end
  
  def ooe_change_hardcoded_event_pickup(event_entity, pickup_global_id)
    event_entity.room.sector.load_necessary_overlay()
    
    @glyphs_placed_as_event_glyphs << pickup_global_id
    
    if event_entity.subtype == 0x8A # Magnes
      # Get rid of the event, turn it into a normal free glyph
      # We can't keep the event because it automatically equips Magnes even if the glyph it gives is not Magnes.
      # Changing what it equips would just make the event not work right, so we may as well remove it.
      pickup_flag = get_unused_pickup_flag()
      event_entity.type = 4
      event_entity.subtype = 2
      event_entity.var_a = pickup_flag
      use_pickup_flag(pickup_flag)
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
      pickup_flag = get_unused_pickup_flag()
      event_entity.type = 4
      event_entity.subtype = 2
      event_entity.var_a = pickup_flag
      use_pickup_flag(pickup_flag)
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
      glyph_id_location, pickup_flag_read_location, pickup_flag_write_location, second_pickup_flag_read_location = case event_entity.subtype
      when 0x2F # Luminatio
        [0x022C4894, 0x022C483C, 0x022C4888]
      when 0x3B # Pneuma
        [0x022C28E8, 0x022C2880, 0x022C28DC, 0x022C279C]
      when 0x44 # Lapiste
        [0x022C2CB0, 0x022C2C24, 0x022C2CA0]
      when 0x54 # Vol Umbra
        [0x022C2FBC, 0x022C2F70, 0x022C2FB4]
      when 0x4C # Vol Fulgur
        [0x022C2490, 0x022C2404, 0x022C2480]
      when 0x52 # Vol Ignis
        [0x0221F1A0, 0x0221F148, 0x0221F194]
      when 0x47 # Vol Grando
        [0x022C230C, 0x022C2584, 0x022C22FC]
      when 0x40 # Cubus
        [0x022C31DC]
      when 0x53 # Morbus
        [0x022C2354, 0x022C2318, 0x022C2344]
      when 0x76 # Dominus Agony
        [0x022C25BC]
      else
        return
      end
      
      # What glyph is actually spawned.
      game.fs.write(glyph_id_location, [pickup_global_id+1].pack("C"))
      
      if pickup_flag_write_location
        # The pickup flag set when you absorb the glyph.
        pickup_flag = pickup_global_id+2
        game.fs.write(pickup_flag_write_location, [pickup_flag].pack("C"))
      end
      
      if pickup_flag_read_location
        # The pickup flag read to decide whether you've completed this puzzle yet or not.
        # This is determined by two lines of code:
        
        # The first loads the word in the bitfield containing the correct bit (0x20 bits in each word):
        pickup_flag_word_offset = 0x40 + 4*(pickup_flag/0x20)
        game.fs.write(pickup_flag_read_location, [pickup_flag_word_offset].pack("C"))
        game.fs.write(second_pickup_flag_read_location, [pickup_flag_word_offset].pack("C")) if second_pickup_flag_read_location
        
        # The second does a tst on the exact bit within that word:
        pickup_flag_bit_index = pickup_flag % 0x20
        game.fs.replace_hardcoded_bit_constant(pickup_flag_read_location+4, pickup_flag_bit_index)
        game.fs.replace_hardcoded_bit_constant(second_pickup_flag_read_location+4, pickup_flag_bit_index) if second_pickup_flag_read_location
      end
    end
  end
end
