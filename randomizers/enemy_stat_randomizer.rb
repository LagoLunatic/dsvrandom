
module EnemyStatRandomizer
  def randomize_enemy_stats
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      
      is_boss = BOSS_IDS.include?(enemy_id)
      
      if is_boss
        stat_mult_range_name = :boss_stat_mult_range
      else
        stat_mult_range_name = :enemy_stat_mult_range
      end
      enemy_dna["HP"]     = (enemy_dna["HP"]     *named_rand_range_weighted(stat_mult_range_name)).round
      enemy_dna["Attack"] = (enemy_dna["Attack"] *named_rand_range_weighted(stat_mult_range_name)).round
      enemy_dna["Attack"] = 0xFF if enemy_dna["Attack"] > 0xFF
      
      case GAME
      when "dos"
        if enemy_dna["Defense"] == 0 && rng.rand() >= 0.50
          enemy_dna["Defense"] += rng.rand(0..5)
        end
        enemy_dna["Defense"] = (enemy_dna["Defense"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["Defense"] = 0xFF if enemy_dna["Defense"] > 0xFF
      when "por", "ooe"
        if enemy_dna["Physical Defense"] == 0 && rng.rand() >= 0.50
          enemy_dna["Physical Defense"] += rng.rand(0..5)
        end
        if enemy_dna["Magical Defense"] == 0 && rng.rand() >= 0.50
          enemy_dna["Magical Defense"] += rng.rand(0..5)
        end
        
        if rng.rand() >= 0.50
          # 50% chance to change up the enemy's physical and magical defense.
          case rng.rand(1..3)
          when 1
            # Swap phys and magic def.
            enemy_dna["Physical Defense"], enemy_dna["Magical Defense"] = enemy_dna["Magical Defense"], enemy_dna["Physical Defense"]
          when 2
            # Set both phys and magic def to phys def.
            enemy_dna["Physical Defense"], enemy_dna["Magical Defense"] = enemy_dna["Physical Defense"], enemy_dna["Physical Defense"]
          when 3
            # Set both phys and magic def to magic def.
            enemy_dna["Physical Defense"], enemy_dna["Magical Defense"] = enemy_dna["Magical Defense"], enemy_dna["Magical Defense"]
          end
        end
        
        enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["Physical Defense"] = 0xFF if enemy_dna["Physical Defense"] > 0xFF
        enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["Magical Defense"]  = 0xFF if enemy_dna["Magical Defense"] > 0xFF
      end
      
      case GAME
      when "dos"
        enemy_dna["MP"] = (enemy_dna["MP"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["MP"] = 0xFFFF if enemy_dna["MP"] > 0xFFFF
      when "por"
        enemy_dna["SP"] = (enemy_dna["SP"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["SP"] = 0xFF if enemy_dna["SP"] > 0xFF
      when "ooe"
        enemy_dna["AP"] = (enemy_dna["AP"]*named_rand_range_weighted(stat_mult_range_name)).round
        enemy_dna["AP"] = 0xFF if enemy_dna["AP"] > 0xFF
      end
      
      enemy_dna["EXP"] = (enemy_dna["EXP"]*named_rand_range_weighted(stat_mult_range_name)).round
      
      # Don't let some stats be 0.
      enemy_dna["HP"]     = 1 if enemy_dna["HP"] < 1
      enemy_dna["MP"]     = 1 if GAME == "dos" && enemy_dna["MP"] < 1
      enemy_dna["SP"]     = 1 if GAME == "por" && enemy_dna["SP"] < 1
      enemy_dna["AP"]     = 1 if GAME == "ooe" && enemy_dna["AP"] < 1
      enemy_dna["EXP"]    = 1 if enemy_dna["EXP"] < 1
      enemy_dna["Attack"] = 1 if enemy_dna["Attack"] < 1
      
      # Don't let some stats be 5 digits long since they won't display properly in the bestiary.
      enemy_dna["HP"]  = 9999 if enemy_dna["HP"] > 9999
      enemy_dna["EXP"] = 9999 if enemy_dna["EXP"] > 9999
      
      enemy_dna["Blood Color"] = rng.rand(0..8) if GAME == "ooe"
      
      enemy_dna.write_to_rom()
    end
  end
  
  def randomize_enemy_tolerances
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      
      is_boss = BOSS_IDS.include?(enemy_id)
      
      if GAME == "por" && enemy_dna.name == "Death"
        # PoR Death hardcodes his weaknesses and resists, so don't both randomizing them
        next
      end
      
      if GAME == "ooe"
        all_non_status_elements = ENEMY_DNA_BITFIELD_ATTRIBUTES["Weaknesses"][0,7]
      else
        all_non_status_elements = ENEMY_DNA_BITFIELD_ATTRIBUTES["Weaknesses"][0,8]
      end
      
      if is_boss
        # Make sure bosses have the same number of weaknesses/resistances as they originally did.
        
        orig_num_weaknesses = 0
        all_non_status_elements.each_with_index do |name, i|
          if enemy_dna["Weaknesses"][i]
            orig_num_weaknesses += 1
          end
        end
        
        orig_num_resists = 0
        all_non_status_elements.each_with_index do |name, i|
          if enemy_dna["Resistances"][i]
            orig_num_resists += 1
          end
        end
        
        num_weaknesses = orig_num_weaknesses
        num_resists = orig_num_resists
      else
        num_weaknesses = named_rand_range_weighted(:enemy_num_weaknesses_range)
        num_resists = named_rand_range_weighted(:enemy_num_resistances_range)
      end
      
      weakness_names = all_non_status_elements.sample(num_weaknesses, random: rng)
      resist_names = all_non_status_elements.sample(num_resists, random: rng)
      
      # Don't allow an enemy to both be weak to and resist the same element.
      # Random 50% chance whether we will make it weak or resist.
      (weakness_names & resist_names).each do |element|
        if rng.rand < 0.5
          weakness_names.delete(element)
        else
          resist_names.delete(element)
        end
      end
      
      [
        "Weaknesses",
        "Resistances",
      ].each do |bitfield_attr_name|
        enemy_dna[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Resistance 32" # Something related to rendering its GFX
          
          if all_non_status_elements.include?(bit_name)
            if bitfield_attr_name == "Weaknesses" && weakness_names.include?(bit_name) || bitfield_attr_name == "Resistances" && resist_names.include?(bit_name)
              enemy_dna[bitfield_attr_name][i] = true
            else
              enemy_dna[bitfield_attr_name][i] = false
            end
          elsif is_boss
            # Don't randomize boss status effect weaknesses.
            next
          elsif GAME == "por" && bitfield_attr_name == "Resistances" && [25, 26].include?(i)
            # Deflect subweapons/Deflect spells bits.
            if rng.rand() <= 0.10
              enemy_dna[bitfield_attr_name][i] = true
            else
              enemy_dna[bitfield_attr_name][i] = false
            end
          else
            # Status effects for common enemies.
            if GAME == "dos" || bitfield_attr_name == "Weaknesses" # Don't set status effect resists in PoR/OoE since they do nothing anyway.
              enemy_dna[bitfield_attr_name][i] = [true, false, false, false, false, false].sample(random: rng)
            end
          end
          
          if bitfield_attr_name == "Resistances" && enemy_dna["Weaknesses"][i] == true
            # Don't set both the weakness and resistance bits for a given element.
            # Depending on the game this can be somewhat buggy.
            enemy_dna["Resistances"][i] = false
          end
        end
      end
      
      enemy_dna.write_to_rom()
    end
  end
  
  def update_hardcoded_enemy_attributes
    # Updates some stats hardcoded by certain enemies.
    
    case GAME
    when "por"
      enemy_id = 0x90
      death = game.enemy_dnas[enemy_id]
      game.fs.load_overlay(OVERLAY_FILE_FOR_ENEMY_AI[enemy_id])
      phys_def = death["Physical Defense"]
      mag_def = death["Magical Defense"]
      
      game.fs.write(0x022DB348, [mag_def].pack("C")) # Phys def in purple form
      game.fs.write(0x022DB344, [mag_def/2].pack("C")) # Phys def in purple form for richter/old axe armor hard mode
      game.fs.write(0x022DB368, [phys_def].pack("C")) # Mag def in purple form
      game.fs.write(0x022D7B5C, [mag_def].pack("C")) # Phys def in purple form
      game.fs.write(0x022D7B58, [mag_def/2].pack("C")) # Phys def in purple form for richter/old axe armor hard mode
      game.fs.write(0x022D7B7C, [phys_def].pack("C")) # Mag def in purple form
      game.fs.write(0x022DB2DC, [phys_def].pack("C")) # Phys def in white form
      game.fs.write(0x022DB2F0, [mag_def].pack("C")) # Mag def in white form
    end
  end
end
