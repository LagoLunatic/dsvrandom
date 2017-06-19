
module EnemyAIRandomizer
  def randomize_enemy_ai
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      
      this_overlay = OVERLAY_FILE_FOR_ENEMY_AI[enemy_dna.enemy_id]
      available_enemies_with_same_overlay = COMMON_ENEMY_IDS.select do |other_enemy_id|
        other_overlay = OVERLAY_FILE_FOR_ENEMY_AI[other_enemy_id]
        other_overlay.nil? || other_overlay == this_overlay
      end
      
      selected_enemy_id = available_enemies_with_same_overlay.sample(random: rng)
      selected_enemy_dna = game.enemy_dnas[selected_enemy_id]
      enemy_dna["Update Code"] = selected_enemy_dna["Update Code"]
      enemy_dna.write_to_rom()
    end
  end
end
