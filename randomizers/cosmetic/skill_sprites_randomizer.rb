
module SkillSpriteRandomizer
  def randomize_skill_sprites
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    
    skills_to_randomize = []
    all_skill_sprites = {}
    all_orig_skill_sprites = {}
    weapon_glyph_sprite_indexes = []
    remaining_sprite_indexes_by_type = {}
    skills.each do |skill|
      next if skill["Sprite"] == 0 # Skill with no sprite
      
      if GAME == "ooe" && skill["Item ID"] == 0x68
        # Don't randomize the sprite of the Dominus union.
        # It doesn't look good with other sprites and other glyphs with this sprite don't look good either.
        next
      end
      
      skills_to_randomize << skill
      
      skill_gfx = SkillGfx.new(skill["Sprite"]-1, game.fs)
      sprite = Sprite.new(skill_gfx.sprite_file_pointer, game.fs)
      all_skill_sprites[skill["Sprite"]] = sprite
      orig_sprite = Sprite.new(skill_gfx.sprite_file_pointer, game.fs)
      all_orig_skill_sprites[skill["Sprite"]] = orig_sprite
      
      if GAME == "por"
        # In PoR, dual crushes are hardcoded to have more possible space reserved for allocating their sprite files compared to subweapons/spells.
        # So we can't mix the two groups together, or a subweapon/spell with a large dual crush sprite file could corrupt Jonathan's sprite file which is after it in RAM.
        type = skill["Type"]
      else
        # DoS and OoE do not have this issue.
        type = "any"
      end
      
      remaining_sprite_indexes_by_type[type] ||= []
      
      if !remaining_sprite_indexes_by_type[type].include?(skill["Sprite"])
        remaining_sprite_indexes_by_type[type] << skill["Sprite"]
      end
      
      if GAME == "ooe" && skill["Code"] == 0x02070890
        weapon_glyph_sprite_indexes << skill["Sprite"]
      end
    end
    if GAME == "ooe"
      # Add some glyph unions that animate the same as melee glyphs.
      weapon_glyph_sprite_indexes += [0x45, 0x46, 0x4A, 0x4B]
    end
    
    skill_sprites_to_fix = []
    old_sprite_index_to_new_sprite_index = {}
    new_sprite_index_to_old_sprite_index = {}
    skills_to_randomize.each do |skill|
      if old_sprite_index_to_new_sprite_index[skill["Sprite"]]
        # Always replace one sprite with a specific other one.
        # This simplifies fixing the sprite later on.
        skill["Sprite"] = old_sprite_index_to_new_sprite_index[skill["Sprite"]]
        skill.write_to_rom()
        next
      end
      
      if GAME == "por"
        type = skill["Type"]
      else
        type = "any"
      end
      
      if remaining_sprite_indexes_by_type[type].empty?
        raise "Ran out of unique skill sprite indexes to use"
      end
      
      new_sprite_index = remaining_sprite_indexes_by_type[type].sample(random: rng) || 0
      old_sprite_index_to_new_sprite_index[skill["Sprite"]] = new_sprite_index
      new_sprite_index_to_old_sprite_index[new_sprite_index] = skill["Sprite"]
      remaining_sprite_indexes_by_type[type].delete(new_sprite_index)
      skill["Sprite"] = new_sprite_index
      skill.write_to_rom()
      
      skill_sprites_to_fix << new_sprite_index
    end
    
    skill_sprites_to_fix.uniq!
    skill_sprites_to_fix.each do |new_sprite_index|
      new_sprite = all_skill_sprites[new_sprite_index]
      
      old_sprite_index = new_sprite_index_to_old_sprite_index[new_sprite_index]
      old_sprite = all_orig_skill_sprites[old_sprite_index]
      
      old_is_weapon_glyph_sprite = weapon_glyph_sprite_indexes.include?(old_sprite_index)
      new_is_weapon_glyph_sprite = weapon_glyph_sprite_indexes.include?(new_sprite_index)
      
      fix_skill_or_enemy_sprite(new_sprite, old_sprite, new_is_weapon_glyph_sprite, old_is_weapon_glyph_sprite)
    end
  end
  
  def fix_skill_or_enemy_sprite(sprite, old_sprite, new_is_weapon_glyph_sprite, old_is_weapon_glyph_sprite)
    any_changes_made_to_this_sprite = false
    
    # Fix OoE weapon glyphs being stuck on your feet when they get a non-weapon glyph sprite.
    if old_is_weapon_glyph_sprite && !new_is_weapon_glyph_sprite
      sprite.parts.each do |part|
        part.x_pos += 0x20
        part.y_pos -= 0x20
      end
      sprite.hitboxes.each do |hitbox|
        hitbox.x_pos += 0x20
        hitbox.y_pos -= 0x20
      end
      any_changes_made_to_this_sprite = true
    end
    
    # If there were any completely invisible frames, copy a visible frame over them.
    invisible_frames = sprite.frames.select{|frame| frame.number_of_parts == 0}
    if invisible_frames.any?
      first_visible_frame = sprite.frames.find{|frame| frame.number_of_parts != 0}
      if first_visible_frame.nil?
        raise "Sprite has no visible frames"
      end
      
      invisible_frames.each do |invisible_frame|
        first_visible_frame.parts.each do |part|
          if sprite.sprite_file
            # Sprites in individual files can't reuse the same part multiple times.
            new_part = part.dup
            sprite.parts << new_part
            invisible_frame.parts << new_part
          else
            invisible_frame.parts << part
          end
        end
        
        # Also copy the hitbox if necessary.
        first_visible_frame.hitboxes.each do |hitbox|
          if sprite.sprite_file
            # Sprites in individual files can't reuse the same hitbox multiple times.
            new_hitbox = hitbox.dup
            sprite.hitboxes << new_hitbox
            invisible_frame.hitboxes << new_hitbox
          else
            invisible_frame.hitboxes << hitbox
          end
        end
      end
      
      any_changes_made_to_this_sprite = true
    end
    
    # Add a hitbox to every frame if it had no hitboxes originally.
    sprite.frames.each do |frame|
      next if frame.number_of_hitboxes > 0 # Don't add hitboxes if the frame already has them
      
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
      sprite.hitboxes << hitbox
      
      any_changes_made_to_this_sprite = true
    end
    
    # Pad out the total number of frames so that all the unanimated frame indexes of the original exist in the new one too.
    old_animated_frame_indexes = []
    old_sprite.animations.each do |anim|
      anim.frame_delays.each do |frame_delay|
        old_animated_frame_indexes << frame_delay.frame_index
      end
    end
    old_highest_unanimated_frame_index = 0
    old_sprite.frames.each_with_index do |frame, frame_index|
      next if old_animated_frame_indexes.include?(frame_index)
      old_highest_unanimated_frame_index = frame_index
    end
    if sprite.animations.length > 0
      orig_frame = sprite.frames[sprite.animations[0].frame_delays[0].frame_index]
    else
      orig_frame = sprite.frames[0]
    end
    while sprite.frames.length <= old_highest_unanimated_frame_index
      new_frame = Frame.new
      orig_frame.hitboxes.each do |hitbox|
        if sprite.sprite_file
          # Sprites in individual files can't reuse the same hitbox multiple times.
          new_hitbox = hitbox.dup
          sprite.hitboxes << new_hitbox
          new_frame.hitboxes << new_hitbox
        else
          new_frame.hitboxes << hitbox
        end
      end
      orig_frame.parts.each do |part|
        if sprite.sprite_file
          # Sprites in individual files can't reuse the same part multiple times.
          new_part = part.dup
          sprite.parts << new_part
          new_frame.parts << new_part
        else
          new_frame.parts << part
        end
      end
      sprite.frames << new_frame
      
      any_changes_made_to_this_sprite = true
    end
    
    # Pad every existing animation with duplicate keyframes to get it up to the same number of keyframes the original sprite had for this animation. (Assuming we can do so without affecting the actual time the animation takes to play out.)
    # The reason we need to make the animation have a lot of keyframes is to to fix the issue of some skills/enemies not advancing until a certain keyframe index is reached (e.g. Vol Arcus doesn't fire until keyframe 0xD is reached).
    # So instead of having one keyframe that lasts for a certain number of frames, we have a bunch of keyframes that only last for 1 frame each.
    sprite.animations.each_with_index do |animation, anim_index|
      if anim_index >= old_sprite.animations.length
        break
      end
      old_animation = old_sprite.animations[anim_index]
      remaining_keyframes_to_add = (old_animation.frame_delays.length - animation.frame_delays.length)
      
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
end
