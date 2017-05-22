
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
    
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy = game.enemy_dnas[enemy_id]
      
      can_drop_items = true
      if GAME == "ooe" && enemy.name == "Blood Skeleton"
        # Blood Skeletons can't be killed so they can't drop items.
        can_drop_items = false
      end
      
      if rng.rand <= 0.5 && can_drop_items # 50% chance to have an item drop
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
          
          if enemy.name.include?("Fomor") || enemy.name.include?("Demon")
            # Fomors and Demons can actually use the glyph you give them, but only if it's a projectile arm glyph.
            enemy["Glyph"] = get_unplaced_non_progression_projectile_glyph() - SKILL_GLOBAL_ID_RANGE.begin + 1
          else
            enemy["Glyph"] = get_unplaced_non_progression_skill() - SKILL_GLOBAL_ID_RANGE.begin + 1
          end
          
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
end
