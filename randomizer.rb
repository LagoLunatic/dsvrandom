
require_relative 'completability_checker'

class Randomizer
  attr_reader :options,
              :rng,
              :log,
              :game,
              :checker
  
  def initialize(seed, game, options={})
    @game = game
    @checker = CompletabilityChecker.new(game, options[:enable_glitch_reqs])
    #checker.generate_empty_item_requirements_file()
    
    @options = options
    
    @next_available_item_id = 1
    @used_skills = []
    @used_items = []
    
    FileUtils.mkdir_p("./logs")
    @log = File.open("./logs/random.txt", "a")
    if seed
      @rng = Random.new(seed)
      log.puts "Using seed: #{seed}"
    else
      @rng = Random.new
      log.puts "New random seed: #{rng.seed}"
    end
    @log.close()
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
    @boss_entities = []
    overlay_ids_for_common_enemies = OVERLAY_FILE_FOR_ENEMY_AI.select do |enemy_id, overlay_id|
      COMMON_ENEMY_IDS.include?(enemy_id)
    end
    overlay_ids_for_common_enemies = overlay_ids_for_common_enemies.values.uniq
    
    game.each_room do |room|
      @enemy_pool_for_room = []
      enemy_overlay_id_for_room = overlay_ids_for_common_enemies.sample(random: rng)
      @allowed_enemies_for_room = COMMON_ENEMY_IDS.select do |enemy_id|
        overlay = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
        overlay.nil? || overlay == enemy_overlay_id_for_room
      end
      
      room.entities.each do |entity|
        randomize_entity(entity)
      end
    end
    
    @unplaced_non_progression_pickups = all_non_progression_pickups.dup
    
    if options[:randomize_enemy_drops]
      randomize_enemy_drops()
    end
    
    if options[:randomize_pickups]
      randomize_pickups_completably()
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
  end
  
  def randomize_pickups_completably
    case GAME
    when "dos"
      checker.add_item(0x3D) # seal 1
    end
    
    previous_accessible_locations = []
    locations_randomized_to_have_useful_pickups = []
    # First place progression pickups needed to beat the game.
    while true
      pickups_by_locations = checker.pickups_by_current_num_locations_they_access()
      pickups_by_usefulness = pickups_by_locations.select{|pickup, num_locations| num_locations > 0}
      if pickups_by_usefulness.any?
        useful_pickups = pickups_by_usefulness.keys
        useful_pickup_tiers = useful_pickups.group_by{|pickup| pickups_by_usefulness[pickup]}
        least_useful_pickups = []
        # Take pickups from the least useful tiers until we have at least 5 possible pickups.
        # If we only take from the single lowest tier, it might only have one pickup in it, which is bad for variety.
        while least_useful_pickups.length < 5
          min_usefulness = useful_pickup_tiers.keys.min
          least_useful_pickups += useful_pickup_tiers.delete(min_usefulness)
          break if useful_pickup_tiers.empty?
        end
        
        item_names = least_useful_pickups.map do |global_id|
          checker.defs.invert[global_id]
        end
        puts "5 least useful pickups: #{item_names}"
        
        pickup_global_id = least_useful_pickups.sample(random: rng)
      elsif pickups_by_locations.any?
        # No item will open up any new areas. This means the player can access all locations.
        # So we just randomly place one progression pickup.
        pickup_global_id = pickups_by_locations.keys.sample(random: rng)
      else
        # All progression pickups placed.
        break
      end
      
      possible_locations = checker.get_accessible_locations()
      possible_locations -= locations_randomized_to_have_useful_pickups
      
      if !options[:randomize_boss_souls]
        # If randomize boss souls option is off, don't allow putting random things in these locations.
        accessible_unused_boss_locations = possible_locations & checker.enemy_locations
        accessible_unused_boss_locations.each do |location|
          possible_locations.delete(location)
          locations_randomized_to_have_useful_pickups << location
          
          # Also, give the player what this boss drops so the checker takes this into account.
          pickup_global_id = get_entity_soul_drop_by_entity_location(location)
          checker.add_item(pickup_global_id)
        end
        
        next if accessible_unused_boss_locations.length > 0
      end
      
      new_possible_locations = possible_locations - previous_accessible_locations.flatten
      
      if ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
        # If the pickup is an item instead of a soul, don't let bosses drop it.
        new_possible_locations -= checker.enemy_locations
      end
      
      if new_possible_locations.empty?
        previous_accessible_locations.reverse_each do |previous_accessible_region|
          new_possible_locations = previous_accessible_region
          new_possible_locations -= locations_randomized_to_have_useful_pickups
          
          break if new_possible_locations.any?
        end
        
        if new_possible_locations.empty?
          raise "Failed to find any spots to place pickup."
        end
      else
        previous_accessible_locations << new_possible_locations
      end
      
      location = new_possible_locations.sample(random: rng)
      locations_randomized_to_have_useful_pickups << location
      
      is_enemy_str = checker.enemy_locations.include?(location) ? " (boss)" : ""
      puts "Placing pickup %04X (#{checker.defs.invert[pickup_global_id]}) at #{location} #{is_enemy_str}" % pickup_global_id
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
      
      checker.add_item(pickup_global_id)
    end
    
    remaining_locations = checker.all_locations.keys - locations_randomized_to_have_useful_pickups
    remaining_locations.each_with_index do |location, i|
      if checker.enemy_locations.include?(location)
        # Boss
        pickup_global_id = get_unplaced_non_progression_skill()
      else
        # Pickup
        # 80% chance to be an item.
        # 20% chance to either be an item or a soul.
        # TODO: small chance to be a money bag/chest.
        if rng.rand <= 0.8
          pickup_global_id = get_unplaced_non_progression_item()
        else
          pickup_global_id = get_unplaced_non_progression_pickup()
        end
      end
      
      change_entity_location_to_pickup_global_id(location, pickup_global_id)
    end
    
    if !checker.check_req("beat game")
      item_names = checker.current_items.map do |global_id|
        checker.defs.invert[global_id]
      end
      raise "Bug: Game not beatable on this seed!\n\nItems:\n#{item_names.join(", ")}"
    end
  end
  
  def all_non_progression_pickups
    @all_non_progression_pickups ||= PICKUP_GLOBAL_ID_RANGE.to_a - checker.all_progression_pickups
  end
  
  def get_unplaced_non_progression_pickup
    pickup_global_id = @unplaced_non_progression_pickups.sample(random: rng)
    
    if pickup_global_id.nil?
      # Ran out of unplaced ones, so place a duplicate instead.
      @unplaced_non_progression_pickups = all_non_progression_pickups()
      return get_unplaced_non_progression_pickup()
    end
    
    @unplaced_non_progression_pickups.delete(pickup_global_id)
    
    return pickup_global_id
  end
  
  def get_unplaced_non_progression_item
    unplaced_non_progression_souls = @unplaced_non_progression_pickups.select do |pickup_global_id|
      ITEM_GLOBAL_ID_RANGE.include?(pickup_global_id)
    end
    
    item_global_id = unplaced_non_progression_souls.sample(random: rng)
    
    if item_global_id.nil?
      # Ran out of unplaced ones, so place a duplicate instead.
      @unplaced_non_progression_pickups = all_non_progression_pickups()
      return get_unplaced_non_progression_item()
    end
    
    @unplaced_non_progression_pickups.delete(item_global_id)
    
    return item_global_id
  end
  
  def get_unplaced_non_progression_skill
    unplaced_non_progression_souls = @unplaced_non_progression_pickups.select do |pickup_global_id|
      SKILL_GLOBAL_ID_RANGE.include?(pickup_global_id)
    end
    
    soul_global_id = unplaced_non_progression_souls.sample(random: rng)
    
    if soul_global_id.nil?
      # Ran out of unplaced ones, so place a duplicate instead.
      @unplaced_non_progression_pickups = all_non_progression_pickups()
      return get_unplaced_non_progression_skill()
    end
    
    @unplaced_non_progression_pickups.delete(soul_global_id)
    
    return soul_global_id
  end
  
  def change_entity_location_to_pickup_global_id(location, pickup_global_id)
    location =~ /^(\h\h)-(\h\h)-(\h\h)_(\h+)$/
    area_index, sector_index, room_index, entity_index = $1.to_i(16), $2.to_i(16), $3.to_i(16), $4.to_i(16)
    
    room = game.areas[area_index].sectors[sector_index].rooms[room_index]
    entity = room.entities[entity_index]
    
    item_type, item_index = game.get_item_type_and_index_by_global_id(pickup_global_id)
    
    if entity.type == 1
      # Boss
      if !PICKUP_SUBTYPES_FOR_SKILLS.include?(item_type)
        raise "Can't make boss drop required item"
      end
      
      if GAME == "dos" && entity.room.sector_index == 9 && entity.room.room_index == 1
        # Aguni. He's not placed in the room so we hardcode him.
        enemy_dna = game.enemy_dnas[0x70]
      else
        enemy_dna = game.enemy_dnas[entity.subtype]
      end
      
      enemy_dna["Soul"] = item_index
      enemy_dna.write_to_rom()
    else
      if PICKUP_SUBTYPES_FOR_SKILLS.include?(item_type)
        case GAME
        when "dos"
          # Soul candle
          entity.type = 2
          entity.subtype = 1
          entity.var_a = 0
          entity.var_b = item_index
        when "por"
        when "ooe"
        else
        end
      else
        # Item
        entity.type = 4
        entity.subtype = item_type
        entity.var_b = item_index
      end
      
      entity.write_to_rom()
    end
  end
  
  def get_entity_soul_drop_by_entity_location(location)
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
    
    soul_local_id = enemy_dna["Soul"]
    soul_global_id = soul_local_id + SKILL_GLOBAL_ID_RANGE.begin
    
    return soul_global_id
  end
  
  def randomize_entity(entity)
    case entity.type
    when 0x01 # Enemy
      randomize_enemy(entity)
      entity.write_to_rom()
    when 0x04
      # Pickup. These are randomized separately to ensure the game is completable.
    end
  end
  
  def randomize_enemy(enemy)
    available_enemy_ids_for_entity = nil
    
    if enemy.is_boss?
      if RANDOMIZABLE_BOSS_IDS.include?(enemy.subtype)
        # Will be randomized by a separate function.
        @boss_entities << enemy
      end
      
      return
    elsif enemy.is_common_enemy?
      return unless options[:randomize_enemies]
      
      available_enemy_ids_for_entity = @allowed_enemies_for_room.dup
    else
      puts "Enemy #{enemy.subtype} isn't in either the enemy list or boss list. Todo: fix this"
      return
    end
    
    if @enemy_pool_for_room.length >= 6
      # We don't want the room to have too many different enemies as this would take up too much space in RAM and crash.
      
      enemy.subtype = @enemy_pool_for_room.sample(random: rng)
    else
      # Enemies are chosen weighted closer to the ID of what the original enemy was so that early game enemies are less likely to roll into endgame enemies.
      # Method taken from: https://gist.github.com/O-I/3e0654509dd8057b539a
      weights = available_enemy_ids_for_entity.map do |possible_enemy_id|
        id_difference = (possible_enemy_id - enemy.subtype)
        weight = (available_enemy_ids_for_entity.length - id_difference).abs
        weight = weight**2
        weight
      end
      ps = weights.map{|w| w.to_f / weights.reduce(:+)}
      weighted_enemy_ids = available_enemy_ids_for_entity.zip(ps).to_h
      random_enemy_id = weighted_enemy_ids.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
      
      #random_enemy_id = available_enemy_ids_for_entity.sample(random: rng)
      enemy.subtype = random_enemy_id
      @enemy_pool_for_room << random_enemy_id
    end
    
    enemy_dna = game.enemy_dnas[enemy.subtype]
    case GAME
    when "dos"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "por"
      por_adjust_randomized_enemy(enemy, enemy_dna)
    when "ooe"
      ooe_adjust_randomized_enemy(enemy, enemy_dna)
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
      # So for now let's just delete these enemies so this can't happen.
      # TODO: Try to detect if they're placed near cliffs and move them a bit.
      enemy.type = 0
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
    end
  end
  
  def ooe_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Zombie", "Ghoul"
      # TODO
    when "Skeleton"
      enemy.var_a = rng.rand(0..1) # Can jump away.
    when "Bone Archer"
      enemy.var_a = rng.rand(0..8) # Arrow speed.
    when "Bat", "Fleaman"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "Ghost"
      enemy.var_a = rng.rand(1..5) # Max ghosts on screen at once.
    when "Skull Spider"
      # TODO: move out of floor
    when "Gelso"
      # TODO
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
    
    @boss_entities.each do |boss_entity|
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
    end
  end
  
  def randomize_enemy_drops
    if GAME == "ooe"
      BOSS_IDS.each do |enemy_id|
        enemy = EnemyDNA.new(enemy_id, game.fs)
        
        if enemy["Glyph"] != 0
          # Boss that has a glyph you can absorb during the fight (Albus, Barlowe, and Wallman).
          # These must be done before common enemies because otherwise there won't be any unique glyphs left to give them.
          
          enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin
          enemy["Glyph Chance"] = rng.rand(0x01..0x0F)
          
          enemy.write_to_rom()
        end
      end
    end
    
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy = EnemyDNA.new(enemy_id, game.fs)
      
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
        
        if rng.rand <= 0.20 # 20% chance to have a glyph drop
          enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin
          enemy["Glyph Chance"] = rng.rand(0x01..0x0F)
        else
          enemy["Glyph"] = 0
        end
      end
      
      enemy.write_to_rom()
    end
  end
  
  def get_random_id(global_id_range, used_list)
    available_ids = global_id_range.to_a - used_list
    id = available_ids.sample(random: rng)
    used_list << id
    return id
  end
  
  def get_random_item
    get_random_id(ITEM_GLOBAL_ID_RANGE, @used_items) || 0
  end
  
  def get_random_soul
    get_random_id(SKILL_LOCAL_ID_RANGE, @used_skills) || 0xFF
  end
  
  def get_random_glyph
    get_random_id(SKILL_LOCAL_ID_RANGE, @used_skills) || 0
  end
  
  def get_unique_id
    id = @next_available_item_id
    @next_available_item_id += 1
    return id
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
    
    # TODO: don't randomize unused doors that are blocked off behind walls like ones in the lost village.
    
    transition_rooms = game.get_transition_rooms()
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      area.sectors.each do |sector|
        remaining_doors = {
          left: [],
          up: [],
          right: [],
          down: []
        }
        
        sector.rooms.each do |room|
          next if transition_rooms.include?(room)
          
          room.doors.each do |door|
            next if transition_rooms.include?(door.destination_door.room)
            
            remaining_doors[door.direction] << door
          end
        end
        
        sector.rooms.each do |room|
          next if transition_rooms.include?(room)
          
          room.doors.each do |inside_door|
            next if transition_rooms.include?(inside_door.destination_door.room)
            
            next unless remaining_doors[inside_door.direction].include?(inside_door) # Already randomized this door
            
            remaining_doors[inside_door.direction].delete(inside_door)
            
            next if remaining_doors[inside_door.direction].length == 0
            
            old_outside_door = inside_door.destination_door
            remaining_doors[old_outside_door.direction].delete(old_outside_door)
            inside_door_to_swap_with = remaining_doors[inside_door.direction].sample(random: rng)
            remaining_doors[inside_door_to_swap_with.direction].delete(inside_door_to_swap_with)
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
    end
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      door.write_to_rom()
    end
  end
  
  def randomize_enemy_ai
    common_enemy_dnas = game.enemy_dnas[0..COMMON_ENEMY_IDS.last]
    
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
        "Unknown 21",
        "Unknown 22",
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
    game.items.each do |item|
      case GAME
      when "dos"
        randomize_item_stats_dos(item)
      end
      
      item.write_to_rom()
    end
  end
  
  def randomize_item_stats_dos(item)
    item["Price"] = rand_range_weighted_very_low(1..25000)
    
    case item.item_type_name
    when "Consumables"
      item["Type"] = rng.rand(0..4)
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
      item["Luck"]         = rand_range_weighted_very_low(0..10)
      
      item["Swing Anim"] = rng.rand(0..0xC)
      item["Super Anim"] = rng.rand(0..0xE)
      item["Sprite Anim"] = rng.rand(0..3)
      item["IFrames"] = rng.rand(4..0x28)
      
      [
        "Effects",
        "Swing Modifiers",
      ].each do |bitfield_attr_name|
        item[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Shaky weapon" # This makes the weapon appear too high up
          
          item[bitfield_attr_name][i] = [true, false].sample(random: rng)
        end
      end
    when "Armor"
      item["Attack"]       = rand_range_weighted_very_low(0..10)
      item["Defense"]      = rand_range_weighted_very_low(0..0x40)
      item["Strength"]     = rand_range_weighted_very_low(0..12)
      item["Constitution"] = rand_range_weighted_very_low(0..12)
      item["Intelligence"] = rand_range_weighted_very_low(0..12)
      item["Luck"]         = rand_range_weighted_very_low(0..12)
      
      [
        "Resistances",
      ].each do |bitfield_attr_name|
        item[bitfield_attr_name].names.each_with_index do |bit_name, i|
          item[bitfield_attr_name][i] = [true, false].sample(random: rng)
        end
      end
    end
  end
  
  def inspect; to_s; end
end
