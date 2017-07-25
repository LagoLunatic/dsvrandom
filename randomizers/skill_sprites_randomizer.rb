
module SkillSpriteRandomizer
  def randomize_skill_sprites
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    
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
  end
end
