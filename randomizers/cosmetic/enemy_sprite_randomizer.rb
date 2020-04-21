
module EnemySpriteRandomizer
  def randomize_enemy_sprites
    enemy_ids_to_randomize = []
    if options[:randomize_enemy_sprites]
      enemy_ids_to_randomize += COMMON_ENEMY_IDS
    end
    if options[:randomize_boss_sprites]
      enemy_ids_to_randomize += BOSS_IDS
    end
    
    sprite_info_locations_for_enemy = {}
    orig_enemy_id_to_reused_enemy_ids = {}
    all_enemy_sprites = []
    enemy_ids_to_randomize.each do |enemy_id|
      if (REUSED_ENEMY_INFO[enemy_id] || {})[:init_code] == -1
        # No sprite
        next
      end
      if GAME == "por" && ["Andras", "Dragon Zombie"].include?(game.enemy_dnas[enemy_id].name)
        # TODO: Need to implement func 0x02021364 LoadSpriteMultiGfx2? somehow
        # this also is used for most bosses
        next
      end
      
      enemy = game.enemy_dnas[enemy_id]
      
      puts "Enemy ID: %02X #{enemy.name}" % enemy_id
      reused_info = REUSED_ENEMY_INFO[enemy_id] || {}
      overlay_to_load = OVERLAY_FILE_FOR_ENEMY_AI[enemy_id]
      ptr_to_ptr_to_files_to_load = ENEMY_FILES_TO_LOAD_LIST + enemy_id*4
      result_hash = find_gfx_and_palette_and_sprite_locations_in_create_code(
        enemy["Create Code"],
        game.fs, overlay_to_load,
        reused_info, ptr_to_ptr_to_files_to_load
      )
      
      orig_enemy = sprite_info_locations_for_enemy.find do |enemy_id, other_hash|
        result_hash[:line_that_called_func]   == other_hash[:line_that_called_func]   &&
        result_hash[:location_of_gfx_ptr]     == other_hash[:location_of_gfx_ptr]     &&
        result_hash[:location_of_palette_ptr] == other_hash[:location_of_palette_ptr] &&
        result_hash[:location_of_sprite_ptr]  == other_hash[:location_of_sprite_ptr]  &&
        result_hash[:overlay_to_load]         == other_hash[:overlay_to_load]
      end
      if orig_enemy
        orig_enemy_id, _ = orig_enemy
        orig_enemy_id_to_reused_enemy_ids[orig_enemy_id] ||= []
        orig_enemy_id_to_reused_enemy_ids[orig_enemy_id] << enemy_id
        
        puts "Enemy is reused (orig: %02X #{game.enemy_dnas[orig_enemy_id].name}), skipping" % orig_enemy_id
        puts
        next
      end
      
      sprite_info_locations_for_enemy[enemy_id] = result_hash
      all_enemy_sprites << Sprite.new(result_hash[:sprite_ptr], game.fs)
      puts
    end
    
    remaining_unused_enemy_sprite_ids = sprite_info_locations_for_enemy.keys
    remaining_unused_enemy_sprite_ids.shuffle!(random: rng)
    
    sprite_info_locations_for_enemy.each do |enemy_id, hash|
      overlay_to_load = hash[:overlay_to_load]
      if overlay_to_load.is_a?(Integer)
        game.fs.load_overlay(overlay_to_load)
      elsif overlay_to_load.is_a?(Array)
        overlay_to_load.each do |overlay|
          game.fs.load_overlay(overlay)
        end
      end
      
      line_that_called_func    = hash[:line_that_called_func]
      location_of_gfx_ptr      = hash[:location_of_gfx_ptr]
      location_of_palette_ptr  = hash[:location_of_palette_ptr]
      location_of_sprite_ptr   = hash[:location_of_sprite_ptr]
      
      other_enemy_id = remaining_unused_enemy_sprite_ids.pop()
      other_hash = sprite_info_locations_for_enemy[other_enemy_id]
      other_is_multi_gfx             = other_hash[:is_multi_gfx]
      other_gfx_ptr                  = other_hash[:gfx_ptr]
      other_palette_ptr              = other_hash[:palette_ptr]
      other_sprite_ptr               = other_hash[:sprite_ptr]
      other_pointer_to_files_to_load = other_hash[:pointer_to_files_to_load]
      
      enemy = game.enemy_dnas[enemy_id]
      other_enemy = game.enemy_dnas[other_enemy_id]
      puts "Gave %02X #{enemy.name} the sprite of %02X #{other_enemy.name}" % [enemy_id, other_enemy_id]
      
      # Update which files this enemy loads
      game.fs.write(ENEMY_FILES_TO_LOAD_LIST + enemy_id*4, [other_pointer_to_files_to_load].pack("V"))
      
      # Also update the files loaded by any reused versions of this enemy
      if orig_enemy_id_to_reused_enemy_ids[enemy_id]
        orig_enemy_id_to_reused_enemy_ids[enemy_id].each do |reused_enemy_id|
          game.fs.write(ENEMY_FILES_TO_LOAD_LIST + reused_enemy_id*4, [other_pointer_to_files_to_load].pack("V"))
        end
      end
      
      game.fs.write(location_of_gfx_ptr, [other_gfx_ptr].pack("V"))
      game.fs.write(location_of_palette_ptr, [other_palette_ptr].pack("V"))
      game.fs.write(location_of_sprite_ptr, [other_sprite_ptr].pack("V"))
      
      if other_is_multi_gfx
        load_sprite_func_to_use = CUSTOM_LOAD_SPRITE_MULTI_GFX_FUNC_PTR
      else
        load_sprite_func_to_use = LOAD_SPRITE_SINGLE_GFX_FUNC_PTR
      end
      func_offset = ((load_sprite_func_to_use - line_that_called_func - 8) / 4) & 0x00FFFFFF
      new_line_of_code = 0xEB000000 | func_offset
      game.fs.write(line_that_called_func, [new_line_of_code].pack("V"))
    end
    
    all_enemy_sprites.each do |sprite|
      fix_enemy_sprite(sprite)
    end
  end
  
  def fix_enemy_sprite(sprite)
    any_changes_made_to_this_sprite = false
    
    # Add a hitbox to every frame if it had no hitboxes originally.
    sprite.frames.each do |frame|
      next if frame.number_of_hitboxes > 0 # Don't add hitboxes if the frame already has them
      next if frame.number_of_parts == 0 # Don't add hitboxes if the frame is not even visible
      
      min_part_x = frame.parts.map{|part| part.x_pos}.min
      min_part_y = frame.parts.map{|part| part.y_pos}.min
      max_part_x = frame.parts.map{|part| part.x_pos + part.width}.max
      max_part_y = frame.parts.map{|part| part.y_pos + part.height}.max
      
      hitbox = Hitbox.new
      hitbox.x_pos = min_part_x
      hitbox.y_pos = min_part_y
      hitbox.width = max_part_x - min_part_x
      hitbox.height = max_part_y - min_part_y
      
      frame.hitboxes << hitbox
      frame.first_hitbox_offset = sprite.hitboxes.size*Hitbox.data_size
      sprite.hitboxes << hitbox
      
      any_changes_made_to_this_sprite = true
    end
    
    # Pad every existing animation with duplicate keyframes to get it up to 20 keyframes. (Assuming we can do so without affecting the actual time the animation takes to play out.)
    # The reason we need to make the animation have a lot of keyframes is to to fix the issue of some enemies not advancing until a certain keyframe index is reached (e.g. like how Vol Arcus doesn't fire until keyframe 0xD is reached).
    # So instead of having one keyframe that lasts for a certain number of frames, we have a bunch of keyframes that only last for 1 frame each.
    sprite.animations.each do |animation|
      remaining_keyframes_to_add = (20 - animation.frame_delays.length)
      
      next if remaining_keyframes_to_add <= 0
      
      any_changes_made_to_this_sprite = true
      
      new_frame_delays = []
      animation.frame_delays.each do |frame_delay|
        new_frame_delays << frame_delay
        
        next if remaining_keyframes_to_add <= 0
        next if frame_delay.delay < 2
        
        dupes_to_add = [frame_delay.delay-1, remaining_keyframes_to_add].min
        
        frame_delay.delay = 1
        
        dupes_to_add.times do
          dupe_frame_delay = FrameDelay.new
          dupe_frame_delay.frame_index = frame_delay.frame_index
          dupe_frame_delay.delay = 1
          new_frame_delays << dupe_frame_delay
        end
        
        remaining_keyframes_to_add -= dupes_to_add
      end
      
      animation.frame_delays.clear()
      new_frame_delays.each do |frame_delay|
        animation.frame_delays << frame_delay
      end
    end
    
    sprite.frame_delays.clear()
    sprite.animations.each do |animation|
      animation.frame_delays.each do |frame_delay|
        sprite.frame_delays << frame_delay
      end
    end
    
    # Add one dummy animation if it had no animations. Give it 20 keyframes, each lasting 1 frame.
    if sprite.animations.length == 0
      num_keyframes = 20
      
      animation = Animation.new
      sprite.animations << animation
      
      num_keyframes.times do |i|
        frame_delay = FrameDelay.new
        frame_delay.frame_index = 0 # Use the first frame
        frame_delay.delay = 1 # 1 frame of delay
        
        sprite.frame_delays << frame_delay
        animation.frame_delays << frame_delay
      end
      
      any_changes_made_to_this_sprite = true
    end
    
    if any_changes_made_to_this_sprite
      sprite.write_to_rom()
    end
  end
  
  def find_gfx_and_palette_and_sprite_locations_in_create_code(create_code_pointer, fs, overlay_to_load, reused_info, ptr_to_ptr_to_files_to_load=nil)
    # This function attempts to find the code that loads the sprite, GFX, and palette for each enemy so that the enemy sprite randomizer can change these.
    # On top of finding those 3 pointers, it also needs to find the line of code that calls LoadSpriteSingleGfx or LoadSpriteMultiGfx so that it can be changed to either one or the other at will.
    
    if overlay_to_load.is_a?(Integer)
      fs.load_overlay(overlay_to_load)
    elsif overlay_to_load.is_a?(Array)
      overlay_to_load.each do |overlay|
        fs.load_overlay(overlay)
      end
    end
    
    if GAME == "por"
      fs.load_overlay(4)
    end
    
    create_code_pointer    = reused_info[:init_code] || create_code_pointer
    gfx_sheet_ptr_index    = reused_info[:gfx_sheet_ptr_index] || 0
    palette_offset         = reused_info[:palette_offset] || 0
    palette_list_ptr_index = reused_info[:palette_list_ptr_index] || 0
    sprite_ptr_index       = reused_info[:sprite_ptr_index] || 0
    ignore_files_to_load   = reused_info[:ignore_files_to_load] || false
    
    if create_code_pointer == -1
      raise CreateCodeReadError.new("This entity has no sprite.")
    end
    
    # Clear lowest two bits of create code pointer so it's aligned to 4 bytes.
    create_code_pointer = create_code_pointer & 0xFFFFFFFC
    
    
    
    possible_gfx_pointers = []
    gfx_page_pointer = nil
    list_of_gfx_page_pointers_wrapper_pointer = nil
    possible_palette_pointers = []
    possible_sprite_pointers = []
    
    
    # The format of a function call is as follows:
    # The first byte is EB for a branch with link (assuming it's unconditional, which it should be for loading a sprite).
    # The remaining three bytes are the offset from the current line of code to the start of the function to call, calculated with this formula: (target_address-curr_address-8)/4
    # So if the line of code calling the function is 0223327C and the function being called is 0201C1B8, the remaining three bytes would be: (0201C1B8-0223327C-8)/4 = F7A3CD
    # And the reverse formula, if you have F7A3CD: 0223327C - ((-F7A3CD)&FFFFFF)*4 + 8
    
    current_code_pointer = create_code_pointer
    called_func_ptr = nil
    line_that_called_func = nil
    data = fs.read(create_code_pointer, 4*1000, allow_length_to_exceed_end_of_file: true)
    data.unpack("V*").each_with_index do |word, i|
      word = fs.read(current_code_pointer, 4).unpack("V").first
      
      if (word >> 24) == 0xEB
        # Function call.
        func_offset = word & 0x00FFFFFF
        if (func_offset & 0x00800000) > 0
          # Negative, do some bitwise stuff to give it a proper negative sign.
          func_offset = -((-func_offset) & 0x00FFFFFF)
        end
        func_pointer = current_code_pointer + func_offset*4 + 8
        if func_pointer == LOAD_SPRITE_SINGLE_GFX_FUNC_PTR
          called_func_ptr = func_pointer
          line_that_called_func = current_code_pointer
          break
        elsif func_pointer == LOAD_SPRITE_MULTI_GFX_FUNC_PTR
          called_func_ptr = func_pointer
          line_that_called_func = current_code_pointer
          break
        end
      end
      
      current_code_pointer += 4
    end
    
    if called_func_ptr.nil?
      raise "Could not find a function call to either LoadSpriteSingleGfx or LoadSpriteMultiGfx."
    end
    
    is_multi_gfx = (called_func_ptr == LOAD_SPRITE_MULTI_GFX_FUNC_PTR)
    line_that_loads_gfx_ptr = nil
    location_of_gfx_ptr = nil
    gfx_ptr = nil
    line_that_loads_palette_ptr = nil
    location_of_palette_ptr = nil
    palette_ptr = nil
    line_that_loads_sprite_ptr = nil
    location_of_sprite_ptr = nil
    sprite_ptr = nil
    (create_code_pointer..line_that_called_func).step(4).reverse_each do |current_code_pointer|
      word = fs.read(current_code_pointer, 4).unpack("V").first
      
      #puts "checking line %08X, code is %08X" % [current_code_pointer, word]
      
      if (word >> 16) == 0xE59F
        # Constant load instruction.
        constant_offset = (word & 0xFFF)
        #puts "constant load with offset %03X" % constant_offset
        location_of_constant = current_code_pointer + constant_offset + 8
        constant = fs.read(location_of_constant, 4).unpack("V").first
        next unless fs.is_pointer?(constant)
        
        pointer = constant
        
        if is_multi_gfx && SpriteInfo.check_if_valid_gfx_list_pointer(pointer, fs)
          line_that_loads_gfx_ptr = current_code_pointer
          location_of_gfx_ptr = location_of_constant
          gfx_ptr = pointer
        elsif !is_multi_gfx && SpriteInfo.check_if_valid_gfx_wrapper_pointer(pointer, fs)
          line_that_loads_gfx_ptr = current_code_pointer
          location_of_gfx_ptr = location_of_constant
          gfx_ptr = pointer
        elsif SpriteInfo.check_if_valid_palette_pointer(pointer, fs)
          line_that_loads_palette_ptr = current_code_pointer
          location_of_palette_ptr = location_of_constant
          palette_ptr = pointer
        elsif SpriteInfo.check_if_valid_sprite_pointer(pointer, fs)
          line_that_loads_sprite_ptr = current_code_pointer
          location_of_sprite_ptr = location_of_constant
          sprite_ptr = pointer
        end
        
        if gfx_ptr && palette_ptr && sprite_ptr
          break
        end
      end
    end
    
    if gfx_ptr.nil? || palette_ptr.nil? || sprite_ptr.nil?
      not_found_ptrs = []
      not_found_ptrs << "GFX pointer" if gfx_ptr.nil?
      not_found_ptrs << "palette pointer" if palette_ptr.nil?
      not_found_ptrs << "sprite pointer" if sprite_ptr.nil?
      raise "Could not find line that loads #{not_found_ptrs.join(", ")}."
    end
    
    
    puts "%08X called %08X" % [line_that_called_func, called_func_ptr]
    if is_multi_gfx
      puts "%08X loads GFX list pointer %08X" % [line_that_loads_gfx_ptr, gfx_ptr]
    else
      puts "%08X loads GFX pointer %08X" % [line_that_loads_gfx_ptr, gfx_ptr]
    end
    puts "%08X loads palette %08X" % [line_that_loads_palette_ptr, palette_ptr]
    puts "%08X loads sprite %08X" % [line_that_loads_sprite_ptr, sprite_ptr]
    
    pointer_to_files_to_load = fs.read(ptr_to_ptr_to_files_to_load, 4).unpack("V").first
    
    return {
      line_that_called_func: line_that_called_func,
      called_func_ptr: called_func_ptr,
      is_multi_gfx: is_multi_gfx,
      location_of_gfx_ptr: location_of_gfx_ptr,
      gfx_ptr: gfx_ptr,
      location_of_palette_ptr: location_of_palette_ptr,
      palette_ptr: palette_ptr,
      location_of_sprite_ptr: location_of_sprite_ptr,
      sprite_ptr: sprite_ptr,
      pointer_to_files_to_load: pointer_to_files_to_load,
      overlay_to_load: overlay_to_load,
    }
  end
end
