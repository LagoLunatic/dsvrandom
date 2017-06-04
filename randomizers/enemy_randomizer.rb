
module EnemyRandomizer
  MAX_ASSETS_PER_ROOM = 12
  
  def randomize_enemies
    overlay_ids_for_common_enemies = OVERLAY_FILE_FOR_ENEMY_AI.select do |enemy_id, overlay_id|
      COMMON_ENEMY_IDS.include?(enemy_id)
    end
    overlay_ids_for_common_enemies = overlay_ids_for_common_enemies.values.uniq
    
    @assets_for_each_enemy = {}
    @skeletally_animated_enemy_ids = []
    ENEMY_IDS.each do |enemy_id|
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
      rescue StandardError => e
        puts "Error getting sprite info for enemy id %02X" % enemy_id
        @assets_for_each_enemy[enemy_id] = []
        @skeletally_animated_enemy_ids << enemy_id # Probably a 3D enemy, so count it anyway
      end
    end
    @cpu_intensive_enemy_ids = @skeletally_animated_enemy_ids.dup
    @cpu_intensive_enemy_ids += ENEMY_IDS.select do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      if ["Forneus", "Spin Devil", "Stolas"].include?(enemy_dna.name)
        true
      else
        false
      end
    end
    
    #@assets_for_each_special_object = {}
    #SPECIAL_OBJECT_IDS.each do |special_object_id|
    #  begin
    #    special_object = game.special_objects[special_object_id]
    #    sprite_info = special_object.extract_gfx_and_palette_and_sprite_from_create_code
    #    if sprite_info.gfx_file_pointers == COMMON_SPRITE[:gfx_files]
    #      # Don't count the common sprite.
    #      @assets_for_each_special_object[special_object_id] = []
    #    else
    #      @assets_for_each_special_object[special_object_id] = sprite_info.gfx_file_pointers
    #    end
    #  rescue StandardError => e
    #    puts "Error getting sprite info for object id %02X" % special_object_id
    #    @assets_for_each_special_object[special_object_id] = []
    #  end
    #end
    
    game.each_room do |room|
      @enemy_pool_for_room = []
      @num_spawners = 0
      @total_cpu_intensive_enemies_in_room = 0
      @assets_needed_for_room = []
      
      enemy_overlay_id_for_room = overlay_ids_for_common_enemies.sample(random: rng)
      @allowed_enemies_for_room = COMMON_ENEMY_IDS.select do |enemy_id|
        overlay = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
        overlay.nil? || overlay == enemy_overlay_id_for_room
      end
      
      enemies_in_room = room.entities.select{|e| e.is_common_enemy?}
      
      next if enemies_in_room.empty?
      
      #objects_in_room = room.entities.select{|e| e.is_special_object?}
      #objects_in_room.each do |object|
      #  assets = @assets_for_each_special_object[object.subtype]
      #  puts "OBJ: %02X, ASSETS: #{assets}" % object.subtype
      #  @assets_needed_for_room += assets
      #  @assets_needed_for_room.uniq!
      #end
      
      if enemies_in_room.length >= 6
        # Don't let cpu intensive enemies in rooms that have lots of enemies.
        
        @allowed_enemies_for_room -= @cpu_intensive_enemy_ids
      end
      
      # Don't allow spawners in Nest of Evil/Large Cavern.
      if (GAME == "por" && room.area_index == 9) || (GAME == "ooe" && room.area_index == 0x0C)
        @allowed_enemies_for_room -= SPAWNER_ENEMY_IDS
      end
      # Don't allow spawners in the train room.
      if GAME == "por" && room.area_index == 2 && room.sector_index == 0 && room.room_index == 1
        @allowed_enemies_for_room -= SPAWNER_ENEMY_IDS
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
      max_allowed_enemy_attack = max_enemy_attack*@max_enemy_attack_room_multiplier
      
      enemies_in_room.shuffle(random: rng).each_with_index do |enemy, i|
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
        
        if i == 0 && enemies_in_room.length > 1
          # We don't want the first enemy we place to be one that there can only be a limited number in a given room.
          # This is because if this one enemy goes over the asset limit for the room, then we wouldn't have any enemies left to place: the same one we already placed would go over the limit per room, while any new one would go over the asset limit.
          # If the total number of enemies in the room is 1 it doesn't matter.
          limitable_enemy_ids = @cpu_intensive_enemy_ids + SPAWNER_ENEMY_IDS
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
        
        remaining_new_room_difficulty -= enemy.subtype
        
        assets = @assets_for_each_enemy[enemy.subtype]
        @assets_needed_for_room += assets
        @assets_needed_for_room.uniq!
        
        if @total_cpu_intensive_enemies_in_room >= 2
          # We don't want too many skeletally animated enemies on screen at once, as it takes up too much processing power.
          
          @allowed_enemies_for_room -= @cpu_intensive_enemy_ids
          @enemy_pool_for_room -= @cpu_intensive_enemy_ids
        end
      end
      
      #puts "ASSETS: #{@assets_needed_for_room.size}, ROOM: %02X-%02X-%02X" % [room.area_index, room.sector_index, room.room_index] if @assets_needed_for_room.size > 10
    end
  end
  
  def randomize_enemy(enemy)
    if GAME == "dos" && enemy.room.sector_index == 4 && enemy.room.room_index == 0x10 && enemy.subtype == 0x3A
      # That one Malachi needed for Dmitrii's event. Don't do anything to it or the event gets messed up.
      return
    end
    if GAME == "ooe" && enemy.room.area_index == 0 && enemy.room.sector_index == 0xC
      # Those two gargoyles outside of the castle. These aren't supposed to be enemies, just decorations, so don't randomize them.
      return
    end
    
    if @assets_needed_for_room.size >= MAX_ASSETS_PER_ROOM && @enemy_pool_for_room.any?
      # There's a limit to how many different GFX files can be loaded at once before things start getting very buggy.
      # Once there's too many, just select from enemies already in the room.
      
      random_enemy_id = @enemy_pool_for_room.sample(random: rng)
    else
      # Enemies are chosen weighted closer to the ID of what the original enemy was so that early game enemies are less likely to roll into endgame enemies.
      # Method taken from: https://gist.github.com/O-I/3e0654509dd8057b539a
      max_enemy_id = ENEMY_IDS.max
      weights = @allowed_enemies_for_room.map do |possible_enemy_id|
        id_difference = (possible_enemy_id - enemy.subtype).abs
        weight = max_enemy_id - id_difference
        weight**@enemy_difficulty_preservation_weight_exponent
      end
      ps = weights.map{|w| w.to_f / weights.reduce(:+)}
      weighted_enemy_ids = @allowed_enemies_for_room.zip(ps).to_h
      random_enemy_id = weighted_enemy_ids.max_by{|_, weight| rng.rand ** (1.0 / weight)}.first
    end
    
    fix_enemy_position(enemy)
    
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
      @enemy_pool_for_room.uniq!
      
      if @cpu_intensive_enemy_ids.include?(random_enemy_id)
        @total_cpu_intensive_enemies_in_room += 1
      end
    end
  end
  
  def fix_enemy_position(enemy)
    enemy.x_pos = [enemy.x_pos, 0x10].max
    enemy.y_pos = [enemy.y_pos, 0x10].max
    
    room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
    room_height = enemy.room.height*SCREEN_HEIGHT_IN_PIXELS
    enemy.x_pos = [enemy.x_pos, room_width-0x10].min
    enemy.y_pos = [enemy.y_pos, room_height-0x10].min
    
    if enemy.x_pos <= 0x40
      close_to_left_door = enemy.room.doors.find{|door| door.direction == :left && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
      if close_to_left_door
        #puts "CLOSE LEFT %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.x_pos = 0x40
      end
    elsif enemy.x_pos >= room_width - 0x40
      close_to_right_door = enemy.room.doors.find{|door| door.direction == :right && door.y_pos == enemy.y_pos/SCREEN_HEIGHT_IN_PIXELS}
      if close_to_right_door
        #puts "CLOSE RIGHT %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.x_pos = room_width - 0x40
      end
    end
    if enemy.y_pos <= 0x60
      close_to_up_door = enemy.room.doors.find{|door| door.direction == :up && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
      if close_to_up_door
        #puts "CLOSE UP %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        enemy.y_pos = 0x60
      end
    end
    if enemy.y_pos >= room_height - SCREEN_HEIGHT_IN_PIXELS
      close_to_down_door = enemy.room.doors.find{|door| door.direction == :down && door.x_pos == enemy.x_pos/SCREEN_WIDTH_IN_PIXELS}
      if close_to_down_door
        #puts "CLOSE DOWN %02X-%02X-%02X_%02X" % [enemy.room.area_index, enemy.room.sector_index, enemy.room.room_index, enemy.room.entities.index(enemy)]
        if room_height - 0x40 < enemy.y_pos
          enemy.y_pos = room_height - 0x40
        end
        if (0x51..0xAF).include?(enemy.x_pos % 0x100)
          # Over the center of a door.
          # Also move it a little to the left or right a little, so it doesn't fall on the player's head.
          enemy.x_pos = enemy.x_pos/0x100*0x100 + [0x50, 0xB0].sample(random: rng)
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
      enemy.var_a = rng.rand(1..8)
    when "Malachi"
      enemy.var_a = 0
    when "Medusa Head"
      enemy.var_a = rng.rand(1..7) # Max at once
      enemy.var_b = rng.rand(0..1) # Type of Medusa Head
    when "Mud Demon"
      enemy.var_b = rng.rand(0..0x50) # Max rand spawn distance
    when "Stolas"
      if @enemy_pool_for_room.any?
        enemy_id_a = @enemy_pool_for_room.sample(random: rng)
        enemy_id_b = @enemy_pool_for_room.sample(random: rng)
      elsif (@allowed_enemies_for_room-@cpu_intensive_enemy_ids).any?
        enemy_id_a = (@allowed_enemies_for_room-@cpu_intensive_enemy_ids).sample(random: rng)
        enemy_id_b = (@allowed_enemies_for_room-@cpu_intensive_enemy_ids).sample(random: rng)
        
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
      room_has_left_doors = !!enemy.room.doors.find{|door| door.direction == :left}
      room_has_right_doors = !!enemy.room.doors.find{|door| door.direction == :right}
      if room_has_left_doors && !room_has_right_doors
        # On a right wall.
        enemy.var_a = 1
        room_width = room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
        enemy.x_pos = room_width - 0x10
      elsif room_has_right_doors && !room_has_left_doors
        # On a left wall.
        enemy.var_a = 0
        enemy.x_pos = 0x10
      else
        # Hard to know where to place this enemy if the room has both left and right doors.
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
    else
      enemy.var_a = 0
      enemy.var_b = 0
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
      if enemy.room.height > 1
        # Don't allow in tall rooms
        return :redo
      end
      if enemy.room.width <= 1
        # Don't allow in non-wide rooms
        return :redo
      end
      if enemy.room.doors.find{|door| door.y_pos >= 1}
        # Don't allow in rooms that have a door in the floor
        return :redo
      end
      
      enemy.var_a = 1
    when "Mud Man", "Mummy"
      # 10% chance to be a single one, 90% chance to be a spawner.
      if rng.rand <= 0.10
        enemy.var_a = 0
      else
        enemy.var_a = rng.rand(2..6) # Max at once
        
        room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
        enemy.var_b = rng.rand(100..room_width) # Max horizontal distance in pixels from the spawner to spawn them
      end
    when "Skeleton Gunman"
      room_width = enemy.room.width*SCREEN_WIDTH_IN_PIXELS
      max_left_dist = enemy.x_pos - 0x10
      max_right_dist = room_width - enemy.x_pos - 0x10
      
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
      
      if max_dist <= 0x20
        dist = 0x20
      else
        dist = rng.rand(0x20..max_dist)
      end
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
    else
      enemy.var_a = 0
      enemy.var_b = 0
    end
  end
  
  def ooe_adjust_randomized_enemy(enemy, enemy_dna)
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
      # Move out of the floor
      enemy.y_pos -= 0x08
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
    else
      enemy.var_a = 0
      enemy.var_b = 0
    end
  end
end
