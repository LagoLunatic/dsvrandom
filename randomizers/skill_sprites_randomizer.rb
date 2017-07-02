
module SkillSpriteRandomizer
  def randomize_skill_sprites
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    max_skill_sprite_index = skills.map{|skill| skill["Sprite"]}.max
    
    skills.each do |skill|
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
      
      new_sprite_index = possible_sprite_indexes.sample(random: rng)
      skill["Sprite"] = new_sprite_index
      skill.write_to_rom()
    end
  end
end
