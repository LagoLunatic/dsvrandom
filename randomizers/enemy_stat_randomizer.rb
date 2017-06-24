
module EnemyStatRandomizer
  def randomize_enemy_stats
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      
      is_boss = BOSS_IDS.include?(enemy_id)
      
      if is_boss
        stat_mult_range = @boss_stat_mult_range
      else
        stat_mult_range = @enemy_stat_mult_range
      end
      enemy_dna["HP"]               = (enemy_dna["HP"]              *rng.rand(stat_mult_range)).round
      enemy_dna["MP"]               = (enemy_dna["MP"]              *rng.rand(stat_mult_range)).round if GAME == "dos"
      enemy_dna["SP"]               = (enemy_dna["SP"]              *rng.rand(stat_mult_range)).round if GAME == "por"
      enemy_dna["AP"]               = (enemy_dna["AP"]              *rng.rand(stat_mult_range)).round if GAME == "ooe"
      enemy_dna["EXP"]              = (enemy_dna["EXP"]             *rng.rand(stat_mult_range)).round
      enemy_dna["Attack"]           = (enemy_dna["Attack"]          *rng.rand(stat_mult_range)).round
      enemy_dna["Defense"]          = (enemy_dna["Defense"]         *rng.rand(stat_mult_range)).round if GAME == "dos"
      enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*rng.rand(stat_mult_range)).round if GAME == "por" || GAME == "ooe"
      enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"] *rng.rand(stat_mult_range)).round if GAME == "por" || GAME == "ooe"
      
      # Don't let some stats be 0.
      enemy_dna["HP"]               = 1 if enemy_dna["HP"] < 1
      enemy_dna["MP"]               = 1 if GAME == "dos" && enemy_dna["MP"] < 1
      enemy_dna["SP"]               = 1 if GAME == "por" && enemy_dna["SP"] < 1
      enemy_dna["AP"]               = 1 if GAME == "ooe" && enemy_dna["AP"] < 1
      enemy_dna["EXP"]              = 1 if enemy_dna["EXP"] < 1
      enemy_dna["Attack"]           = 1 if enemy_dna["Attack"] < 1
      
      enemy_dna["Blood Color"] = rng.rand(0..8) if GAME == "ooe"
      
      [
        "Weaknesses",
        "Resistances",
      ].each do |bitfield_attr_name|
        enemy_dna[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Resistance 32" # Something related to rendering its GFX
          
          # Randomize boss elemental weaknesses/resistances, but not status effect weaknesses, etc.
          next if is_boss && i >= 8
          
          enemy_dna[bitfield_attr_name][i] = [true, false, false, false, false, false].sample(random: rng)
          
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
