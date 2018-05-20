
module EnemyRandomizer
  MAX_ASSETS_PER_ROOM = 16
  
  RESOURCE_INTENSIVE_ENEMY_NAMES = [
    "Forneus",
    "Spin Devil",
    "Stolas",
    "Necromancer",
    "Mollusca",
    "Giant Slug",
    "Invisible Man",
    "Quetzalcoatl",
    "Ukoback",
    "White Dragon",
    "Bone Pillar",
    "Fish Head",
    "Bone Ark",
    "Fleaman",
    "Edimmu",
  ]
  
  attr_reader :coll
  
  def randomize_enemies
    apply_tweaks_for_enemy_rando()
    
    overlay_ids_for_common_enemies = OVERLAY_FILE_FOR_ENEMY_AI.select do |enemy_id, overlay_id|
      COMMON_ENEMY_IDS.include?(enemy_id)
    end
    @overlay_ids_for_common_enemies = overlay_ids_for_common_enemies.values.uniq
    
    build_entity_assets_lists()
    
    
    enemy_rando_info_for_each_room, all_randomizable_enemy_locations = build_enemy_rando_info_list()
    total_enemy_locations = all_randomizable_enemy_locations.length
    
    
    locations_done = 0
    all_randomizable_enemy_locations.shuffle!(random: rng)
    all_randomizable_enemy_locations.each do |enemy|
      room = enemy.room
      room_info = enemy_rando_info_for_each_room[room.room_str]
      enemies_in_room = room_info[:enemies_in_room]
      @enemy_pool_for_room = room_info[:enemy_pool_for_room]
      @num_spawners = room_info[:num_spawners]
      @total_resource_intensive_enemies_in_room = room_info[:total_resource_intensive_enemies_in_room]
      @assets_needed_for_room = room_info[:assets_needed_for_room]
      @allowed_enemies_for_room = room_info[:allowed_enemies_for_room]
      @coll = room_info[:coll]
      remaining_new_room_difficulty = room_info[:remaining_new_room_difficulty]
      max_allowed_enemy_attack = room_info[:max_allowed_enemy_attack]
      on_first_enemy_of_room = room_info[:on_first_enemy_of_room]
      
      @allowed_enemies_for_room.select! do |enemy_id|
        enemy_dna = game.enemy_dnas[enemy_id]
        if enemy_dna["Attack"] <= @weak_enemy_attack_threshold
          # Always allow weak enemies in the room.
          true
        elsif enemy_dna["Attack"] <= remaining_new_room_difficulty && enemy_dna["Attack"] <= max_allowed_enemy_attack
          true
        else
          false
        end
      end
      
      # Remove enemies that would go over the asset cap.
      asset_slots_left = MAX_ASSETS_PER_ROOM - @assets_needed_for_room.size
      @allowed_enemies_for_room.select! do |enemy_id|
        needed_assets_for_enemy = @assets_for_each_enemy[enemy_id].size
        needed_assets_for_enemy <= asset_slots_left
      end
      
      if @num_spawners >= @max_spawners_per_room
        @allowed_enemies_for_room -= SPAWNER_ENEMY_IDS
        @enemy_pool_for_room -= SPAWNER_ENEMY_IDS
      end
      
      if on_first_enemy_of_room && enemies_in_room.length > 1
        # We don't want the first enemy we place to be one that there can only be a limited number in a given room.
        # This is because if this one enemy goes over the asset limit for the room, then we wouldn't have any enemies left to place: the same one we already placed would go over the limit per room, while any new one would go over the asset limit.
        # If the total number of enemies in the room is 1 it doesn't matter.
        limitable_enemy_ids = @resource_intensive_enemy_ids + SPAWNER_ENEMY_IDS
        temporarily_removed_enemies = @allowed_enemies_for_room & limitable_enemy_ids
        @allowed_enemies_for_room -= temporarily_removed_enemies
      end
      
      randomize_enemy(enemy)
      
      if temporarily_removed_enemies
        # Add back the limitable enemies now.
        @allowed_enemies_for_room += temporarily_removed_enemies
      end
      
      if SPAWNER_ENEMY_IDS.include?(enemy.subtype)
        @num_spawners += 1
      end
      
      enemy_dna = game.enemy_dnas[enemy.subtype]
      remaining_new_room_difficulty -= enemy_dna["Attack"]
      
      assets = @assets_for_each_enemy[enemy.subtype]
      @assets_needed_for_room += assets
      @assets_needed_for_room.uniq!
      
      if @total_resource_intensive_enemies_in_room >= 2
        # We don't want too many skeletally animated enemies on screen at once, as it takes up too much processing power.
        
        @allowed_enemies_for_room -= @resource_intensive_enemy_ids
        @enemy_pool_for_room -= @resource_intensive_enemy_ids
      end
      
      
      room_info[:enemy_pool_for_room] = @enemy_pool_for_room
      room_info[:num_spawners] = @num_spawners
      room_info[:total_resource_intensive_enemies_in_room] = @total_resource_intensive_enemies_in_room
      room_info[:assets_needed_for_room] = @assets_needed_for_room
      room_info[:allowed_enemies_for_room] = @allowed_enemies_for_room
      room_info[:remaining_new_room_difficulty] = remaining_new_room_difficulty
      room_info[:on_first_enemy_of_room] = false
      
      
      locations_done += 1
      percent_done = locations_done.to_f / total_enemy_locations
      yield percent_done
    end
    
    # Delete room-specific instance variables as they are no longer needed.
    @enemy_pool_for_room = nil
    @num_spawners = nil
    @total_resource_intensive_enemies_in_room = nil
    @assets_needed_for_room = nil
    @allowed_enemies_for_room = nil
    @coll = nil
  end
  
  def build_entity_assets_lists
    if COMMON_SPRITE[:gfx_files]
      common_sprite_gfx_files = COMMON_SPRITE[:gfx_files]
    elsif COMMON_SPRITE[:gfx_wrapper]
      common_sprite_gfx_files = SpriteInfo.unpack_gfx_pointer_list(COMMON_SPRITE[:gfx_wrapper], game.fs)
    else
      raise "Could not parse common sprite constant"
    end
    
    @assets_for_each_enemy = {}
    @skeletally_animated_enemy_ids = []
    ENEMY_IDS.each do |enemy_id|
      if REUSED_ENEMY_INFO[enemy_id] && REUSED_ENEMY_INFO[enemy_id][:init_code] == -1
        @assets_for_each_enemy[enemy_id] = []
        @skeletally_animated_enemy_ids << enemy_id # Probably a 3D enemy, so count it anyway
        next
      end
      
      begin
        enemy_dna = game.enemy_dnas[enemy_id]
        sprite_info = enemy_dna.extract_gfx_and_palette_and_sprite_from_init_ai
        @assets_for_each_enemy[enemy_id] = sprite_info.gfx_file_pointers
        if sprite_info.skeleton_file
          @assets_for_each_enemy[enemy_id] << sprite_info.skeleton_file
          @skeletally_animated_enemy_ids << enemy_id
        elsif OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
          @skeletally_animated_enemy_ids << enemy_id
        end
        if enemy_dna.name == "Necromancer"
          # Also add Zombie's assets since he summons zombies.
          @assets_for_each_enemy[enemy_id] += @assets_for_each_enemy[1]
        end
      rescue StandardError => e
        puts "Error getting sprite info for enemy id %02X" % enemy_id
        @assets_for_each_enemy[enemy_id] = []
        @skeletally_animated_enemy_ids << enemy_id # Probably a 3D enemy, so count it anyway
      end
    end
    @resource_intensive_enemy_ids = @skeletally_animated_enemy_ids.dup
    @resource_intensive_enemy_ids += ENEMY_IDS.select do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      RESOURCE_INTENSIVE_ENEMY_NAMES.include?(enemy_dna.name)
    end
    
    @assets_for_each_special_object = {}
    SPECIAL_OBJECT_IDS.each do |special_object_id|
      if REUSED_SPECIAL_OBJECT_INFO[special_object_id] && REUSED_SPECIAL_OBJECT_INFO[special_object_id][:init_code] == -1
        @assets_for_each_special_object[special_object_id] = []
        next
      end
      
      begin
        special_object = game.special_objects[special_object_id]
        sprite_info = special_object.extract_gfx_and_palette_and_sprite_from_create_code
        if sprite_info.gfx_file_pointers == common_sprite_gfx_files
          # Don't count the common sprite.
          @assets_for_each_special_object[special_object_id] = []
        elsif special_object_id == AREA_NAME_SUBTYPE
          # Only count one gfx file for area names since the game only loads one.
          @assets_for_each_special_object[special_object_id] = [sprite_info.gfx_file_pointers.first]
        else
          @assets_for_each_special_object[special_object_id] = sprite_info.gfx_file_pointers
        end
      rescue StandardError => e
        puts "Error getting sprite info for object id %02X: #{e.message}" % special_object_id
        @assets_for_each_special_object[special_object_id] = []
      end
    end
    
    if GAME == "dos"
      # Add the searchlight's assets to Mothman's assets since it will be placed alongside him.
      @assets_for_each_enemy[0x50] += @assets_for_each_special_object[0x4B]
    end
  end
  
  def build_enemy_rando_info_list
    enemy_rando_info_for_each_room = {}
    all_randomizable_enemy_locations = []
    game.each_room do |room|
      enemies_in_room = get_common_enemies_in_room(room)
      next if enemies_in_room.empty?
      
      all_randomizable_enemy_locations += enemies_in_room
      
      allowed_enemies_for_room = build_initial_allowed_enemy_list_for_room(room)
      
      assets_needed_for_room = build_base_list_of_assets_for_room(room)
      
      collision_checker_for_room = RoomCollision.new(room, game.fs)
      
      remaining_new_room_difficulty, max_allowed_enemy_attack = calculate_allowed_difficulty_and_max_attack_for_room(room)
      
      enemy_rando_info_for_each_room[room.room_str] = {
        enemies_in_room: enemies_in_room,
        enemy_pool_for_room: [],
        num_spawners: 0,
        total_resource_intensive_enemies_in_room: 0,
        assets_needed_for_room: assets_needed_for_room,
        allowed_enemies_for_room: allowed_enemies_for_room,
        coll: collision_checker_for_room,
        remaining_new_room_difficulty: remaining_new_room_difficulty,
        max_allowed_enemy_attack: max_allowed_enemy_attack,
        on_first_enemy_of_room: true,
      }
    end
    
    return [enemy_rando_info_for_each_room, all_randomizable_enemy_locations]
  end
  
  def build_initial_allowed_enemy_list_for_room(room)
    # Initialize the list of which enemies can be in this room.
    enemy_overlay_id_for_room = @overlay_ids_for_common_enemies.sample(random: rng)
    allowed_enemies_for_room = COMMON_ENEMY_IDS.select do |enemy_id|
      overlay = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
      overlay.nil? || overlay == enemy_overlay_id_for_room
    end
    if GAME == "ooe"
      allowed_enemies_for_room << 0x6B # Count Giant Skeleton as a common enemy
    end
    enemies_in_room = get_common_enemies_in_room(room)
    if enemies_in_room.length >= 6
      # Don't let cpu intensive enemies in rooms that have lots of enemies.
      
      allowed_enemies_for_room -= @resource_intensive_enemy_ids
    end
    # Don't allow spawners in Nest of Evil/Large Cavern.
    if (GAME == "por" && room.area_index == 9) || (GAME == "ooe" && room.area_index == 0xC)
      allowed_enemies_for_room -= SPAWNER_ENEMY_IDS
    end
    # Don't allow spawners in the train room.
    if GAME == "por" && room.area_index == 2 && room.sector_index == 0 && room.room_index == 1
      allowed_enemies_for_room -= SPAWNER_ENEMY_IDS
    end
    # Don't allow Red Skeletons and Red Axe Armors in Nest of Evil since they can't be killed without certain weapons.
    if GAME == "por" && room.area_index == 9
      allowed_enemies_for_room -= [0x1C, 0x46]
    end
    # Don't allow Blood Skeletons in Large Cavern since they can't be killed.
    if GAME == "ooe" && room.area_index == 0xC
      allowed_enemies_for_room -= [0x4B]
    end
    # Don't allow Mimics in Large Cavern since they can't be opened there, for some unknown reason.
    if GAME == "ooe" && room.area_index == 0xC
      allowed_enemies_for_room -= [0x4D]
    end
    
    return allowed_enemies_for_room
  end
  
  def build_base_list_of_assets_for_room(room)
    # Builds a list of assets that always need to be loaded for this room regardless of what the enemies are randomized into.
    
    assets_needed_for_room = []
    
    objects_in_room = room.entities.select{|e| e.is_special_object?}
    objects_in_room.each do |object|
      assets = @assets_for_each_special_object[object.subtype]
      #puts "OBJ: %02X, ASSETS: #{assets}" % object.subtype
      assets_needed_for_room += assets
      assets_needed_for_room.uniq!
    end
    
    return assets_needed_for_room
  end
  
  def calculate_allowed_difficulty_and_max_attack_for_room(room)
    enemies_in_room = get_common_enemies_in_room(room)
    
    if room_rando? && options[:rebalance_enemies_in_room_rando] && @room_rando_enemy_difficulty_for_room[room.room_str]
      hash = @room_rando_enemy_difficulty_for_room[room.room_str]
      
      original_room_difficulty = hash[:average_attack] * enemies_in_room.size
      max_enemy_attack = hash[:max_enemy_attack]
    else
      # Calculate how difficult a room originally was by the sum of the Attack value of all enemies in the room.
      original_room_difficulty = enemies_in_room.reduce(0) do |difficulty, enemy|
        enemy_dna = @original_enemy_dnas[enemy.subtype]
        difficulty + enemy_dna["Attack"]
      end
    
      max_enemy_attack = enemies_in_room.map do |enemy|
        enemy_dna = @original_enemy_dnas[enemy.subtype]
        enemy_dna["Attack"]
      end.max
    end
    
    # Only allow tough enemies in the room up to the original room's difficulty times a multiplier.
    remaining_new_room_difficulty = original_room_difficulty*@difficulty_settings[:max_room_difficulty_mult]
    
    # Only allow enemies up to a certain multiplier higher than the strongest enemy in the original room.
    max_allowed_enemy_attack = max_enemy_attack*@difficulty_settings[:max_enemy_difficulty_mult]
    
    return [remaining_new_room_difficulty, max_allowed_enemy_attack]
  end
  
  def get_common_enemies_in_room(room)
    enemies_in_room = room.entities.select{|e| e.is_common_enemy?}
    
    if GAME == "por"
      enemies_in_room += room.entities.select do |e|
         e.is_enemy? && e.subtype == 0x94 && e.var_a == 0 # Count The Creature as a common enemy
      end
    end
    if GAME == "ooe"
      enemies_in_room += room.entities.select do |e|
         e.is_enemy? && e.subtype == 0x6B && e.var_a == 0 # Count Giant Skeleton as a common enemy
      end
    end
    
    return enemies_in_room
  end
  
  def randomize_enemy(enemy, failed_enemies_for_this_spot = [])
    if GAME == "dos" && enemy.room.sector_index == 4 && enemy.room.room_index == 0x10 && enemy.subtype == 0x3A
      # That one Malachi needed for Dmitrii's event. Don't do anything to it or the event gets messed up.
      return
    end
    if GAME == "ooe" && enemy.room.area_index == 0 && enemy.room.sector_index == 0xC
      # Those two gargoyles outside of the castle. These aren't supposed to be enemies, just decorations, so don't randomize them.
      return
    end
    
    if @assets_needed_for_room.size >= MAX_ASSETS_PER_ROOM
      # There's a limit to how many different GFX files can be loaded at once before things start getting very buggy.
      # Once there's too many, just select from enemies already in the room.
      
      enemy_pool_for_room_minus_failed = @enemy_pool_for_room - failed_enemies_for_this_spot
      
      if enemy_pool_for_room_minus_failed.any?
        random_enemy_id = enemy_pool_for_room_minus_failed.sample(random: rng)
      else
        # Placing any more enemies would go over the asset limit, but none of the existing ones work in this spot.
        # Just delete this enemy.
        enemy.type = 0
        enemy.write_to_rom()
        return
      end
    else
      # Enemies are chosen weighted closer to the ID of what the original enemy was so that early game enemies are less likely to roll into endgame enemies.
      # Method taken from: https://gist.github.com/O-I/3e0654509dd8057b539a
      max_enemy_id = ENEMY_IDS.max
      allowed_enemies_for_room_minus_failed = @allowed_enemies_for_room - failed_enemies_for_this_spot
      weights = allowed_enemies_for_room_minus_failed.map do |possible_enemy_id|
        curr_enemy_id_for_id_weighting = get_enemy_id_for_weighting_purposes(enemy)
        id_difference = (possible_enemy_id - curr_enemy_id_for_id_weighting).abs
        weight = max_enemy_id - id_difference
        weight**@difficulty_settings[:enemy_id_preservation_exponent]
      end
      ps = weights.map{|w| w.to_f / weights.reduce(:+)}
      weighted_enemy_ids = allowed_enemies_for_room_minus_failed.zip(ps).to_h
      random_enemy_id = weighted_enemy_ids.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
    end
    
    fix_enemy_position(enemy)
    
    enemy_dna = game.enemy_dnas[random_enemy_id]
    
    enemy.var_a = 0
    enemy.var_b = 0
    result = case GAME
    when "dos"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "por"
      por_adjust_randomized_enemy(enemy, enemy_dna)
    when "ooe"
      ooe_adjust_randomized_enemy(enemy, enemy_dna)
    end
    
    # We fix the enemy position twice in case the enemy-specific adjustment moved it down onto a door or something.
    fix_enemy_position(enemy)
    
    if result == :redo
      failed_enemies_for_this_spot << random_enemy_id
      randomize_enemy(enemy, failed_enemies_for_this_spot)
    else
      enemy.subtype = random_enemy_id
      enemy.write_to_rom()
      @enemy_pool_for_room << random_enemy_id
      @enemy_pool_for_room.uniq!
      
      if @resource_intensive_enemy_ids.include?(random_enemy_id)
        @total_resource_intensive_enemies_in_room += 1
      end
    end
  end
  
  def get_enemy_id_for_weighting_purposes(enemy)
    if room_rando? && options[:rebalance_enemies_in_room_rando] && @room_rando_enemy_difficulty_for_room[enemy.room.room_str]
      hash = @room_rando_enemy_difficulty_for_room[enemy.room.room_str]
      hash[:average_enemy_id]
    else
      enemy.subtype
    end
  end
  
  def fix_enemy_position(enemy)
    room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
    room_height = enemy.room.height*SCREEN_HEIGHT_IN_PIXELS
    
    if enemy.x_pos <= 0
      #puts "X IS ZERO: %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
      buffer_width_from_room_edge = SCREEN_WIDTH_IN_PIXELS/2
      enemy.x_pos = rng.rand(buffer_width_from_room_edge..room_width-buffer_width_from_room_edge)
    end
    if enemy.y_pos <= 0
      #puts "Y IS ZERO: %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
      buffer_height_from_room_edge = SCREEN_HEIGHT_IN_PIXELS/2
      enemy.y_pos = rng.rand(buffer_height_from_room_edge..room_height-buffer_height_from_room_edge)
    end
    
    enemy.x_pos = [enemy.x_pos, 0x10].max
    enemy.y_pos = [enemy.y_pos, 0x10].max
    
    enemy.x_pos = [enemy.x_pos, room_width-0x10].min
    enemy.y_pos = [enemy.y_pos, room_height-0x10].min
    
    if enemy.x_pos < 0x40
      close_to_left_door = enemy.room.doors.find{|door| door.direction == :left && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
      if close_to_left_door
        #puts "CLOSE LEFT %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.x_pos = 0x40
      end
    elsif enemy.x_pos > room_width - 0x40
      close_to_right_door = enemy.room.doors.find{|door| door.direction == :right && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
      if close_to_right_door
        #puts "CLOSE RIGHT %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.x_pos = room_width - 0x40
      end
    end
    if enemy.y_pos < 0x60
      close_to_up_door = enemy.room.doors.find{|door| door.direction == :up && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
      if close_to_up_door
        #puts "CLOSE UP %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.y_pos = 0x60
      end
    end
    if enemy.y_pos > room_height - 0x80
      close_to_down_door = enemy.room.doors.find{|door| door.direction == :down && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
      if close_to_down_door
        #puts "CLOSE DOWN %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.y_pos = room_height - 0x80
      end
    end
    
    # We either want the enemy to have a solid floor below it, or to have a jumpthrough floor which is not right at the bottom of the room.
    # No floor at all would cause some enemies to crash the game, and others to be inside the door.
    # A jumpthrough platform right at the bottom of the room would be on top of a door, and we don't want enemies on that since it would block the player.
    solid_y = coll.get_floor_y(enemy, allow_jumpthrough: false)
    jumpthrough_y = coll.get_floor_y(enemy, allow_jumpthrough: true)
    if jumpthrough_y.nil? || (solid_y.nil? && jumpthrough_y >= room_height - 0x20)
      #puts "NO FLOOR! %02X-%02X-%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index]
      
      # Try to move it 4 blocks left or right, that should fix it most of the time.
      enemy.x_pos += 0x40
      
      solid_y = coll.get_floor_y(enemy, allow_jumpthrough: false)
      jumpthrough_y = coll.get_floor_y(enemy, allow_jumpthrough: true)
      if jumpthrough_y.nil? || (solid_y.nil? && jumpthrough_y >= room_height - 0x20)
        enemy.x_pos -= 0x80 # Try 4 blocks to the left of its original position
        
        solid_y = coll.get_floor_y(enemy, allow_jumpthrough: false)
        jumpthrough_y = coll.get_floor_y(enemy, allow_jumpthrough: true)
        if jumpthrough_y.nil? || (solid_y.nil? && jumpthrough_y >= room_height - 0x20)
          # If moving it left or right didn't fix it, select a random floor position in the room.
          # This code should never be run, it's not necessary for any known positions. It's just a failsafe.
          random_floor_pos = coll.all_floor_positions.sample(random: rng)
          enemy.x_pos, enemy.y_pos = random_floor_pos
        end
      end
    end
  end
  
  def get_valid_wall_directions(enemy)
    # We don't want Spittle Bone/Slime/etc to try to teleport to a wall that doesn't exist.
    # So we remove directions that have a door in that direction directly in line with the enemy.
    
    possible_directions = [0, 1, 2, 3]
    
    left_door = enemy.room.doors.find{|door| door.direction == :left && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
    possible_directions -= [2] if left_door
    right_door = enemy.room.doors.find{|door| door.direction == :right && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
    possible_directions -= [3] if right_door
    up_door = enemy.room.doors.find{|door| door.direction == :up && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
    possible_directions -= [1] if up_door
    down_door = enemy.room.doors.find{|door| door.direction == :down && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
    possible_directions -= [0] if down_door
    
    if GAME == "por" || GAME == "ooe"
      # In PoR and OoE there are outside rooms with no ceiling.
      # I don't know how to detect these, so just never allow them to go to the ceiling in these games.
      possible_directions -= [1]
    end
    
    return possible_directions
  end
  
  def dos_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Zombie", "Ghoul"
      # 50% chance to be a single zombie, 50% chance to be a spawner.
      if rng.rand <= 0.5
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(2..9)
      end
    when "Bat"
      # 50% chance to be a single bat, 50% chance to be a spawner.
      if rng.rand <= 0.5
        enemy.var_a = 0
        enemy.var_b = 0 # Teleport to the closest ceiling.
      else
        enemy.var_a = 0x100
      end
    when "Skull Archer"
      enemy.var_a = rng.rand(0..8) # Arrow speed.
    when "Slime", "Tanjelly"
      possible_directions = get_valid_wall_directions(enemy)
      
      if possible_directions.empty?
        return :redo
      end
      
      enemy.var_a = possible_directions.sample(random: rng)
    when "Mollusca", "Giant Slug"
      # Mollusca and Giant Slug bug out when placed on top of cliffs or inside walls.
      # They can cause the screen to flash rapidly and take up most of the screen.
      # They can also cause the game to freeze for a couple seconds every time you enter a room with them in it.
      # So we follow the floor to the left and right of them to find the closest cliff or wall.
      # If it's too close in either direction, we ban them from being placed here.
      
      y = coll.get_floor_y(enemy, allow_jumpthrough: true)
      if y.nil?
        # No floor
        return :redo
      end
      enemy.y_pos = y
      
      y = coll.push_up_out_of_floor(enemy)
      if y.nil?
        # Floor extends up infinitely
        return :redo
      end
      enemy.y_pos = y
      
      right_type, right_x, right_y = coll.follow_floor_right(enemy.x_pos, enemy.y_pos)
      left_type, left_x, left_y = coll.follow_floor_left(enemy.x_pos, enemy.y_pos)
      
      if right_type == :unknown || left_type == :unknown
        return :redo
      end
      
      distance_left = enemy.x_pos - left_x
      distance_right = right_x - enemy.x_pos
      if distance_left < 0x60 || distance_right < 0x60
        return :redo
      end
    when "Ghost Dancer"
      enemy.var_a = rng.rand(0..2) # Palette
    when "Killer Doll"
      enemy.var_b = rng.rand(0..1) # Direction
    when "Fleaman"
      enemy.var_a = rng.rand(1..5) # Number of flea men
    when "Bone Pillar", "Fish Head"
      enemy.var_a = rng.rand(1..8)
      
      # Move down to the nearest floor
      y = coll.get_floor_y(enemy, allow_jumpthrough: true)
      if y.nil?
        # No floor
        return :redo
      end
      enemy.y_pos = y
      
      room_has_left_doors = !!enemy.room.doors.find{|door| door.direction == :left}
      room_has_right_doors = !!enemy.room.doors.find{|door| door.direction == :right}
      if room_has_left_doors
        enemy.x_pos = [enemy.x_pos, 0x20].max
      end
      if room_has_right_doors
        room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
        enemy.x_pos = [enemy.x_pos, room_width-0x20].min
      end
    when "Malachi"
      enemy.var_a = 0
    when "Medusa Head"
      enemy.var_a = rng.rand(1..7) # Max at once
      enemy.var_b = rng.rand(0..1) # Type of Medusa Head
    when "Mud Demon"
      enemy.var_b = rng.rand(0..0x50) # Max rand spawn distance
    when "Stolas"
      if (@enemy_pool_for_room-STOLAS_UNFRIENDLY_ENEMY_IDS).any?
        enemy_id_a = (@enemy_pool_for_room-STOLAS_UNFRIENDLY_ENEMY_IDS).sample(random: rng)
        enemy_id_b = (@enemy_pool_for_room-STOLAS_UNFRIENDLY_ENEMY_IDS).sample(random: rng)
      elsif (@allowed_enemies_for_room-@resource_intensive_enemy_ids-STOLAS_UNFRIENDLY_ENEMY_IDS).any?
        enemy_id_a = (@allowed_enemies_for_room-@resource_intensive_enemy_ids-STOLAS_UNFRIENDLY_ENEMY_IDS).sample(random: rng)
        enemy_id_b = (@allowed_enemies_for_room-@resource_intensive_enemy_ids-STOLAS_UNFRIENDLY_ENEMY_IDS).sample(random: rng)
        
        @enemy_pool_for_room << enemy_id_a
        @enemy_pool_for_room << enemy_id_b
        @enemy_pool_for_room.uniq!
      else
        return :redo
      end
      
      chance_a = rng.rand(0x10..0xF0)
      chance_b = rng.rand(0x10..0xF0)
      enemy.var_a = (chance_a << 8) | enemy_id_a
      enemy.var_b = (chance_b << 8) | enemy_id_b
    when "White Dragon"
      right_x = coll.get_right_wall_x(enemy)
      left_x = coll.get_left_wall_x(enemy)
      if right_x && left_x
        if rng.rand <= 0.50
          enemy.x_pos = right_x
          enemy.var_a = 1
        else
          enemy.x_pos = left_x
          enemy.var_a = 0
        end
      elsif right_x
        enemy.x_pos = right_x
        enemy.var_a = 1
      elsif left_x
        enemy.x_pos = left_x
        enemy.var_a = 0
      else
        # No walls to the left or right, don't place this enemy here.
        return :redo
      end
    when "Flying Humanoid"
      # Don't let Flying Humanoid in large rooms. His hitbox is only on the upper left screen, and we don't want them to be disjointed.
      if enemy.room.width > 1 || enemy.room.height > 1
        return :redo
      end
      
      # Dont let Flying Humanoid in rooms with other enemies. His huge hitbox blocks bullets from the guns, making it so you can't hit other enemies.
      num_enemies_in_room = enemy.room.entities.select{|e| e.is_enemy?}.length
      if num_enemies_in_room > 1
        return :redo
      end
    when "Homunculus"
      if enemy.room.width > 3 || enemy.room.height > 3
        # Homunculus freaks out in large rooms.
        return :redo
      end
    when "Mothman"
      # Mothman needs a searchlight in his room for him to appear.
      room = enemy.room
      searchlight = Entity.new(room, room.fs)
      
      searchlight.x_pos = enemy.x_pos
      searchlight.y_pos = enemy.y_pos
      searchlight.type = 2
      searchlight.subtype = 0x4B
      
      room.entities << searchlight
      room.write_entities_to_rom()
    end
  end
  
  def por_adjust_randomized_enemy(enemy, enemy_dna)
    case enemy_dna.name
    when "Zombie", "Bat", "Fleaman", "Medusa Head", "Slime", "Tanjelly", "Bone Pillar", "Fish Head", "White Dragon"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "Hanged Bones", "Skeleton Tree"
      # Try to limit possible buggy positions where it will be near a door and not let you enter the room.
      if enemy.room.width <= 1
        return :redo
      end
      if enemy.x_pos < 0x80
        enemy.x_pos = 0x80
      end
      room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
      if enemy.x_pos > room_width - 0x80
        enemy.x_pos = room_width - 0x80
      end
      
      if enemy.room.entities.find{|e| e.is_special_object? && [0x34, 0x35].include?(e.subtype)}
        # There are cogs in this room.
        # Cogs don't let you stand on them if they're in the same room as a hanged bones/skeleton tree.
        return :redo
      end
      
      enemy.var_a = rng.rand(0..0x40) # Length
      enemy.var_b = 0
      enemy.y_pos = 0x20
    when "Spittle Bone", "Vice Beetle"
      # TODO: move out of floor
      
      possible_directions = get_valid_wall_directions(enemy)
      
      if possible_directions.empty?
        return :redo
      end
      
      enemy.var_a = possible_directions.sample(random: rng)
      
      enemy.var_b = rng.rand(0x600..0x1800) # speed
    when "Razor Bat"
      # 70% chance to be a single Razor Bat, 30% chance to be a spawner.
      if rng.rand <= 0.7
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(0xA0..0x1A0) # delay in frames between spawns
      end
    when "Sand Worm", "Poison Worm"
      close_to_down_door = enemy.room.doors.find{|door| door.direction == :down && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
      if close_to_down_door
        # Don't allow above a down door.
        return :redo
      end
      
      enemy.var_a = 1
    when "Mud Man", "Mummy"
      real_layers = enemy.room.layers.reject{|layer| layer.layer_tiledata_ram_start_offset.nil?}
      if enemy_dna.name == "Mud Man" && real_layers.length == 1
        # If mud men are placed in a room with only 1 layer (e.g. some rooms in Dark Academy with a 3D background) they will crash the game on real hardware.
        return :redo
      end
      
      # 10% chance to be a single one, 90% chance to be a spawner.
      if rng.rand <= 0.10
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(2..6) # Max at once
        
        room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
        enemy.var_b = rng.rand(100..room_width) # Max horizontal distance in pixels from the spawner to spawn them
      end
    when "Skeleton Gunman"
      if enemy.room.width > 3
        # Skeleton Gunmen can shoot from offscreen, which can be unfair in wide rooms, and make the game impossible if they're in the train room.
        return :redo
      end
      
      # Move to floor first so we know where he actually will be in game.
      y = coll.get_floor_y(enemy, allow_jumpthrough: false)
      if y.nil?
        # No floor
        return :redo
      end
      enemy.y_pos = y - 0x10
      
      room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
      right_wall_x = coll.get_right_wall_x(enemy)
      left_wall_x = coll.get_left_wall_x(enemy)
      if right_wall_x.nil? || left_wall_x.nil?
        # Would have line of sight to a door, meaning they could shoot the player as soon as they walk in.
        return :redo
      end
      
      # Calculate the maximum distance these gunmen should be allowed to walk without going inside a wall.
      # Subtract a block since we don't want the gunman to be half inside the wall either.
      max_left_dist = enemy.x_pos - left_wall_x - 0x10
      max_right_dist = right_wall_x - enemy.x_pos - 0x10
      
      room_has_left_doors = !!enemy.room.doors.find{|door| door.direction == :left}
      room_has_right_doors = !!enemy.room.doors.find{|door| door.direction == :right}
      if room_has_left_doors && !room_has_right_doors
        dir = 0
      elsif room_has_right_doors && !room_has_left_doors
        dir = 1
      else
        dir = rng.rand(-1..1)
      end
      
      case dir
      when 0 # Faces left
        enemy.var_a = 0
        max_dist = max_right_dist
      when 1 # Faces right
        enemy.var_a = 0x0100
        max_dist = max_left_dist
      else # Faces the player when they enter the room
        enemy.var_a = 0xFFFF
        max_dist = [max_left_dist, max_right_dist].min
      end
      
      min_dist = 0x20
      min_dist = max_dist if min_dist > max_dist
      
      dist = rng.rand(min_dist..max_dist)
      enemy.var_b = dist
    when "Blue Crow", "Black Crow"
      enemy.var_a = 1 # Teleport to the closest floor.
    when "Killer Bee", "Bee Hive"
      if enemy.room.width > 4
        # Bee AI seems buggy and can teleport them around in very wide rooms.
        return :redo
      end
    when "Larva"
      enemy.var_b = rng.rand(0..0xF) # Bitfield of which of the 4 directions the larva can move in
    when "Persephone"
      enemy.var_a = rng.rand(0..2) # How she behaves (normal, vacuum, already in the middle of vacuuming)
    when "Skeleton Flail"
      room_has_left_doors = !!enemy.room.doors.find{|door| door.direction == :left}
      room_has_right_doors = !!enemy.room.doors.find{|door| door.direction == :right}
      if room_has_left_doors && !room_has_right_doors
        enemy.var_a = 1
      elsif room_has_right_doors && !room_has_left_doors
        enemy.var_a = 2
      else
        enemy.var_a = 0
      end
      
      # TODO: var B is num steps to take. try to detect collision and prevent him from walking off edges or walking into walls.
      enemy.var_b = rng.rand(0..6)
    when "Yorick"
      room_has_up_doors = !!enemy.room.doors.find{|door| door.direction == :up}
      room_has_upwards_gravity = !!enemy.room.entities.find{|e| e.is_special_object? && e.subtype == 3 && e.var_a == 0xC000}
      if room_has_up_doors && room_has_upwards_gravity
        # In rooms with upside down gravity and an updoor, Yorick's skull can fall infinitely upwards out of bounds, which lags the game.
        # The lag doesn't occur when falling infinitely downwards out of bounds for some reason.
        puts enemy.room.room_str
        return :redo
      end
    end
  end
  
  def ooe_adjust_randomized_enemy(enemy, enemy_dna)
    if enemy_dna["Glyph"] != 0
      glyphs_in_room = enemy.room.entities.select{|e| e.is_glyph? || e.is_glyph_statue? || e.is_villager?}
      if glyphs_in_room.length >= 2
        # If the room already has 2+ glyphs in it, don't put any enemies that create glyphs in the room too.
        # (Applies to both enemies that drop glyphs when they die, as well as ones that use glyphs while they're alive.)
        return :redo
      end
    end
    
    case enemy_dna.name
    when "Bat", "Medusa Head", "Bone Pillar", "Fish Head", "White Dragon"
      dos_adjust_randomized_enemy(enemy, enemy_dna)
    when "Black Crow"
      por_adjust_randomized_enemy(enemy, enemy_dna)
    when "Zombie", "Ghoul"
      if rng.rand <= 0.30 # 30% chance to be a single Zombie
        enemy.var_a = 0
        enemy.var_b = 0
      else # 70% chance to be a spawner
        enemy.var_a = rng.rand(3..6) # Max at once
        
        room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
        enemy.var_b = rng.rand(100..room_width) # Max horizontal distance in pixels from the spawner to spawn the Zombies
      end
    when "Sea Stinger"
      if rng.rand <= 0.10 # 10% chance to be a single Sea Stinger
        enemy.var_a = 0
        enemy.var_b = 0
      else # 90% chance to be a spawner
        enemy.var_a = rng.rand(2..6) # Max at once
      end
    when "Skeleton"
      enemy.var_a = rng.rand(0..1) # Can jump away.
    when "Bone Archer"
      enemy.var_a = rng.rand(0..8) # Arrow speed.
    when "Axe Knight"
      # 80% chance to be normal, 20% chance to start out in pieces.
      if rng.rand() <= 0.80
        enemy.var_b = 0
      else
        enemy.var_b = 1
      end
    when "Flea Man"
      enemy.var_b = 0
    when "Ghost"
      enemy.var_a = rng.rand(1..4) # Max ghosts on screen at once.
    when "Skull Spider"
      # Move out of the floor TODO this doesn't work
      enemy.y_pos -= 0x08
      
      enemy.var_a = rng.rand(0x600..0x1800) # speed
    when "Skeleton Frisky"
      y = coll.get_floor_y(enemy, allow_jumpthrough: true)
      if y.nil?
        # No floor, Frisky will crash the game
        return :redo
      end
      enemy.y_pos = y
    when "Gelso"
      if rng.rand <= 0.40 # 40% chance to be a single Gelso
        enemy.var_a = 0
        enemy.var_b = 0
      else # 60% chance to be a spawner
        enemy.var_a = rng.rand(1..6) # Max at once
        enemy.var_b = rng.rand(180..480) # Frames in between spawning them
      end
    when "Merman"
      # Move out of the floor
      enemy.y_pos -= 0x10
    when "Saint Elmo"
      enemy.var_a = rng.rand(1..3)
      enemy.var_b = 0x78
    when "Winged Guard"
      enemy.var_a = rng.rand(1..5) # Max at once
    when "Winged Skeleton"
      enemy.var_a = rng.rand(40..80) # Minimum delay between spawns
      enemy.var_b = rng.rand(40..80) # Random range to add to delay between spawns
    when "Altair"
      if rng.rand <= 0.40 # 40% chance to carry fleamen
        enemy.var_a = 0
      else # 60% chance to attack by swooping down
        enemy.var_a = 1
      end
      enemy.var_b = rng.rand(240..720) # Spawn rate is somewhere from every 2 seconds to one every 6 seconds.
    when "Gorgon Head"
      enemy.var_a = rng.rand(300..700) # Minimum delay between spawns
      enemy.var_b = rng.rand(120..700) # Random range to add to delay between spawns
    when "Nightmare"
      if enemy.room.width <= 1
        # Don't let Nightmare appear in 1-screen wide rooms as he will just fade in and out constantly if he doesn't have a wide area.
        return :redo
      end
    when "Tin Man"
      y = coll.get_nonsolid_y_upwards(enemy)
      if y.nil?
        # No gap at or above the Tin Man. He would be stuck inside the wall, which crashes the game.
        return :redo
      end
      
      # If Tin Man is placed on a 1-tile-wide jump-through-platform he will crash the game because his AI isn't sure where to put him.
      # So move him downwards to the nearest *solid* floor to prevent this.
      y = coll.get_floor_y(enemy, allow_jumpthrough: false)
      if y.nil?
        # No floor
        return :redo
      end
      enemy.y_pos = y
      
      # If var A is nonzero, Tin Man will be able to fall off ledges - but long falls will crash the game, so disable this.
      enemy.var_a = 0
    when "Mimic"
      # If a Mimic isn't on the floor it's impossible for the player to open it, and therefore impossible to kill.
      
      y = coll.get_floor_y(enemy, allow_jumpthrough: false)
      if y.nil?
        # No floor
        return :redo
      end
      enemy.y_pos = y
    when "Giant Skeleton"
      enemy.var_a = 0 # Common enemy Giant Skeleton.
      enemy.var_b = 0 # Faces the player when they enter the room.
    end
  end
  
  def apply_tweaks_for_enemy_rando
    if GAME == "dos"
      # Remove a bunch of enemies from those two big rooms with about 25 enemies.
      # Randomizing that many enemies in a single room always causes bugs, so just reduce the number to about 16.
      big_chapel_room = game.room_by_str("00-04-15")
      [0x12, 0x0D, 0x0E, 0x10, 0x16, 0x1A, 0x1D].each do |entity_index|
        entity = big_chapel_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
      
      big_hell_room = game.room_by_str("00-06-17")
      [0x1C, 0x1D, 0x19, 0x18, 0x15, 0x16, 0x0F, 0x1A, 0x17].each do |entity_index|
        entity = big_hell_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    end
  end
end

class RoomCollision
  attr_reader :room,
              :fs,
              :collision_layer,
              :collision_tileset,
              :tiles,
              :room_width,
              :room_height
  
  def initialize(room, fs)
    @room = room
    @fs = fs
    
    room.sector.load_necessary_overlay()
    @collision_layer = room.layers.first
    @collision_tileset = CollisionTileset.new(collision_layer.collision_tileset_pointer, fs)
    
    @tiles = []
    collision_layer.tiles.each do |tile|
      @tiles << collision_tileset.tiles[tile.index_on_tileset]
    end
    
    @room_width = room.width*SCREEN_WIDTH_IN_PIXELS
    @room_height = room.height*SCREEN_HEIGHT_IN_PIXELS
  end
  
  def [](x, y)
    x = x / 0x10
    y = y / 0x10
    room_width_in_tiles = room.width*SCREEN_WIDTH_IN_TILES
    tile_index = x + y*room_width_in_tiles
    collision_tile = tiles[tile_index]
    
    if collision_tile.is_slope?
      layer_tile = collision_layer.tiles[tile_index]
      collision_tile = collision_tile.dup
      collision_tile.horizontal_flip = !collision_tile.horizontal_flip if layer_tile.horizontal_flip
      collision_tile.vertical_flip   = !collision_tile.vertical_flip   if layer_tile.vertical_flip
    end
    
    collision_tile
  end
  
  def get_floor_y(entity, allow_jumpthrough: false)
    start_y = entity.y_pos/0x10*0x10
    x = entity.x_pos
    chosen_y = nil
    (start_y..room_height-1).step(0x10) do |y|
      if self[x,y].is_solid?
        chosen_y = y
        break
      end
      if self[x,y].is_jumpthrough_platform? && allow_jumpthrough
        chosen_y = y
        if self[x,y].is_bottom_half?
          chosen_y += 8
        end
        break
      end
    end
    
    return chosen_y
  end
  
  def push_up_out_of_floor(entity)
    start_y = entity.y_pos/0x10*0x10
    x = entity.x_pos
    chosen_y = nil
    (0..start_y-1).step(0x10).reverse_each do |y|
      if !self[x,y].is_solid? && self[x,y+0x10].is_solid?
        chosen_y = y+0x10
        break
      end
    end
    
    return chosen_y
  end
  
  def get_right_wall_x(entity)
    y = entity.y_pos
    chosen_x = nil
    start_x = entity.x_pos/0x10*0x10
    (start_x..room_width-1).step(0x10) do |x|
      if self[x,y].is_solid?
        chosen_x = x
        break
      end
    end
    
    return chosen_x
  end
  
  def get_left_wall_x(entity)
    y = entity.y_pos
    chosen_x = nil
    start_x = (entity.x_pos-1)/0x10*0x10
    (0..start_x).step(0x10).reverse_each do |x|
      if self[x,y].is_solid?
        chosen_x = x + 0x10 # Add a block because we want the position of the right edge of this tile.
        break
      end
    end
    
    return chosen_x
  end
  
  def get_nonsolid_y_upwards(entity)
    x = entity.x_pos
    chosen_y = nil
    (0..entity.y_pos).step(0x10).reverse_each do |y|
      if !self[x,y].is_solid?
        chosen_y = y
        break
      end
    end
    
    return chosen_y
  end
  
  def all_floor_positions
    @all_floor_positions ||= begin
      all_positions = []
      
      (0x10..room_height-1).step(0x10) do |y|
        (0x10..room_width-0x11).step(0x10) do |x|
          if self[x,y-0x10].is_blank && (self[x,y].is_solid? || self[x,y].is_jumpthrough_platform?)
            all_positions << [x, y-0x10]
          end
        end
      end
      
      all_positions
    end
  end
  
  def follow_floor_right(start_x, start_y)
    start_x = start_x/0x10*0x10
    y = start_y/0x10*0x10
    
    (start_x..room_width-1).step(0x10) do |x|
      if y == 0 || y > room_height-0x10
        return [:unknown, x, y] # Invalid
      end
      
      if self[x,y].is_flat_floor? && self[x,y-0x10].is_blank_or_damage?
        # Do nothing, normal flat floor.
      elsif self[x,y].is_valid_floor_slope_left? && self[x,y-0x10].is_blank_or_damage?
        # Following a slope down.
        y += self[x,y].slope_amount
      elsif self[x,y].is_solid_block? && self[x,y-0x10].is_valid_floor_slope_right?
        # Starting to follow a slope up.
        y -= self[x,y-0x10].slope_amount
      elsif self[x,y].is_valid_floor_slope_right? && self[x,y-0x10].is_blank_or_damage?
        # Continuing to follow a slope up.
        y -= self[x,y].slope_amount
      elsif self[x,y].is_solid_block? && self[x,y-0x10].is_solid_block?
        # Reached a wall.
        return [:wall, x, y]
      elsif self[x,y].is_blank_or_damage? && self[x,y-0x10].is_blank_or_damage?
        # Reached a drop off of a cliff.
        return [:cliff, x, y]
      else
        return [:unknown, x, y]
      end
    end
    
    return [:roomedge, room_width-0x10, y]
  end
  
  def follow_floor_left(start_x, start_y)
    start_x = start_x/0x10*0x10
    y = start_y/0x10*0x10
    
    (0..start_x).step(0x10).reverse_each do |x|
      if y == 0 || y > room_height-0x10
        return [:unknown, x, y] # Invalid
      end
      
      if self[x,y].is_flat_floor? && self[x,y-0x10].is_blank_or_damage?
        # Do nothing, normal flat floor.
      elsif self[x,y].is_valid_floor_slope_right? && self[x,y-0x10].is_blank_or_damage?
        # Following a slope down.
        y += self[x,y].slope_amount
      elsif self[x,y].is_solid_block? && self[x,y-0x10].is_valid_floor_slope_left?
        # Starting to follow a slope up.
        y -= self[x,y-0x10].slope_amount
      elsif self[x,y].is_valid_floor_slope_left? && self[x,y-0x10].is_blank_or_damage?
        # Continuing to follow a slope up.
        y -= self[x,y].slope_amount
      elsif self[x,y].is_solid_block? && self[x,y-0x10].is_solid_block?
        # Reached a wall.
        return [:wall, x, y]
      elsif self[x,y].is_blank_or_damage? && self[x,y-0x10].is_blank_or_damage?
        # Reached a drop off of a cliff.
        return [:cliff, x, y]
      else
        return [:unknown, x, y]
      end
    end
    
    return [:roomedge, 0, y]
  end
end
