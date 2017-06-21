
module PlayerRandomizer
  def randomize_players
    players = game.players
    
    players.each do |player|
      player["Walking speed"]       =  rng.rand(0x1400..0x2000)
      player["Jump force"]          = -rng.rand(0x5A00..0x6000)
      player["Double jump force"]   = -rng.rand(0x4A00..0x6000)
      player["Slide force"]         =  rng.rand(0x1800..0x5000)
      player["Backdash force"]      = -rng.rand(0x3800..0x5800)
      player["Backdash friction"]   =  rng.rand(0x100..0x230)
      player["Backdash duration"]   =  rng.rand(20..60)
      player["Trail scale"]         =  rng.rand(0x0D00..0x1200)
      player["Enable player scale"] =  rng.rand(0..1)
      player["Player height scale"] =  player["Trail scale"]
      player["Number of trails"]    =  rng.rand(0x00..0x14)
      
      ["Trail start color", "Trail end color"].each do |attr_name|
        color = 0
        color |= rng.rand(0..0x1F)
        color |= rng.rand(0..0x1F) << 8
        color |= rng.rand(0..0x1F) << 16
        color |= rng.rand(0..0x1F) << 24
        player[attr_name] = color
      end
      
      [
        "Actions",
        "??? bitfield",
        "Damage types",
      ].each do |bitfield_attr_name|
        next if player[bitfield_attr_name].nil?
        
        player[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Horizontal flip"
          next if bit_name == "Is currently AI partner"
          
          if ["Can slide", "Can use weapons", "Can up-pose", "Can absorb glyphs"].include?(bit_name)
            player[bitfield_attr_name][i] = true
            next
          end
          
          player[bitfield_attr_name][i] = [true, false].sample(random: rng)
        end
      end
    end
    
    # Shuffle some player attributes such as graphics
    remaining_players = players.dup
    players.each do |player|
      next unless remaining_players.include?(player) # Already randomized this player
      
      remaining_players.delete(player)
      
      break if remaining_players.empty?
      
      other_player = remaining_players.sample(random: rng)
      remaining_players.delete(other_player)
      
      [
        "GFX list pointer",
        "Sprite pointer",
        "Palette pointer",
        "State anims ptr",
        "GFX asset index",
        "Sprite asset index",
        "Filename pointer",
        "Sprite Y offset",
        "Hitbox pointer",
        "Face icon frame",
        "Palette unknown 1",
        "Palette unknown 2",
      ].each do |attr_name|
        player[attr_name], other_player[attr_name] = other_player[attr_name], player[attr_name]
      end
      
      # Horizontal flip bit
      player["??? bitfield"][0], other_player["??? bitfield"][0] = other_player["??? bitfield"][0], player["??? bitfield"][0]
    end
    
    players.each_with_index do |player, i|
      player["Actions"][1] = true # Can use weapons
      if ["Stella", "Loretta"].include?(player.name)
        player["Actions"][16] = true # No gravity
      else
        player["Actions"][16] = false # No gravity
      end
      if player["Damage types"]
        player["Damage types"][18] = true # Can be hit
      end
      
      player.write_to_rom()
    end
  end
end
