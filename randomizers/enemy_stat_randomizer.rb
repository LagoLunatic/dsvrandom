
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
      enemy_dna["HP"]               = (enemy_dna["HP"]              *named_rand_range_weighted(stat_mult_range_name)).round
      enemy_dna["MP"]               = (enemy_dna["MP"]              *named_rand_range_weighted(stat_mult_range_name)).round if GAME == "dos"
      enemy_dna["SP"]               = (enemy_dna["SP"]              *named_rand_range_weighted(stat_mult_range_name)).round if GAME == "por"
      enemy_dna["AP"]               = (enemy_dna["AP"]              *named_rand_range_weighted(stat_mult_range_name)).round if GAME == "ooe"
      enemy_dna["EXP"]              = (enemy_dna["EXP"]             *named_rand_range_weighted(stat_mult_range_name)).round
      enemy_dna["Attack"]           = (enemy_dna["Attack"]          *named_rand_range_weighted(stat_mult_range_name)).round
      enemy_dna["Defense"]          = (enemy_dna["Defense"]         *named_rand_range_weighted(stat_mult_range_name)).round if GAME == "dos"
      enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*named_rand_range_weighted(stat_mult_range_name)).round if GAME == "por" || GAME == "ooe"
      enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"] *named_rand_range_weighted(stat_mult_range_name)).round if GAME == "por" || GAME == "ooe"
      
      # Don't let some stats be 0.
      enemy_dna["HP"]               = 1 if enemy_dna["HP"] < 1
      enemy_dna["MP"]               = 1 if GAME == "dos" && enemy_dna["MP"] < 1
      enemy_dna["SP"]               = 1 if GAME == "por" && enemy_dna["SP"] < 1
      enemy_dna["AP"]               = 1 if GAME == "ooe" && enemy_dna["AP"] < 1
      enemy_dna["EXP"]              = 1 if enemy_dna["EXP"] < 1
      enemy_dna["Attack"]           = 1 if enemy_dna["Attack"] < 1
      
      enemy_dna["Blood Color"] = rng.rand(0..8) if GAME == "ooe"
      
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
      
      weakness_names = all_non_status_elements.sample(num_weaknesses)
      resist_names = all_non_status_elements.sample(num_resists)
      
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
          else
            # Status effects for common enemies.
            enemy_dna[bitfield_attr_name][i] = [true, false, false, false, false, false].sample(random: rng)
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
end
