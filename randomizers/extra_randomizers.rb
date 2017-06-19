
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
      enemy_dna["Update Code"] = selected_enemy_dna["Update Code"]
      enemy_dna.write_to_rom()
    end
  end
  
  def get_n_damage_types(all_damage_types, possible_n_values)
    known_damage_type_names = all_damage_types.select{|name| name !~ /\d$/}
    normal_damage_types = all_damage_types[0,8] & known_damage_type_names
    known_damage_type_names += normal_damage_types # Double the chance of normal damage types compared to status effects and other bits.
    num_damage_types = possible_n_values.sample(random: rng)
    damage_types_to_set = known_damage_type_names.sample(num_damage_types)
    damage_types_to_set
  end
  
  def randomize_item_stats
    (ITEM_GLOBAL_ID_RANGE.to_a - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS).each do |item_global_id|
      item = game.items[item_global_id]
      
      progress_item = checker.all_progression_pickups.include?(item_global_id)
      
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
      
      if progress_item
        # Always make progression items be worth 0 gold so they can't be sold on accident.
        item["Price"] = 0
      elsif item.name == "CASTLE MAP 1" && GAME == "por"
        # Don't randomize castle map 1 in PoR so it doesn't cost a lot to buy for the first quest.
      else
        item["Price"] = rand_range_weighted_very_low(1..250)*100
      end
      
      description = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
      
      case item.item_type_name
      when "Consumables"
        case GAME
        when "dos", "por"
          possible_types = (0..0x8).to_a
          possible_types -= [4, 5, 6] # Don't allow unusable items
          possible_types += [0, 0, 0, 0, 0, 0, 1, 1, 2] # Increase chances of some item types
          possible_types -= [7, 8] # Don't allow max ups, only certain items we already chose earlier may be max ups.
          # Don't allow potions/mind ups to subtract HP
          if (0..5).include?(item["Item ID"])
            possible_types.delete(3)
          end
          
          if progress_item
            # Always make progression items unusable so the player can't accidentally eat one and softlock themself.
            possible_types = [4]
          end
          
          if @max_up_items[0] == item["Item ID"]
            # HP Max Up
            possible_types = [7]
          elsif @max_up_items[1] == item["Item ID"]
            # MP Max Up
            possible_types = [8]
          end
          
          item["Type"] = possible_types.sample(random: rng)
          
          case item["Type"]
          when 0, 1, 3 # Restores HP/restores MP/subtracts HP
            item["Var A"] = rand_range_weighted_very_low(1..1000)
          when 2 # Cures status effect
            item["Var A"] = [1, 1, 1, 2, 2, 2, 4].sample(random: rng)
          end
          
          case item["Type"]
          when 0
            description.decoded_string = "Restores #{item["Var A"]} HP."
          when 1
            description.decoded_string = "Restores #{item["Var A"]} MP."
          when 2
            case item["Var A"]
            when 1
              description.decoded_string = "Cures poison."
            when 2
              description.decoded_string = "Nullifies curse."
            when 4
              description.decoded_string = "Cures petrify."
            end
          when 3
            description.decoded_string = "Subtracts #{item["Var A"]} HP."
          when 7
            description.decoded_string = "HP Max up."
          when 8
            description.decoded_string = "MP Max up."
          end
        when "ooe"
          possible_types = (0..0xB).to_a
          possible_types -= [4, 5, 6] # Don't allow max ups, only certain items we already chose earlier may be max ups.
          possible_types -= [8] # Don't allow unusable items
          unless (0x75..0xAC).include?(item["Item ID"])
            possible_types -= [9] # Don't allow records unless it will actually play a song.
          end
          possible_types -= [0xB] # Don't allow attribute point increases because I don't fully understand them yet TODO
          possible_types += [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 3, 3] # Increase chances of some item types
          # Don't allow potions/mind ups/heart repairs to subtract HP
          if (0x75..0x7B).include?(item["Item ID"])
            possible_types.delete(7)
          end
          
          if progress_item
            # Always make progression items unusable so the player can't accidentally eat one and softlock themself.
            possible_types = [4]
          end
          
          if @max_up_items[0] == item["Item ID"]
            # HP Max Up
            possible_types = [4]
          elsif @max_up_items[1] == item["Item ID"]
            # MP Max Up
            possible_types = [5]
          elsif @max_up_items[2] == item["Item ID"]
            # HEART Max Up
            possible_types = [6]
          end
          
          item["Type"] = possible_types.sample(random: rng)
          
          case item["Type"]
          when 0, 1, 7 # Restores HP/restores MP/subtracts HP
            item["Var A"] = rand_range_weighted_very_low(1..1000)
          when 2 # Restores hearts
            item["Var A"] = rand_range_weighted_very_low(1..350)
          when 3 # Cures status effect
            item["Var A"] = [1, 1, 1, 2, 2, 2, 4].sample(random: rng)
          end
          
          case item["Type"]
          when 0
            description.decoded_string = "Restores #{item["Var A"]} HP."
          when 1
            description.decoded_string = "Restores #{item["Var A"]} MP."
          when 2
            description.decoded_string = "Restores #{item["Var A"]} hearts."
          when 3
            case item["Var A"]
            when 1
              description.decoded_string = "Cures poison."
            when 2
              description.decoded_string = "Nullifies curse."
            when 4
              description.decoded_string = "Cures petrify."
            end
          when 4
            description.decoded_string = "Increases your maximum HP."
          when 5
            description.decoded_string = "Increases your maximum MP."
          when 6
            description.decoded_string = "Increases your heart maximum."
          when 7
            description.decoded_string = "Subtracts #{item["Var A"]} HP."
          when 9
            description.decoded_string = "Adjust the background music to your liking."
          when 0xA
            description.decoded_string = "A one-way pass to return to the village immediately."
          when 0xB
            description.decoded_string = "Increases your attribute points."
          end
        end
      when "Weapons"
        item["Attack"] = rand_range_weighted_very_low(0..150)
        
        extra_stats = ["Defense", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted_very_low(0..total_num_extra_stats)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = rand_range_weighted_low(1..100, weight_exponent: 4)
        end
        
        item["IFrames"] = rng.rand(4..55)
        
        case GAME
        when "dos"
          unless [9, 0xA, 0xB].include?(item["Swing Anim"])
            # Only randomize swing anim if it wasn't originally a throwing/firing weapon.
            # Throwing/firing weapon sprites have no hitbox, so they won't be able to damage anything if they don't remain a throwing/firing weapon.
            item["Swing Anim"] = rng.rand(0..0xC)
          end
          item["Super Anim"] = rng.rand(0..0xE) unless progress_item
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
          
          unless progress_item
            palette = item["Crit type/Palette"] & 0xC0
            crit_type = rng.rand(0..0x13)
            item["Crit type/Palette"] = palette | crit_type
          end
          
          if item.name == "Heaven's Sword" || item.name == "Tori"
            item["Special Effect"] = [1, 5, 6, 7].sample(random: rng)
          elsif rng.rand <= 0.50 # 50% chance to have a special effect
            item["Special Effect"] = rng.rand(1..7)
          else
            item["Special Effect"] = 0
          end
        end
        
        player_can_move = nil
        item["Swing Modifiers"].names.each_with_index do |bit_name, i|
          next if bit_name == "Shaky weapon" && GAME == "dos" # This makes the weapon appear too high up
          
          item["Swing Modifiers"][i] = [true, false, false, false].sample(random: rng)
          
          if GAME == "dos" && item["Swing Anim"] == 0xA && bit_name == "Player can move"
            # This bit must be set for throwing weapons in DoS or they won't appear.
            item["Swing Modifiers"][i] = true
          end
          
          if bit_name == "Player can move"
            player_can_move = item["Swing Modifiers"][i]
          end
          
          if bit_name == "No interrupt on anim end" && player_can_move
            # This no interrupt must be set if the player can move during the anim, or the weapon won't swing.
            item["Swing Modifiers"][i] = true
          end
        end
        
        damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,16], [1, 1, 1, 2, 2, 3, 4])
        damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        item["Effects"].names.each_with_index do |bit_name, i|
          if damage_types_to_set.include?(bit_name)
            item["Effects"][i] = true
          else
            item["Effects"][i] = false
          end
          
          if bit_name == "Cures vampirism & kills undead" && item["Effects"][i] == true
            # Don't give this weapon the magical bit if it has the cures vampirism bit because we don't want it to cure the sisters.
            item["Effects"][26] = false # Magical
          end
        end
        
        if item["Special Effect"] == 6
          # Illusion fist effect overrides damage types bitfield.
          # Therefore we set the damage types bitfield to match so it at least displays the correct values.
          item["Effects"].value = 4 # Slash
        end
        
        if item["Special Effect"] == 5
          # The Heaven Sword "throw the weapon in front of you" effect only uses the first frame of the weapon's sprite.
          # If the first frame has no hitbox the weapon won't be able to hit enemies.
          # So we reorder the frames so that one with a hitbox is first.
          weapon_gfx = WeaponGfx.new(item["Sprite"], game.fs)
          sprite = Sprite.new(weapon_gfx.sprite_file_pointer, game.fs)
          possible_frames = sprite.frames.select{|frame| frame.hitboxes.any?}
          if possible_frames.any?
            # Select the first frame with a hitbox.
            frame = possible_frames.first
            # Move that frame to the front.
            sprite.frames.delete(frame)
            sprite.frames.unshift(frame)
            sprite.write_to_rom()
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
        
        damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Resistances"], [0, 0, 0, 0, 0, 0, 1])
        item["Resistances"].names.each_with_index do |bit_name, i|
          if damage_types_to_set.include?(bit_name)
            item["Resistances"][i] = true
          else
            item["Resistances"][i] = false
          end
        end
      end
      
      item.write_to_rom()
    end
    
    game.text_database.write_to_rom()
  end
  
  def randomize_skill_stats
    SKILL_GLOBAL_ID_RANGE.each do |skill_global_id|
      skill = game.items[skill_global_id]
      
      progress_skill = !all_non_progression_pickups.include?(skill_global_id)
      
      if @ooe_starter_glyph_id
        next if skill_global_id == @ooe_starter_glyph_id
      else
        next if skill.name == "Confodere"
      end
      
      if GAME == "por" && (0x1A2..0x1AB).include?(skill_global_id)
        # Dual crush
        skill["Mana cost"] = rng.rand(50..250) unless progress_skill
        skill["DMG multiplier"] = rand_range_weighted_low(15..85)
      elsif GAME == "ooe" && (0x50..0x6E).include?(skill_global_id)
        # Glyph union
        skill["Heart cost"] = rand_range_weighted_low(5..50)
        skill["DMG multiplier"] = rand_range_weighted_low(15..85)
        
        skill["Heart cost"] = 0 if skill_global_id == 0x68 # Dominus union shouldn't cost hearts
      else
        skill["Mana cost"] = rng.rand(1..60) unless progress_skill
        skill["DMG multiplier"] = rand_range_weighted_low(5..55, weight_exponent: 3)
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
        if (0xCE..0x102).include?(skill_global_id) && !progress_skill
          soul_extra_data = game.items[skill_global_id+0x7B]
          soul_extra_data["Max at once"] = rand_range_weighted_low(1..3)
          soul_extra_data["Bonus max at once"] = rand_range_weighted_low(0..2)
          soul_extra_data.write_to_rom()
        end
      when "por"
        if (0x150..0x1A0).include?(skill_global_id)
          skill_extra_data = game.items[skill_global_id+0x6C]
          
          unless progress_skill
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
        
        skill["IFrames"] = rand_range_weighted_low(4..55)
        skill["Delay"] = rand_range_weighted_low(1..20) unless progress_skill
      end
      
      damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,16], [1, 1, 1, 2, 2, 3, 4])
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      skill["Effects"].names.each_with_index do |bit_name, i|
        if bit_name == "Cures vampirism & kills undead"
          # Don't want to randomize this or Sanctuary won't work. Also don't want to give any other spells besides Sanctuary this.
          next
        end
        
        if damage_types_to_set.include?(bit_name)
          skill["Effects"][i] = true
        else
          skill["Effects"][i] = false
        end
        
        if bit_name == "Magical" && skill.name == "Sanctuary"
          # Always make sure Sanctuary has the magical bit set, in case it's a Jonathan skill and it doesn't get set automatically.
          skill["Effects"][i] = true
        end
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
    COMMON_ENEMY_IDS.each do |enemy_id|
      enemy_dna = game.enemy_dnas[enemy_id]
      
      min_mult = 0.5
      max_mult = 2.5
      enemy_dna["HP"]               = (enemy_dna["HP"]              *rng.rand(min_mult..max_mult)).round
      enemy_dna["MP"]               = (enemy_dna["MP"]              *rng.rand(min_mult..max_mult)).round if GAME == "dos"
      enemy_dna["SP"]               = (enemy_dna["SP"]              *rng.rand(min_mult..max_mult)).round if GAME == "por"
      enemy_dna["AP"]               = (enemy_dna["AP"]              *rng.rand(min_mult..max_mult)).round if GAME == "ooe"
      enemy_dna["EXP"]              = (enemy_dna["EXP"]             *rng.rand(min_mult..max_mult)).round
      enemy_dna["Attack"]           = (enemy_dna["Attack"]          *rng.rand(min_mult..max_mult)).round
      enemy_dna["Defense"]          = (enemy_dna["Defense"]         *rng.rand(min_mult..max_mult)).round if GAME == "dos"
      enemy_dna["Physical Defense"] = (enemy_dna["Physical Defense"]*rng.rand(min_mult..max_mult)).round if GAME == "por" || GAME == "ooe"
      enemy_dna["Magical Defense"]  = (enemy_dna["Magical Defense"] *rng.rand(min_mult..max_mult)).round if GAME == "por" || GAME == "ooe"
      
      enemy_dna["Blood Color"] = rng.rand(0..8) if GAME == "ooe"
      
      [
        "Weaknesses",
        "Resistances",
      ].each do |bitfield_attr_name|
        enemy_dna[bitfield_attr_name].names.each_with_index do |bit_name, i|
          next if bit_name == "Resistance 32" # Something related to rendering its GFX
          
          enemy_dna[bitfield_attr_name][i] = [true, false, false, false, false, false, false, false, false].sample(random: rng)
          
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
    
    available_souls = all_non_progression_pickups & SKILL_GLOBAL_ID_RANGE.to_a
    available_souls.map!{|global_id| global_id - 0xCE}
    
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
        synth.required_soul_id = available_souls.sample(random: rng)
        synth.created_item_id = created_item + 1
        
        synth.write_to_rom()
      end
    end
  end
end
