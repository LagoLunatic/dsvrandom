
module SkillSpriteRandomizer
  def randomize_skill_sprites
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    
    all_skill_sprites = {}
    skills.each do |skill|
      next if skill["Sprite"] == 0 # Skill with no sprite
      
      skill_gfx = SkillGfx.new(skill["Sprite"]-1, game.fs)
      sprite = Sprite.new(skill_gfx.sprite_file_pointer, game.fs)
      all_skill_sprites[skill["Sprite"]] = sprite
    end
    
    skill_sprites_to_fix = []
    skills.each do |skill|
      next if skill["Sprite"] == 0 # Skill with no sprite
      
      if GAME == "dos" || GAME == "por"
        skills_of_same_type = skills.select do |other_skill|
          other_skill["Type"] == skill["Type"]
        end
      elsif GAME == "ooe"
        case skill["Item ID"]
        when 0x00..0x36
          skills_of_same_type = skills[0x00..0x36]
        when 0x37..0x4F
          skills_of_same_type = skills[0x37..0x4F]
        when 0x50..0x6E
          skills_of_same_type = skills[0x50..0x6E]
        end
      end
      
      possible_sprite_indexes = skills_of_same_type.map{|skill| skill["Sprite"]}.uniq
      possible_sprite_indexes -= [0] # Not a valid sprite
      
      new_sprite_index = possible_sprite_indexes.sample(random: rng)
      skill["Sprite"] = new_sprite_index
      skill.write_to_rom()
      
      skill_sprites_to_fix << new_sprite_index
      
      skill_gfx = SkillGfx.new(new_sprite_index-1, game.fs)
      sprite = Sprite.new(skill_gfx.sprite_file_pointer, game.fs)
      
      if GAME == "dos"
        no_hitbox_frames = sprite.frames.select{|frame| frame.number_of_hitboxes == 0}
        hitbox_frames = sprite.frames.select{|frame| frame.number_of_hitboxes > 0}
        if hitbox_frames.any?
          no_hitbox_frames.each do |no_hitbox_frame|
            hitbox_frame = hitbox_frames.first
            no_hitbox_frame.number_of_hitboxes = hitbox_frame.number_of_hitboxes
            no_hitbox_frame.first_hitbox_offset = hitbox_frame.first_hitbox_offset
          end
        end
        sprite.write_to_rom()
      end
    end
    
    skill_sprites_to_fix.uniq!
    skill_sprites_to_fix.each do |skill_sprite_index|
      sprite = all_skill_sprites[skill_sprite_index]
      fix_skill_sprite(sprite)
    end
  end
  
  def fix_skill_sprite(sprite)
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
      frame.number_of_hitboxes += 1
      frame.first_hitbox_offset = sprite.hitboxes.size*Hitbox.data_size
      sprite.hitboxes << hitbox
      
      any_changes_made_to_this_sprite = true
    end
    
    # Add one dummy animation if it had no animations.
    if sprite.animations.length == 0
      # We need to make the animation have a lot of keyframes in order to fix the issue of some skills not advancing until a certain keyframe index is reached (e.g. Vol Arcus doesn't fire until keyframe 0xD is reached).
      # So instead of having one keyframe that lasts for a certain number of frames, we have a bunch of keyframes that only last for 1 frame each.
      num_keyframes = 20
      
      animation = Animation.new
      animation.first_frame_delay_offset = sprite.frame_delays.size*FrameDelay.data_size
      animation.number_of_frames = num_keyframes
      sprite.animations << animation
      
      num_keyframes.times do |i|
        frame_delay = FrameDelay.new
        frame_delay.frame_index = 0 # Use the first frame
        frame_delay.delay = 1 # 1 frame of delay
        
        sprite.frame_delays << frame_delay
      end
      
      any_changes_made_to_this_sprite = true
    end
    
    if any_changes_made_to_this_sprite
      sprite.write_to_rom()
    end
  end
end
