
module ExtraRandomizers
  def randomize_starting_room
    rooms = []
    game.each_room do |room|
      next if room.layers.length == 0
      next if room.doors.length == 0
      
      next if room.area.name.include?("Boss Rush")
      
      next if room.sector.name.include?("Boss Rush")
      
      rooms << room
    end
    
    room = rooms.sample(random: rng)
    game.set_starting_room(room.area_index, room.sector_index, room.room_index)
  end
  
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
      enemy_dna["Running AI"] = selected_enemy_dna["Running AI"]
      enemy_dna.write_to_rom()
    end
  end
  
  def randomize_item_stats
    game.items[ITEM_GLOBAL_ID_RANGE].each do |item|
      # Don't randomize unequip/starting items.
      if item.name == "---" || item.name == "Bare knuckles" || item.name == "Casual Clothes" || item.name == "Encyclopedia"
        next
      end
      case GAME
      when "dos"
        next if item.name == "Knife"
      when "por"
        next if item["Item ID"] == 0x61 # starting Vampire Killer
      end
      
      if checker.all_progression_pickups.include?(item["Item ID"])
        # Don't randomize the price of progression items so they can't be sold on accident.
      elsif item.name == "CASTLE MAP 1" && GAME == "por"
        # Also so castle map 1 in PoR doesn't cost a lot to buy.
      else
        item["Price"] = rand_range_weighted_very_low(1..250)*100
      end
      
      case item.item_type_name
      when "Consumables"
        case GAME
        when "dos", "por"
          possible_types = (0..0x8).to_a
          possible_types -= [4, 5, 6] # Don't allow unusable items
          possible_types += [0, 0, 0, 1, 7, 8] # Increase chances of some item types
          if GAME == "dos"
            # No HP/MP max ups in DoS
            possible_types.delete(7)
            possible_types.delete(8)
          end
          # Don't allow potions/mind ups to subtract HP
          if (0..5).include?(item["Item ID"])
            possible_types.delete(3)
          end
          
          if checker.all_progression_pickups.include?(item["Item ID"])
            # Always make progression items unusable so the player can't accidentally eat one and softlock themself.
            possible_types = [4]
          end
          
          item["Type"] = possible_types.sample(random: rng)
          
          case item["Type"]
          when 0, 1, 3 # Restores HP/restores MP/subtracts HP
            item["Var A"] = rand_range_weighted_very_low(1..4000)
          when 2 # Cures status effect
            item["Var A"] = [1, 2].sample(random: rng)
          end
        when "ooe"
          possible_types = (0..0xB).to_a
          possible_types -= [8] # Don't allow unusable items
          unless (0x75..0xAC).include?(item["Item ID"])
            possible_types -= [9] # Don't allow records unless it will actually play a song.
          end
          possible_types -= [0xB] # Don't allow attribute point increases because I don't fully understand them yet TODO
          possible_types += [0, 0, 0, 0, 0, 1, 2, 2, 3, 3, 4, 5] # Increase chances of some item types
          # Don't allow potions/mind ups/heart repairs to subtract HP
          if (0x75..0x7B).include?(item["Item ID"])
            possible_types.delete(7)
          end
          
          item["Type"] = possible_types.sample(random: rng)
          
          case item["Type"]
          when 0, 1, 7 # Restores HP/restores MP/subtracts HP
            item["Var A"] = rand_range_weighted_very_low(1..4000)
          when 2 # Restores hearts
            item["Var A"] = rand_range_weighted_low(1..500)
          when 3 # Cures status effect
            item["Var A"] = [1, 1, 1, 2, 2, 2, 4].sample(random: rng)
          end
        end
      when "Weapons"
        item["Attack"] = rand_range_weighted_very_low(0..150)
        
        extra_stats = ["Defense", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted_very_low(0..total_num_extra_stats)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = rand_range_weighted_very_low(1..10)
        end
        
        item["IFrames"] = rng.rand(4..45)
        
        case GAME
        when "dos"
          unless item["Swing Anim"] == 0xA
            # Only randomize swing anim if it wasn't originally a throwing weapon.
            # Throwing weapon sprite anims are super short (like 1 frame) so they won't work if they're not still a throwing weapon.
            item["Swing Anim"] = rng.rand(0..0xC)
          end
          item["Super Anim"] = rng.rand(0..0xE)
        when "por"
          if [0x61, 0x6C].include?(item["Item ID"]) || item.name == "---"
            # Don't randomize who can equip the weapons Jonathan and Charlotte start out already equipped with, or the --- unequipped placeholder.
          else
            # 1/8 chance to be a weapon for Charlotte, otherwise for Jonathan.
            item["Equippable by"].value = [1, 1, 1, 1, 1, 1, 1, 2].sample(random: rng)
          end
          
          if item["Equippable by"].value == 1
            # Jonathan swing anims.
            item["Swing Anim"] = rng.rand(0..8)
          else
            # Charlotte swing anim.
            item["Swing Anim"] = 9
          end
          
          item["Crit type/Palette"] = rng.rand(0..0x13)
          item["Graphical Effect"] = rng.rand(0..7)
        end
        
        [
          "Effects",
          "Swing Modifiers",
        ].each do |bitfield_attr_name|
          player_can_move = nil
          
          item[bitfield_attr_name].names.each_with_index do |bit_name, i|
            next if bit_name == "Shaky weapon" && GAME == "dos" # This makes the weapon appear too high up
            
            item[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
            
            if item["Swing Anim"] == 0xA && bit_name == "Player can move"
              # This bit must be set for throwing weapons in DoS or they won't appear.
              item[bitfield_attr_name][i] = true
            end
            
            if bit_name == "Player can move"
              player_can_move = item[bitfield_attr_name][i]
            end
            
            if bit_name == "No interrupt on anim end" && player_can_move
              # This no interrupt must be set if the player can move during the anim, or the weapon won't swing.
              item[bitfield_attr_name][i] = true
            end
            
            if bit_name == "Cures vampirism & kills undead" && item[bitfield_attr_name][i] == true
              # Don't give this weapon the magical bit if it has the cures vampirism bit because we don't want it to cure the sisters.
              item[bitfield_attr_name][26] = false # Magical
            end
          end
        end
      when "Armor", "Body Armor", "Head Armor", "Leg Armor", "Accessories"
        item["Defense"] = rand_range_weighted_very_low(0..40)
        
        extra_stats = ["Attack", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted_very_low(0..total_num_extra_stats)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = rand_range_weighted_very_low(1..10)
        end
        
        unless item.name == "Casual Clothes"
          item["Equippable by"].value = rng.rand(1..3) if GAME == "por"
        end
        
        [
          "Resistances",
        ].each do |bitfield_attr_name|
          item[bitfield_attr_name].names.each_with_index do |bit_name, i|
            item[bitfield_attr_name][i] = [true, false, false, false, false, false, false, false, false].sample(random: rng)
          end
        end
      end
      
      item.write_to_rom()
    end
  end
  
  def randomize_skill_stats
    (SKILL_GLOBAL_ID_RANGE.to_a & all_non_progression_pickups).each do |skill_global_id|
      skill = game.items[skill_global_id]
      
      if @ooe_starter_glyph_id
        next if skill_global_id == @ooe_starter_glyph_id
      else
        next if skill.name == "Confodere"
      end
      
      if GAME == "por" && (0x1A2..0x1AB).include?(skill_global_id)
        # Dual crush
        skill["Mana cost"] = rng.rand(50..250)
        skill["DMG multiplier"] = rand_range_weighted_low(15..85)
      elsif GAME == "ooe" && (0x50..0x6E).include?(skill_global_id)
        # Glyph union
        skill["Heart cost"] = rand_range_weighted_low(5..50)
        skill["DMG multiplier"] = rand_range_weighted_low(15..55)
      else
        skill["Mana cost"] = rng.rand(1..60)
        skill["DMG multiplier"] = rand_range_weighted_very_low(1..35)
      end
      
      skill["Soul Scaling"] = rng.rand(0..4) if GAME == "dos"
      
      if skill["?/Swings/Union"]
        union_type = skill["?/Swings/Union"]
        if union_type != 0x13 # Don't randomize Dominus glyphs (union type 13)
          union_type = rng.rand(0x01..0x12)
          low_two_bits = skill["?/Swings/Union"] & 0b11
          skill["?/Swings/Union"] = (union_type << 2) | low_two_bits
        end
      end
      
      if GAME == "por" && skill["Type"] == 0
        skills_that_must_be_used_by_original_player = [
          "Stonewall",
          "Wrecking Ball",
          "Rampage",
          "Toad Morph",
          "Owl Morph",
          "Speed Up",
          "Berserker",
          "STR Boost",
          "CON Boost",
          "INT Boost",
          "MIND Boost",
          "LUCK Boost",
          "ALL Boost",
        ]
        
        unless skills_that_must_be_used_by_original_player.include?(skill.name)
          # Randomize whether this skill is usable by Jonathan or Charlotte.
          # Except for the above listed skills, since the wrong character can't actually use them.
          skill["??? bitfield"][2] = [true, false].sample(random: rng)
        end
      end
      
      case GAME
      when "dos"
        if (0xCE..0x102).include?(skill_global_id)
          soul_extra_data = game.items[skill_global_id+0x7B]
          soul_extra_data["Max at once"] = rand_range_weighted_low(1..3)
          soul_extra_data["Bonus max at once"] = rand_range_weighted_low(0..2)
          soul_extra_data.write_to_rom()
        end
      when "por"
        if (0x150..0x1A0).include?(skill_global_id)
          skill_extra_data = game.items[skill_global_id+0x6C]
          
          max_at_once = rand_range_weighted_low(1..8)
          is_spell = skill["??? bitfield"][2]
          if is_spell
            charge_time = rand_range_weighted_very_low(8..120)
            skill_extra_data["Max at once/Spell charge"] = (charge_time<<4) | max_at_once
            skill_extra_data["SP to Master"] = 0
          else
            mastered_bonus_max_at_once = rand_range_weighted_low(1..6)
            skill_extra_data["Max at once/Spell charge"] = (mastered_bonus_max_at_once<<4) | max_at_once
            skill_extra_data["SP to Master"] = rng.rand(1..30)*100
          end
          
          skill_extra_data["Price (1000G)"] = rand_range_weighted_low(1..30)
          
          skill_extra_data.write_to_rom()
        end
      when "ooe"
        if (0x37..0x4E).include?(skill_global_id)
          # Back glyphs can't be properly toggled off if max at once is greater than 1. (Except Agartha.)
          skill["Max at once"] = 1
        else
          skill["Max at once"] = rand_range_weighted_low(1..6)
        end
        
        skill["IFrames"] = rand_range_weighted_low(1..0x24)
        skill["Delay"] = rand_range_weighted_low(0..14)
      end
      
      skill["Effects"].names.each_with_index do |bit_name, i|
        if bit_name == "Cures vampirism & kills undead"
          # Don't want to randomize this or Sanctuary won't work. Also don't want to give any other spells besides Sanctuary this.
          next
        end
        if bit_name == "Magical" && skill.name == "Sanctuary"
          # Always make sure Sanctuary has the magical bit set, in case it's a Jonathan skill and it doesn't get set automatically.
          skill["Effects"][i] = true
          next
        end
        skill["Effects"][i] = [true, false, false, false].sample(random: rng)
      end
      
      skill["Unwanted States"].names.each_with_index do |bit_name, i|
        # 50% chance to make a state that was originally not allowed be allowed.
        # But don't make a state that was originally allowed be not allowed.
        next if skill["Unwanted States"][i] == false
        skill["Unwanted States"][i] = [true, false].sample(random: rng)
      end
      
      skill.write_to_rom()
    end
  end
  
  def randomize_enemy_stats
    game.enemy_dnas.each_with_index do |enemy_dna, enemy_id|
      enemy_dna["HP"]      = (enemy_dna["HP"]*rng.rand(0.5..3.0)).round
      enemy_dna["MP"]      = (enemy_dna["MP"]*rng.rand(0.5..3.0)).round if GAME == "dos"
      enemy_dna["SP"]      = (enemy_dna["SP"]*rng.rand(0.5..3.0)).round if GAME == "por"
      enemy_dna["AP"]      = (enemy_dna["AP"]*rng.rand(0.5..3.0)).round if GAME == "ooe"
      enemy_dna["EXP"]     = (enemy_dna["EXP"]*rng.rand(0.5..3.0)).round
      enemy_dna["Attack"]  = (enemy_dna["Attack"]*rng.rand(0.5..3.0)).round
      enemy_dna["Defense"] = (enemy_dna["Defense"]*rng.rand(0.5..3.0)).round if GAME == "dos"
      enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*rng.rand(0.5..3.0)).round if GAME == "por" || GAME == "ooe"
      enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"]*rng.rand(0.5..3.0)).round if GAME == "por" || GAME == "ooe"
      
      enemy_dna["Blood Color"] = rng.rand(0..8) if GAME == "ooe"
      
      [
        "Weaknesses",
        "Resistances",
      ].each do |bitfield_attr_name|
        enemy_dna[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Resistance 32" # Something related to rendering its GFX
          
          if BOSS_IDS.include?(enemy_id) && ["Curse", "Stone", "Torpor"].include?(bit_name) && bitfield_attr_name == "Weaknesses"
            # Don't let bosses be cursed/stoned/torpored, because some bosses will softlock the game if this happens.
            # TODO: Test every boss to see which ones do and don't softlock the game, and only disable these bits for those bosses.
            next
          end
          
          enemy_dna[bitfield_attr_name][i] = [true, false, false, false].sample(random: rng)
          
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
  
  def randomize_weapon_synths
    return unless GAME == "dos"
    
    items_by_type = []
    items_by_type << (0x00..0x41).to_a # Consumables
    items_by_type << (0x42..0x90).to_a # Weapons
    items_by_type << (0x91..0xAE).to_a # Body armor
    items_by_type << (0xAF..0xCD).to_a # Accessories
    items_by_type.map! do |item_list_for_type|
      item_list_for_type & all_non_progression_pickups
    end
    
    WEAPON_SYNTH_CHAIN_NAMES.each_index do |index|
      chain = WeaponSynthChain.new(index, game.fs)
      
      item_types_with_enough_items = items_by_type.select do |item_list_for_type|
        item_list_for_type.length >= chain.synths.length*2
      end
      items_available_for_this_chain = item_types_with_enough_items.sample(random: rng)#.dup
      
      chain.synths.each do |synth|
        req_item = items_available_for_this_chain.sample(random: rng)
        items_available_for_this_chain.delete(req_item)
        created_item = items_available_for_this_chain.sample(random: rng)
        items_available_for_this_chain.delete(created_item)
        
        synth.required_item_id = req_item + 1
        synth.required_soul_id = rng.rand(SKILL_LOCAL_ID_RANGE)
        synth.created_item_id = created_item + 1
        
        synth.write_to_rom()
      end
    end
  end
end
