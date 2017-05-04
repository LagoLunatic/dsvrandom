
require 'digest/md5'
require_relative 'completability_checker'

class Randomizer
  attr_reader :options,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker
  
  def initialize(seed, game, options={})
    @game = game
    @checker = CompletabilityChecker.new(game, options[:enable_glitch_reqs], options[:open_world_map])
    
    @options = options
    
    @next_available_item_id = 1
    @used_skills = []
    @used_items = []
    
    if seed.nil? || seed.empty?
      raise "No seed given"
    end
    
    FileUtils.mkdir_p("./logs")
    @seed_log = File.open("./logs/seed_log_no_spoilers.txt", "a")
    seed_log.puts "Using seed: #{seed}, Game: #{LONG_GAME_NAME}"
    seed_log.close()
    
    @seed = seed
    int_seed = Digest::MD5.hexdigest(seed).to_i(16)
    @rng = Random.new(int_seed)
  end
  
  def rand_range_weighted_low(range)
    random_float = (1 - Math.sqrt(1 - rng.rand()))
    return (random_float * (range.max + 1 - range.min) + range.min).floor
  end
  
  def rand_range_weighted_very_low(range)
    random_float = (1 - Math.sqrt(Math.sqrt(1 - rng.rand())))
    return (random_float * (range.max + 1 - range.min) + range.min).floor
  end
  
  def randomize
    @spoiler_log = File.open("./logs/spoiler_log.txt", "a")
    spoiler_log.puts "Seed: #{@seed}, Game: #{LONG_GAME_NAME}"
    
    if options[:randomize_enemies]
      randomize_enemies()
    end
    
    if options[:randomize_pickups]
      randomize_pickups_completably()
    end
    
    @unplaced_non_progression_pickups = all_non_progression_pickups.dup
    @unplaced_non_progression_pickups -= checker.current_items
    
    if options[:randomize_enemy_drops]
      randomize_enemy_drops()
    end
    
    if options[:randomize_pickups]
      place_non_progression_pickups()
    end
    
    if options[:randomize_boss_souls] && GAME == "dos"
      # If the player beats Balore but doesn't own Balore's soul they will appear stuck. (Though they could always escape with suspend.)
      # So get rid of the line of code Balore runs when he dies that recreates the Balore blocks in the room.
      
      game.fs.load_overlay(23)
      game.fs.write(0x02300808, [0xE1A00000].pack("V"))
    end
    
    if options[:randomize_bosses]
      randomize_bosses()
    end
    
    if options[:randomize_area_connections]
      randomize_transition_doors()
    end
    
    if options[:randomize_room_connections]
      randomize_non_transition_doors()
    end
    
    if options[:randomize_starting_room]
      game.fix_top_screen_on_new_game()
      randomize_starting_room()
    end
    
    if options[:randomize_enemy_ai]
      randomize_enemy_ai()
    end
    
    if options[:randomize_players]
      randomize_players()
    end
    
    if options[:randomize_item_stats]
      randomize_item_stats()
    end
    
    if options[:randomize_skill_stats]
      randomize_skill_stats()
    end
    
    if options[:randomize_enemy_stats]
      randomize_enemy_stats()
    end
    
    if options[:randomize_weapon_synths]
      randomize_weapon_synths()
    end
  rescue StandardError => e
    spoiler_log.puts "ERROR!"
    raise e
  ensure
    spoiler_log.puts
    spoiler_log.puts
    spoiler_log.close()
  end
  
  def randomize_pickups_completably
    spoiler_log.puts "Randomizing pickups:"
    
    case GAME
    when "dos"
      checker.add_item(0x3D) # seal 1
    when "por"
      checker.add_item(0x1AD) # call cube
      
      # Always replace change cube with skill cube
      checker.add_item(0x1AE) # skill cube
      change_entity_location_to_pickup_global_id("00-00-01_01", 0x1AE)
      
      # In the corridor where Behemoth chases you, change the code of the platform to not permanently disappear.
      # This is so the player can't get stuck if they miss an important item up there.
      game.fs.load_overlay(79)
      game.fs.write(0x022EC638, [0xEA000003].pack("V"))
    when "ooe"
      checker.add_item(0x6F) # lizard tail
      checker.add_item(0x72) # glyph union
      
      # Give the player the glyph sleeve in Ecclesia like in hard mode.
      # To do this just get rid of the entity hider that hides it on normal mode.
      entity_hider = game.areas[2].sectors[0].rooms[4].entities[6]
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
      
      checker.add_item(0x1E) # torpor. the player will get enough of these as it is
      
      # For OoE we sometimes need pickup flags for when a glyph statue gets randomized into something that's not a glyph statue.
      # Flags 12F-149 are unused in the base game but still work, so use those.
      @unused_picked_up_flags = (0x12F..0x149).to_a
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
      spoiler_str = "Placing #{pickup_str} at #{location}#{is_enemy_str}#{is_event_str} (#{area_name})"
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
      if pickup_global_id == :money
        case rng.rand
        when 0.00..0.20 # 20% chance to be a money chest
          entity.type = 2
          entity.subtype = 1
          if GAME == "dos"
            entity.var_a = 0x10
          else
            entity.var_a = rng.rand(0x0E..0x0F)
          end
        when 0.20..1.00 # 80% chance to be a money bag
          entity.type = 4
          entity.subtype = 1
          entity.var_b = rng.rand(3..6)
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
        when "por"
          # Skill
          unless entity.is_hidden_pickup?
            entity.type = 4
          end
          entity.subtype = item_type
          entity.var_b = item_index
        end
      else
        # Item
        unless entity.is_hidden_pickup?
          entity.type = 4
        end
        entity.subtype = item_type
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
      
      if entity.is_glyph?
        entity.y_pos += 0x20
      end
      
      if pickup_global_id == :money
        entity.type = 4
        entity.subtype = 1
        entity.var_a = picked_up_flag
        entity.var_b = rng.rand(3..6)
        
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
          case rng.rand
          when 0.00..0.50
            # 50% chance for a glyph statue
            entity.type = 2
            entity.subtype = 2
            entity.var_a = 0
            entity.var_b = pickup_global_id + 1
            
            # We didn't use the picked up flag, so put it back
            @unused_picked_up_flags << picked_up_flag
          else
            # 50% chance for a free glyph
            entity.type = 4
            entity.subtype = 2
            entity.var_a = picked_up_flag
            entity.var_b = pickup_global_id + 1
          end
        end
      end
      
      if entity.is_glyph?
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
    elsif event_entity.subtype == 0x82 || event_entity.subtype == 0x83 # Cerberus
      # Delete it, we don't need 3 glyphs
      event_entity.type = 0
      event_entity.write_to_rom()
    end
    
    hardcoded_glyph_location = case event_entity.subtype
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
    
    game.fs.write(hardcoded_glyph_location, [pickup_global_id+1].pack("C"))
  end
  
  def randomize_enemies
    overlay_ids_for_common_enemies = OVERLAY_FILE_FOR_ENEMY_AI.select do |enemy_id, overlay_id|
      COMMON_ENEMY_IDS.include?(enemy_id)
    end
    overlay_ids_for_common_enemies = overlay_ids_for_common_enemies.values.uniq
    
    @skeletally_animated_enemy_ids = COMMON_ENEMY_IDS.select do |enemy_id|
      overlay_id = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
      if overlay_id
        true
      else
        begin
          enemy_dna = game.enemy_dnas[enemy_id]
          sprite_info = enemy_dna.extract_gfx_and_palette_and_sprite_from_init_ai
          if sprite_info.skeleton_file
            true
          else
            false
          end
        rescue StandardError => e
          puts "Error getting sprite info for enemy id %02X" % enemy_id
          true # Probably a 3D enemy, so count it anyway
        end
      end
    end
    
    game.each_room do |room|
      @enemy_pool_for_room = []
      @enemy_gfx_load_in_room = 0
      @total_skeletally_animated_enemies_in_room = 0
      
      enemy_overlay_id_for_room = overlay_ids_for_common_enemies.sample(random: rng)
      @allowed_enemies_for_room = COMMON_ENEMY_IDS.select do |enemy_id|
        overlay = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
        overlay.nil? || overlay == enemy_overlay_id_for_room
      end
      
      enemies_in_room = room.entities.select{|e| e.is_common_enemy?}
      
      next if enemies_in_room.empty?
      
      if enemies_in_room.length >= 8
        # Don't let skeletally animated enemies in rooms that have tons of enemies.
        
        @allowed_enemies_for_room -= @skeletally_animated_enemy_ids
      end
      
      # Calculate how difficult a room originally was by the sum of the Attack value of all enemies in the room.
      original_room_difficulty = enemies_in_room.reduce(0) do |difficulty, enemy|
        enemy_dna = game.enemy_dnas[enemy.subtype]
        difficulty + enemy_dna["Attack"]
      end
      new_room_difficulty = 0
      
      # Only allow tough enemies in the room up to 2x the original room's difficulty.
      remaining_new_room_difficulty = original_room_difficulty*2
      
      # Only allow enemies up to 1.5x tougher than the toughest enemy in the original room.
      max_enemy_attack = enemies_in_room.map do |enemy|
        enemy_dna = game.enemy_dnas[enemy.subtype]
        enemy_dna["Attack"]
      end.max
      max_allowed_enemy_attack = max_enemy_attack*1.5
      
      enemies_in_room.shuffle(random: rng).each do |enemy|
        @allowed_enemies_for_room.select! do |enemy_id|
          enemy_dna = game.enemy_dnas[enemy_id]
          if enemy_dna["Attack"] <= 32
            # Always allow weak enemies (attack 32 or less) in the room.
            true
          elsif enemy_dna["Attack"] <= remaining_new_room_difficulty && enemy_dna["Attack"] <= max_allowed_enemy_attack
            true
          else
            false
          end
        end
        
        randomize_enemy(enemy)
        
        remaining_new_room_difficulty -= enemy.subtype
        
        if @total_skeletally_animated_enemies_in_room >= 2
          # We don't want too many skeletally animated enemies on screen at once, as it takes up too much processing power.
          
          @allowed_enemies_for_room -= @skeletally_animated_enemy_ids
          @enemy_pool_for_room -= @skeletally_animated_enemy_ids
        end
      end
    end
  end
  
  def randomize_enemy(enemy)
    if GAME == "dos" && enemy.room.sector_index == 4 && enemy.room.room_index == 0x10 && enemy.subtype == 0x3A
      # That one Malachi needed for Dmitrii's event. Don't do anything to it or the event gets messed up.
      return
    end
    
    if @enemy_gfx_load_in_room >= 6 && @enemy_pool_for_room.any?
      # We don't want the room to have too many different enemies as this would take up too much space in RAM and crash.
      
      random_enemy_id = @enemy_pool_for_room.sample(random: rng)
    else
      # Enemies are chosen weighted closer to the ID of what the original enemy was so that early game enemies are less likely to roll into endgame enemies.
      # Method taken from: https://gist.github.com/O-I/3e0654509dd8057b539a
      max_enemy_id = ENEMY_IDS.max
      weights = @allowed_enemies_for_room.map do |possible_enemy_id|
        id_difference = (possible_enemy_id - enemy.subtype).abs
        weight = max_enemy_id - id_difference
        weight**3
      end
      ps = weights.map{|w| w.to_f / weights.reduce(:+)}
      weighted_enemy_ids = @allowed_enemies_for_room.zip(ps).to_h
      random_enemy_id = weighted_enemy_ids.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
    end
    
    enemy_dna = game.enemy_dnas[random_enemy_id]
    
    result = case GAME
    when "dos"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "por"
      por_adjust_randomized_enemy(enemy, enemy_dna)
    when "ooe"
      ooe_adjust_randomized_enemy(enemy, enemy_dna)
    end
    
    if result == :redo
      randomize_enemy(enemy)
    else
      enemy.subtype = random_enemy_id
      enemy.write_to_rom()
      @enemy_pool_for_room << random_enemy_id
      @enemy_gfx_load_in_room += 1
      
      if @skeletally_animated_enemy_ids.include?(random_enemy_id)
        # Count skeletally animated enemies as 2 for the purposes of the enemy pool, so that less unique enemies total can get in the room.
        @enemy_gfx_load_in_room += 2
        @total_skeletally_animated_enemies_in_room += 1
      end
    end
  end
  
  def dos_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Zombie", "Ghoul"
      # 50% chance to be a single zombie, 50% chance to be a spawner.
      if rng.rand <= 0.5
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(2..16)
      end
    when "Bat"
      # 50% chance to be a single bat, 50% chance to be a spawner.
      if rng.rand <= 0.5
        enemy.var_a = 0
      else
        enemy.var_a = 0x100
      end
    when "Skull Archer"
      enemy.var_a = rng.rand(0..8) # Arrow speed.
    when "Slime", "Tanjelly"
      enemy.var_a = rng.rand(0..3) # Floor/ceiling/left wall/right wall
    when "Mollusca", "Giant Slug"
      # Mollusca and Giant Slug have a very high chance of bugging out when placed near cliffs.
      # They can cause the screen to flash rapidly and take up most of the screen.
      # They can also cause the game to freeze for a couple seconds every time you enter a room with them in it.
      # So for now let's just not place these enemies so this can't happen.
      # TODO: Try to detect if they're placed near cliffs and move them a bit.
      return :redo
    when "Ghost Dancer"
      enemy.var_a = rng.rand(0..2) # Palette
    when "Killer Doll"
      enemy.var_b = rng.rand(0..1) # Direction
    when "Fleaman"
      enemy.var_a = rng.rand(1..5)
    when "Bone Pillar", "Fish Head"
      enemy.var_a = rng.rand(1..10)
    when "Malachi"
      enemy.var_a = 0
    when "Medusa Head"
      enemy.var_a = rng.rand(1..7) # Max at once
      enemy.var_b = rng.rand(0..1) # Type of Medusa Head
    when "Mud Demon"
      enemy.var_b = rng.rand(0..0x50) # Max rand spawn distance
    when "Stolas"
      enemy_id_a = @allowed_enemies_for_room.sample(random: rng)
      enemy_id_b = @allowed_enemies_for_room.sample(random: rng)
      chance_a = rng.rand(0x10..0xF0)
      chance_b = rng.rand(0x10..0xF0)
      enemy.var_a = (chance_a << 8) | enemy_id_a
      enemy.var_b = (chance_b << 8) | enemy_id_b
    end
  end
  
  def por_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Bat", "Fleaman"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "Hanged Bones", "Skeleton Tree"
      enemy.var_b = 0
      enemy.y_pos = 0x20
    when "Spittle Bone", "Vice Beetle"
      # TODO: move out of floor
      enemy.var_a = rng.rand(0..3) # wall direction
      enemy.var_b = rng.rand(0x600..0x1200) # speed
    when "Razor Bat"
      # 70% chance to be a single Razor Bat, 30% chance to be a spawner.
      if rng.rand <= 0.7
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(0xA0..0x1A0)
      end
    when "Sand Worm", "Poison Worm"
      if enemy.room.main_layer_height > 1
        # Don't allow in tall rooms
        return :redo
      end
      if enemy.room.main_layer_width <= 1
        # Don't allow in non-wide rooms
        return :redo
      end
      if enemy.room.doors.find{|door| door.y_pos >= 1}
        # Don't allow in rooms that have a door in the floor
        return :redo
      end
      
      enemy.var_a = 1
    end
  end
  
  def ooe_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Zombie", "Ghoul"
      if rng.rand <= 0.30 # 30% chance to be a single Zombie
        enemy.var_a = 0
        enemy.var_b = 0
      else # 70% chance to be a spawner
        enemy.var_a = rng.rand(3..8) # Max at once
        
        room_width = enemy.room.main_layer_width*SCREEN_WIDTH_IN_PIXELS
        enemy.var_b = rng.rand(100..room_width) # Max horizontal distance in pixels from the spawner to spawn the Zombies
      end
    when "Skeleton"
      enemy.var_a = rng.rand(0..1) # Can jump away.
    when "Bone Archer"
      enemy.var_a = rng.rand(0..8) # Arrow speed.
    when "Bat"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "Axe Knight"
      # 80% chance to be normal, 20% chance to start out in pieces.
      if rng.rand() <= 0.80
        enemy.var_b = 0
      else
        enemy.var_b = 1
      end
    when "Flea Man"
      # TODO var A?
      enemy.var_b = 0
    when "Ghost"
      enemy.var_a = rng.rand(1..5) # Max ghosts on screen at once.
    when "Skull Spider"
      # Move out of the floor
      enemy.y_pos -= 0x08
    when "Gelso"
      if rng.rand <= 0.40 # 40% chance to be a single Gelso
        enemy.var_a = 0
        enemy.var_b = 0
      else # 60% chance to be a spawner
        enemy.var_a = rng.rand(1..6) # Max at once
        enemy.var_b = rng.rand(60..360) # Frames in between spawning them
      end
    when "Merman"
      # Move out of the floor
      enemy.y_pos -= 0x10
    when "Saint Elmo"
      enemy.var_a = rng.rand(1..3)
      enemy.var_b = 0x78
    end
  end
  
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
  
  def randomize_enemy_drops
    if GAME == "ooe"
      [0x67, 0x72, 0x73].each do |enemy_id|
        # Boss that has a glyph you can absorb during the fight (Jiang Shi, Albus, and Barlowe).
        # Wallman's glyph is not handled here, as that can be a progression glyph.
        
        enemy = game.enemy_dnas[enemy_id]
        enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin + 1
        enemy.write_to_rom()
      end
    end
    
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy = game.enemy_dnas[enemy_id]
      
      if rng.rand <= 0.5 # 50% chance to have an item drop
        if GAME == "por"
          enemy["Item 1"] = get_unplaced_non_progression_pickup() + 1
        else
          enemy["Item 1"] = get_unplaced_non_progression_item() + 1
        end
        
        if rng.rand <= 0.5 # Further 50% chance (25% total) to have a second item drop
          if GAME == "por"
            enemy["Item 2"] = get_unplaced_non_progression_pickup() + 1
          else
            enemy["Item 2"] = get_unplaced_non_progression_item() + 1
          end
        else
          enemy["Item 2"] = 0
        end
      else
        enemy["Item 1"] = 0
        enemy["Item 2"] = 0
      end
      
      case GAME
      when "dos"
        enemy["Item Chance"] = rng.rand(0x04..0x50)
        
        enemy["Soul"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin
        enemy["Soul Chance"] = rng.rand(0x01..0x30)
      when "por"
        enemy["Item 1 Chance"] = rng.rand(0x01..0x32)
        enemy["Item 2 Chance"] = rng.rand(0x01..0x32)
      when "ooe"
        enemy["Item 1 Chance"] = rng.rand(0x01..0x0F)
        enemy["Item 2 Chance"] = rng.rand(0x01..0x0F)
        
        if enemy["Glyph"] != 0
          # Only give glyph drops to enemies that original had a glyph drop.
          # Other enemies cannot drop a glyph anyway.
          enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin + 1
          if enemy["Glyph Chance"] != 100
            # Don't set glyph chance if it was originally 100%, because it won't matter for those enemies.
            # Otherwise set it to 1-20%.
            enemy["Glyph Chance"] = rng.rand(1..20)
          end
        end
      end
      
      enemy.write_to_rom()
    end
  end
  
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
  end
  
  def randomize_transition_doors
    transition_rooms = game.get_transition_rooms()
    remaining_transition_rooms = transition_rooms.dup
    remaining_transition_rooms.reject! do |room|
      FAKE_TRANSITION_ROOMS.include?(room.room_metadata_ram_pointer)
    end
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    transition_rooms.shuffle(random: rng).each_with_index do |transition_room, i|
      next unless remaining_transition_rooms.include?(transition_room) # Already randomized this room
      
      remaining_transition_rooms.delete(transition_room)
      
      # Transition rooms can only lead to rooms in the same area or the game will crash.
      remaining_transition_rooms_for_area = remaining_transition_rooms.select do |other_room|
        transition_room.area_index == other_room.area_index
      end
      
      if remaining_transition_rooms_for_area.length == 0
        # There aren't any more transition rooms left in this area to randomize with.
        # This is because the area had an odd number of transition rooms, so not all of them can be swapped.
        next
      end
      
      # Only randomize one of the doors, no point in randomizing them both.
      inside_door = transition_room.doors.first
      old_outside_door = inside_door.destination_door
      transition_room_to_swap_with = remaining_transition_rooms_for_area.sample(random: rng)
      remaining_transition_rooms.delete(transition_room_to_swap_with)
      inside_door_to_swap_with = transition_room_to_swap_with.doors.first
      new_outside_door = inside_door_to_swap_with.destination_door
      
      queued_door_changes[inside_door]["destination_room_metadata_ram_pointer"] = inside_door_to_swap_with.destination_room_metadata_ram_pointer
      queued_door_changes[inside_door]["dest_x"] = inside_door_to_swap_with.dest_x
      queued_door_changes[inside_door]["dest_y"] = inside_door_to_swap_with.dest_y
      
      queued_door_changes[inside_door_to_swap_with]["destination_room_metadata_ram_pointer"] = inside_door.destination_room_metadata_ram_pointer
      queued_door_changes[inside_door_to_swap_with]["dest_x"] = inside_door.dest_x
      queued_door_changes[inside_door_to_swap_with]["dest_y"] = inside_door.dest_y
      
      queued_door_changes[old_outside_door]["destination_room_metadata_ram_pointer"] = new_outside_door.destination_room_metadata_ram_pointer
      queued_door_changes[old_outside_door]["dest_x"] = new_outside_door.dest_x
      queued_door_changes[old_outside_door]["dest_y"] = new_outside_door.dest_y
      
      queued_door_changes[new_outside_door]["destination_room_metadata_ram_pointer"] = old_outside_door.destination_room_metadata_ram_pointer
      queued_door_changes[new_outside_door]["dest_x"] = old_outside_door.dest_x
      queued_door_changes[new_outside_door]["dest_y"] = old_outside_door.dest_y
    end
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      door.write_to_rom()
    end
  end
  
  def randomize_non_transition_doors
    # TODO: make sure every room in an area is accessible. this is to prevent infinite loops of a small number of rooms that connect to each other with no way to progress.
    # loop through each room. search for remaining rooms that have a matching door. but the room we find must also have remaining doors in it besides the one we swap with so it's not a dead end, or a loop. if there are no rooms that meet those conditions, then we go with the more lax condition of just having a matching door, allowing dead ends.
    
    transition_rooms = game.get_transition_rooms()
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      area.sectors.each do |sector|
        puts "SECTOR #{sector.sector_index}"
        remaining_doors = {
          left: [],
          up: [],
          right: [],
          down: []
        }
        
        map = game.get_map(sector.area_index, sector.sector_index)
        
        sector.rooms.each do |room|
          next if transition_rooms.include?(room)
          
          room.doors.each do |door|
            next if transition_rooms.include?(door.destination_door.room)
            
            map_tile_x_pos = room.room_xpos_on_map
            map_tile_y_pos = room.room_ypos_on_map
            
            if door.x_pos == 0xFF
              # Do nothing
            elsif door.x_pos >= room.main_layer_width
              map_tile_x_pos += room.main_layer_width - 1
            else
              map_tile_x_pos += door.x_pos
            end
            if door.y_pos == 0xFF
              # Do nothing
            elsif door.y_pos >= room.main_layer_height
              map_tile_y_pos += room.main_layer_height - 1
            else
              map_tile_y_pos += door.y_pos
            end
            
            map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos &&  tile.y_pos == map_tile_y_pos}
            
            if map_tile.nil?
              # Door that's not on the map, just an unused door.
              next
            end
            
            # If the door is a secret door, or is shown on the map as a wall, skip it.
            # The player won't be able to enter secret doors from the wrong side, they'd just get stopped by the breakable wall.
            # As for ones shown as a normal wall, those are leftover doors not intended to be used, and are inaccessible (except with warp glitches).
            case door.direction
            when :left
              if map_tile.left_secret || map_tile.left_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, LEFT" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.left_secret || map_tile.left_wall
            when :right
              if map_tile.right_secret || map_tile.right_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, RIGHT" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.right_secret || map_tile.right_wall
            when :up
              if map_tile.top_secret || map_tile.top_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, UP" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.top_secret || map_tile.top_wall
            when :down
              if map_tile.bottom_secret || map_tile.bottom_wall
                puts "AREA: %02X, X: %02X, Y: %02X, door: %08X, DOWN" % [sector.area_index, map_tile_x_pos, map_tile_y_pos, door.door_ram_pointer]
              end
              next if map_tile.bottom_secret || map_tile.bottom_wall
            end
            
            remaining_doors[door.direction] << door
          end
        end
        
        all_rooms = remaining_doors.values.flatten.map{|door| door.room}.uniq
        if all_rooms.empty?
          # No doors in this sector
          next
        end
        unvisited_rooms = all_rooms.dup
        accessible_remaining_doors = []
        
        current_room = unvisited_rooms.sample(random: rng)
        
        while true
          puts "on room %08X" % current_room.room_metadata_ram_pointer
          unvisited_rooms.delete(current_room)
          
          accessible_remaining_doors += remaining_doors.values.flatten.select{|door| door.room == current_room}
          accessible_remaining_doors.uniq!
          
          inside_door = accessible_remaining_doors.sample(random: rng)
          remaining_doors[inside_door.direction].delete(inside_door)
          
          inaccessible_remaining_matching_doors = remaining_doors[inside_door.direction] - accessible_remaining_doors
          
          inaccessible_remaining_matching_doors_with_other_exits = inaccessible_remaining_matching_doors.select do |door|
            door.room.doors.length > 1 && unvisited_rooms.include?(door.room)
          end
          
          inaccessible_remaining_matching_doors_with_other_direction_exits = inaccessible_remaining_matching_doors_with_other_exits.select do |door|
            if door.direction == :left || door.direction == :right
              door.room.doors.any?{|x| x.direction == :up || x.direction == :down}
            else
              door.room.doors.any?{|x| x.direction == :left || x.direction == :right}
            end
          end
          
          if inaccessible_remaining_matching_doors_with_other_direction_exits.any?
            # There are doors we can swap with that allow more progress, and also allow going in a new direction (up/down vs left/right).
            possible_swap_doors = inaccessible_remaining_matching_doors_with_other_direction_exits
          elsif inaccessible_remaining_matching_doors_with_other_exits.any?
            # There are doors we can swap with that allow more progress.
            possible_swap_doors = inaccessible_remaining_matching_doors_with_other_exits
          elsif inaccessible_remaining_matching_doors.any?
            # There are doors we can swap with that will allow you to reach one new room which is a dead end.
            possible_swap_doors = inaccessible_remaining_matching_doors
          elsif remaining_doors[inside_door.direction].any?
            # This door direction doesn't have any more matching doors left to swap with that will result in progress.
            # So just pick any matching door.
            possible_swap_doors = remaining_doors[inside_door.direction]
          else
            # This door direction doesn't have any matching doors left.
            # Don't do anything to this door.
            
            #puts "#{inside_door.direction} empty"
            #
            #accessible_rooms = accessible_remaining_doors.map{|door| door.room}.uniq
            #accessible_rooms -= [current_room]
            #
            #current_room = accessible_rooms.sample(random: rng)
            #p accessible_remaining_doors.size
            #gets
            
            current_room = unvisited_rooms.sample(random: rng)
            p "3 #{current_room}"
            
            if current_room.nil?
              current_room = all_rooms.sample(random: rng)
              p "2 #{current_room}"
            end
            
            if remaining_doors.values.flatten.empty?
              break
            end
            
            next
          end
          
          inside_door_to_swap_with = possible_swap_doors.sample(random: rng)
          remaining_doors[inside_door_to_swap_with.direction].delete(inside_door_to_swap_with)
          current_room = inside_door_to_swap_with.room
          p "1 #{current_room}"
          
          old_outside_door = inside_door.destination_door
          remaining_doors[old_outside_door.direction].delete(old_outside_door)
          new_outside_door = inside_door_to_swap_with.destination_door
          remaining_doors[new_outside_door.direction].delete(new_outside_door)
          
          queued_door_changes[inside_door]["destination_room_metadata_ram_pointer"] = inside_door_to_swap_with.destination_room_metadata_ram_pointer
          queued_door_changes[inside_door]["dest_x"] = inside_door_to_swap_with.dest_x
          queued_door_changes[inside_door]["dest_y"] = inside_door_to_swap_with.dest_y
          
          queued_door_changes[inside_door_to_swap_with]["destination_room_metadata_ram_pointer"] = inside_door.destination_room_metadata_ram_pointer
          queued_door_changes[inside_door_to_swap_with]["dest_x"] = inside_door.dest_x
          queued_door_changes[inside_door_to_swap_with]["dest_y"] = inside_door.dest_y
          
          queued_door_changes[old_outside_door]["destination_room_metadata_ram_pointer"] = new_outside_door.destination_room_metadata_ram_pointer
          queued_door_changes[old_outside_door]["dest_x"] = new_outside_door.dest_x
          queued_door_changes[old_outside_door]["dest_y"] = new_outside_door.dest_y
          
          queued_door_changes[new_outside_door]["destination_room_metadata_ram_pointer"] = old_outside_door.destination_room_metadata_ram_pointer
          queued_door_changes[new_outside_door]["dest_x"] = old_outside_door.dest_x
          queued_door_changes[new_outside_door]["dest_y"] = old_outside_door.dest_y
        end
      end
    end
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      door.write_to_rom()
    end
  end
  
  def randomize_enemy_ai
    common_enemy_dnas = game.enemy_dnas.select{|enemy_id| COMMON_ENEMY_IDS.include?(enemy_id)}
    
    common_enemy_dnas.each do |this_dna|
      this_overlay = OVERLAY_FILE_FOR_ENEMY_AI[this_dna]
      available_enemies_with_same_overlay = common_enemy_dnas.select do |other_dna|
         other_overlay = OVERLAY_FILE_FOR_ENEMY_AI[other_dna.enemy_id]
         other_overlay.nil? || other_overlay == this_overlay
      end
      
      this_dna["Running AI"] = available_enemies_with_same_overlay.sample(random: rng)["Running AI"]
      this_dna.write_to_rom()
    end
  end
  
  def randomize_players
    players = game.players
    
    players.each do |player|
      player["Walking speed"]       =  rng.rand(0x1400..0x2000)
      player["Jump force"]          = -rng.rand(0x5A00..0x6000)
      player["Double jump force"]   = -rng.rand(0x4A00..0x6000)
      player["Slide force"]         =  rng.rand(0x1800..0x5000)
      player["Backdash force"]      = -rng.rand(0x3800..0x5800)
      player["Backdash friction"]   =  rng.rand(0x100..0x230)
      player["Backdash duration"]   =  rng.rand(20..60)
      player["Trail scale"]         =  rng.rand(0x0D00..0x1200)
      player["Enable player scale"] =  rng.rand(0..1)
      player["Player height scale"] =  player["Trail scale"]
      player["Number of trails"]    =  rng.rand(0x00..0x14)
      
      ["Trail start color", "Trail end color"].each do |attr_name|
        color = 0
        color |= rng.rand(0..0x1F)
        color |= rng.rand(0..0x1F) << 8
        color |= rng.rand(0..0x1F) << 16
        color |= rng.rand(0..0x1F) << 24
        player[attr_name] = color
      end
      
      [
        "Actions",
        "??? bitfield",
        "Damage types",
      ].each do |bitfield_attr_name|
        next if player[bitfield_attr_name].nil?
        
        player[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Horizontal flip"
          next if bit_name == "Is currently AI partner"
          
          if ["Can slide", "Can use weapons", "Can up-pose", "Can absorb glyphs"].include?(bit_name)
            player[bitfield_attr_name][i] = true
            next
          end
          
          player[bitfield_attr_name][i] = [true, false].sample(random: rng)
        end
      end
    end
    
    # Shuffle some player attributes such as graphics
    remaining_players = players.dup
    players.each do |player|
      next unless remaining_players.include?(player) # Already randomized this player
      
      remaining_players.delete(player)
      
      break if remaining_players.empty?
      
      other_player = remaining_players.sample(random: rng)
      remaining_players.delete(other_player)
      
      [
        "GFX list pointer",
        "Sprite pointer",
        "Palette pointer",
        "State anims ptr",
        "GFX file index",
        "Sprite file index",
        "Filename pointer",
        "Sprite Y offset",
        "Hitbox pointer",
        "Face icon frame",
        "Palette unknown 1",
        "Palette unknown 2",
      ].each do |attr_name|
        player[attr_name], other_player[attr_name] = other_player[attr_name], player[attr_name]
      end
      
      # Horizontal flip bit
      player["??? bitfield"][0], other_player["??? bitfield"][0] = other_player["??? bitfield"][0], player["??? bitfield"][0]
    end
    
    players.each do |player|
      player["Actions"][1] = true # Can use weapons
      player["Actions"][16] = false # No gravity
      if player["Damage types"]
        player["Damage types"][18] = true # Can be hit
      end
      
      player.write_to_rom()
    end
  end
  
  def randomize_item_stats
    game.items[ITEM_GLOBAL_ID_RANGE].each do |item|
      item["Price"] = rand_range_weighted_very_low(1..25000)
      
      case item.item_type_name
      when "Consumables"
        item["Type"] = rng.rand(0..4)
        # TODO OoE
        
        case item["Type"]
        when 0, 1, 3
          item["Var A"] = rand_range_weighted_very_low(1..4000)
        when 2
          item["Var A"] = rng.rand(1..2)
        end
      when "Weapons"
        item["Attack"]       = rand_range_weighted_very_low(0..0xA0)
        item["Defense"]      = rand_range_weighted_very_low(0..10)
        item["Strength"]     = rand_range_weighted_very_low(0..10)
        item["Constitution"] = rand_range_weighted_very_low(0..10)
        item["Intelligence"] = rand_range_weighted_very_low(0..10)
        item["Mind"]         = rand_range_weighted_very_low(0..10) if GAME == "por" || GAME == "ooe"
        item["Luck"]         = rand_range_weighted_very_low(0..10)
        item["IFrames"] = rng.rand(4..0x28)
        
        case GAME
        when "dos"
          item["Swing Anim"] = rng.rand(0..0xC)
          item["Super Anim"] = rng.rand(0..0xE)
          item["Sprite Anim"] = rng.rand(0..3)
        when "por"
          item["Swing Anim"] = rng.rand(0..9)
          item["Crit type/Palette"] = rng.rand(0..0x13)
          item["Graphical Effect"] = rng.rand(0..7)
          item["Equippable by"].value = rng.rand(1..3)
        end
        
        [
          "Effects",
          "Swing Modifiers",
        ].each do |bitfield_attr_name|
          item[bitfield_attr_name].names.each_with_index do |bit_name, i|
            next if bit_name == "Shaky weapon" && GAME == "dos" # This makes the weapon appear too high up
            
            item[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
          end
        end
      when "Armor", "Body Armor", "Head Armor", "Leg Armor", "Accessories"
        item["Attack"]       = rand_range_weighted_very_low(0..10)
        item["Defense"]      = rand_range_weighted_very_low(0..0x40)
        item["Strength"]     = rand_range_weighted_very_low(0..12)
        item["Constitution"] = rand_range_weighted_very_low(0..12)
        item["Intelligence"] = rand_range_weighted_very_low(0..12)
        item["Mind"]         = rand_range_weighted_very_low(0..12) if GAME == "por" || GAME == "ooe"
        item["Luck"]         = rand_range_weighted_very_low(0..12)
        
        item["Equippable by"].value = rng.rand(1..3) if GAME == "por"
        
        [
          "Resistances",
        ].each do |bitfield_attr_name|
          item[bitfield_attr_name].names.each_with_index do |bit_name, i|
            item[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
          end
        end
      end
      
      item.write_to_rom()
    end
  end
  
  def randomize_skill_stats
    game.items[SKILL_GLOBAL_ID_RANGE].each do |skill|
      skill["Mana cost"] = rng.rand(1..60)
      skill["DMG multiplier"] = rand_range_weighted_low(1..50)
      
      skill["Soul Scaling"] = rng.rand(0..4) if GAME == "dos"
      
      skill["Max at once"] = rand_range_weighted_low(1..6) if GAME == "ooe"
      skill["IFrames"] = rand_range_weighted_low(1..0x24) if GAME == "ooe"
      skill["Delay"] = rand_range_weighted_low(0..14) if GAME == "ooe"
      # TODO glyph union
      
      [
        "??? bitfield",
        "Effects",
        "Unwanted States",
      ].each do |bitfield_attr_name|
        next if skill[bitfield_attr_name].nil?
        
        skill[bitfield_attr_name].names.each_with_index do |bit_name, i|
          skill[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
        end
      end
      
      skill.write_to_rom()
    end
  end
  
  def randomize_enemy_stats
    game.enemy_dnas.each do |enemy_dna|
      enemy_dna["HP"]      = (enemy_dna["HP"]*rng.rand(0.5..3.0)).round
      enemy_dna["MP"]      = (enemy_dna["MP"]*rng.rand(0.5..3.0)).round if GAME == "dos"
      enemy_dna["SP"]      = (enemy_dna["SP"]*rng.rand(0.5..3.0)).round if GAME == "por"
      enemy_dna["AP"]      = (enemy_dna["AP"]*rng.rand(0.5..3.0)).round if GAME == "ooe"
      enemy_dna["EXP"]     = (enemy_dna["EXP"]*rng.rand(0.5..3.0)).round
      enemy_dna["Attack"]  = (enemy_dna["Attack"]*rng.rand(0.5..3.0)).round
      enemy_dna["Defense"] = (enemy_dna["Defense"]*rng.rand(0.5..3.0)).round if GAME == "dos"
      enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*rng.rand(0.5..3.0)).round if GAME == "por" || GAME == "ooe"
      enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"]*rng.rand(0.5..3.0)).round if GAME == "por" || GAME == "ooe"
      
      [
        "Weaknesses",
        "Resistances",
      ].each do |bitfield_attr_name|
        enemy_dna[bitfield_attr_name].names.each_with_index do |bit_name, i|
          enemy_dna[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
        end
      end
      
      enemy_dna.write_to_rom()
    end
  end
  
  def randomize_weapon_synths
    return unless GAME == "dos"
    
    WEAPON_SYNTH_CHAIN_NAMES.each_index do |index|
      chain = WeaponSynthChain.new(index, game.fs)
      chain.synths.each do |synth|
        synth.required_item_id = rng.rand(ITEM_GLOBAL_ID_RANGE) + 1
        synth.required_soul_id = rng.rand(SKILL_LOCAL_ID_RANGE)
        synth.created_item_id = rng.rand(ITEM_GLOBAL_ID_RANGE) + 1
        
        synth.write_to_rom()
      end
    end
  end
  
  def inspect; to_s; end
end
