
module DropRandomizer
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
    
    if GAME == "dos"
      # Doppelganger's description has 2 lines, but the enemy page only displays 1 line correctly.
      # Cut off the second line.
      description = game.text_database.text_list[TEXT_REGIONS["Soul Descriptions"].begin + 0x76]
      description.decoded_string = "Switch souls and equipment \\nusing the {BUTTON X}."
      game.text_database.write_to_rom()
    end
    
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy = game.enemy_dnas[enemy_id]
      
      can_drop_items = true
      if GAME == "ooe" && enemy.name == "Blood Skeleton"
        # Blood Skeletons can't be killed so they can't drop items.
        can_drop_items = false
      end
      if GAME == "por" && ["Sand Worm", "Poison Worm"].include?(enemy.name)
        # Worms generally stay dead permanently after being killed once, so any drops given to them would be missable.
        can_drop_items = false
      end
      if GAME == "por" && ["Hanged Bones", "Skeleton Tree"].include?(enemy.name)
        # These attach to a wall or ceiling and consider their position to be inside the solid wall - so any item they try to drop would refuse to spawn.
        can_drop_items = false
      end
      
      if rng.rand <= 0.5 && can_drop_items # 50% chance to have an item drop
        if GAME == "por"
          enemy["Item 1"] = get_unplaced_non_progression_pickup_for_enemy_drop() + 1
        elsif GAME == "ooe"
          # Don't let enemies drop relics since they won't auto-equip.
          enemy["Item 1"] = get_unplaced_non_progression_item_except_ooe_relics_for_enemy_drop() + 1
        else
          enemy["Item 1"] = get_unplaced_non_progression_item_for_enemy_drop() + 1
        end
        
        if rng.rand <= 0.5 # Further 50% chance (25% total) to have a second item drop
          if GAME == "por"
            enemy["Item 2"] = get_unplaced_non_progression_pickup_for_enemy_drop() + 1
          elsif GAME == "ooe"
            # Don't let enemies drop relics since they won't auto-equip.
            enemy["Item 2"] = get_unplaced_non_progression_item_except_ooe_relics_for_enemy_drop() + 1
          else
            enemy["Item 2"] = get_unplaced_non_progression_item_for_enemy_drop() + 1
          end
        else
          enemy["Item 2"] = 0
        end
      else
        enemy["Item 1"] = 0
        enemy["Item 2"] = 0
      end
      
      item_1_chance = named_rand_range_weighted(:item_drop_chance_range)
      item_2_chance = named_rand_range_weighted(:item_drop_chance_range)
      skill_chance = named_rand_range_weighted(:skill_drop_chance_range)
      
      case GAME
      when "dos"
        internal_item_chance = (item_1_chance/100.0*1024/3).floor
        internal_item_chance = 1 if internal_item_chance < 1
        internal_item_chance = 255 if internal_item_chance > 255
        enemy["Item Chance"] = internal_item_chance
        
        enemy["Soul"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin
        
        internal_soul_chance = (skill_chance/100.0*512).floor
        internal_soul_chance = 1 if internal_soul_chance < 1
        internal_soul_chance = 255 if internal_soul_chance > 255
        enemy["Soul Chance"] = internal_soul_chance
      when "por"
        internal_item_1_chance = (item_1_chance*2.56).floor
        internal_item_1_chance = 1 if internal_item_1_chance < 1
        internal_item_1_chance = 255 if internal_item_1_chance > 255
        enemy["Item 1 Chance"] = internal_item_1_chance
        
        internal_item_2_chance = (item_2_chance*2.56).floor
        internal_item_2_chance = 1 if internal_item_2_chance < 1
        internal_item_2_chance = 255 if internal_item_2_chance > 255
        enemy["Item 2 Chance"] = internal_item_2_chance
      when "ooe"
        internal_item_1_chance = item_1_chance
        internal_item_1_chance = 1 if internal_item_1_chance < 1
        internal_item_1_chance = 255 if internal_item_1_chance > 255
        enemy["Item 1 Chance"] = internal_item_1_chance
        
        internal_item_2_chance = item_2_chance
        internal_item_2_chance = 1 if internal_item_2_chance < 1
        internal_item_2_chance = 255 if internal_item_2_chance > 255
        enemy["Item 2 Chance"] = internal_item_2_chance
        
        if enemy["Glyph"] != 0
          # Only give glyph drops to enemies that original had a glyph drop.
          # Other enemies cannot drop a glyph anyway.
          
          if enemy.name.include?("Fomor") || enemy.name.include?("Demon")
            # Fomors and Demons can actually use the glyph you give them, but only if it's a projectile arm glyph.
            enemy["Glyph"] = get_unplaced_non_progression_projectile_glyph() - SKILL_GLOBAL_ID_RANGE.begin + 1
          else
            enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin + 1
          end
          
          if enemy["Glyph Chance"] != 100 # Don't set glyph chance if it was originally 100%, because it won't matter for those enemies.
            internal_skill_chance = skill_chance
            internal_skill_chance = 1 if internal_skill_chance < 1
            internal_skill_chance = 255 if internal_skill_chance > 255
            enemy["Glyph Chance"] = internal_skill_chance
          end
        end
      end
      
      enemy.write_to_rom()
    end
  end
  
  def remove_all_enemy_drops
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy = game.enemy_dnas[enemy_id]
      
      enemy["Item 1"] = 0
      enemy["Item 2"] = 0
      enemy["Soul"] = 0xFF if GAME == "dos"
      
      # Don't remove the glyph from enemies that use glyphs to attack, or they won't be able to attack.
      next if enemy.name.include?("Demon") && enemy.name != "Demon"
      next if enemy.name.include?("Fomor")
      next if ["Necromancer", "Nova Skeleton"].include?(enemy.name)
      enemy["Glyph"] = 0 if GAME == "ooe"
      
      enemy.write_to_rom()
    end
    
    if options[:randomize_enemy_drops] && GAME == "ooe"
      # Randomize the glyphs used by enemies that we couldn't remove them from if the player has randomize enemy drops selected.
      ENEMY_IDS.each do |enemy_id|
        enemy = game.enemy_dnas[enemy_id]
        
        next if enemy.name == "Demon"
        next unless enemy.name.include?("Demon") || enemy.name.include?("Fomor") || ["Necromancer", "Nova Skeleton", "Jiang Shi", "Albus", "Barlowe"].include?(enemy.name)
        
        if enemy.name.include?("Fomor") || enemy.name.include?("Demon")
          # Fomors and Demons can actually use the glyph you give them, but only if it's a projectile arm glyph.
          enemy["Glyph"] = get_unplaced_non_progression_projectile_glyph() - SKILL_GLOBAL_ID_RANGE.begin + 1
        else
          enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin + 1
        end
        
        enemy.write_to_rom()
      end
    end
  end
end
