
module ItemSkillStatRandomizer
  def get_n_damage_types(all_damage_types, possible_n_values)
    known_damage_type_names = all_damage_types.select{|name| name !~ /\d$/}
    num_damage_types = possible_n_values.sample(random: rng)
    damage_types_to_set = known_damage_type_names.sample(num_damage_types, random: rng)
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
        item["Price"] = named_rand_range_weighted(:item_price_range)/100*100
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
            item["Var A"] = named_rand_range_weighted(:restorative_amount_range)
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
          possible_types = (0..0xA).to_a
          possible_types -= [4, 5, 6] # Don't allow max ups, only certain items we already chose earlier may be max ups.
          possible_types -= [8] # Don't allow unusable items
          unless (0x75..0xAC).include?(item["Item ID"])
            possible_types -= [9] # Don't allow records unless it will actually play a song.
          end
          possible_types += [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 3, 3] # Increase chances of some item types
          # Don't allow potions/mind ups/heart repairs to subtract HP
          if (0x75..0x7B).include?(item["Item ID"])
            possible_types.delete(7)
          end
          
          if (0x9C..0xA0).include?(item["Item ID"]) && rng.rand >= 0.60
            # Drops. These are the only ones that can be AP increasers, so give them a 60% to be an AP increaser.
            possible_types = [0xB]
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
            item["Var A"] = named_rand_range_weighted(:restorative_amount_range)
          when 2 # Restores hearts
            item["Var A"] = named_rand_range_weighted(:heart_restorative_amount_range)
          when 3 # Cures status effect
            item["Var A"] = [1, 1, 1, 2, 2, 2, 4].sample(random: rng)
          when 0xB # Increases AP
            item["Var A"] = named_rand_range_weighted(:ap_increase_amount_range)
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
            description.decoded_string = "Adjust the background music\\nto your liking."
          when 0xA
            description.decoded_string = "A one-way pass to return\\nto the village immediately."
          when 0xB
            ap_types = %w(flame ice lightning light dark)
            ap_type_index = item["Item ID"]-0x9C
            ap_type = ap_types[ap_type_index]
            description.decoded_string = "Increases your #{ap_type}\\nattribute points by #{item["Var A"]}."
          end
        end
      when "Weapons"
        item["Attack"] = named_rand_range_weighted(:weapon_attack_range)
        
        extra_stats = ["Defense", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted(0..total_num_extra_stats, average: 1)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = named_rand_range_weighted(:item_extra_stats_range)
          if item[stat_name] < 0 && stat_name == "Defense"
            # Defense is unsigned
            item[stat_name] = 0
          end
        end
        
        item["IFrames"] = named_rand_range_weighted(:weapon_iframes_range)
        
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
          elsif item["Equippable by"].value == 1 && progress_item
            # Don't randomize Jonathan's glitch progress weapons (Cinquedia, Axe, etc) to be for Charlotte because Charlotte may not be accessible with "Don't randomize Change Cube".
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
        
        
        if rng.rand() >= 0.30
          # Increase the chance of a pure physical weapon.
          damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,2], [1, 1, 1, 1, 1, 2, 3])
        else
          damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,8], [1, 1, 1, 2, 2, 3, 4])
        end
        
        if damage_types_to_set.length < 4 && rng.rand() <= 0.10
          # 10% chance to add a status effect.
          damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][8,8], [1])
        end
        
        # Add extra bits.
        damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
        
        item["Effects"].names.each_with_index do |bit_name, i|
          if damage_types_to_set.include?(bit_name)
            item["Effects"][i] = true
          else
            item["Effects"][i] = false
          end
          
          if bit_name == "Cures vampirism & kills undead" && item["Effects"][i] == true
            # Don't give this weapon the spell bit if it has the cures vampirism bit because we don't want it to cure the sisters.
            item["Effects"][26] = false # Spell
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
        item["Defense"] = named_rand_range_weighted(:armor_defense_range)
        
        extra_stats = ["Attack", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted(0..total_num_extra_stats, average: 1)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = named_rand_range_weighted(:item_extra_stats_range)
          if item[stat_name] < 0 && stat_name == "Attack"
            # Attack is unsigned
            item[stat_name] = 0
          end
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
        skill["Mana cost"] = named_rand_range_weighted(:crush_mana_cost_range) unless progress_skill
        skill["DMG multiplier"] = named_rand_range_weighted(:crush_or_union_dmg_range)
      elsif GAME == "ooe" && (0x50..0x6E).include?(skill_global_id)
        # Glyph union
        skill["Heart cost"] = named_rand_range_weighted(:union_heart_cost_range)
        skill["DMG multiplier"] = named_rand_range_weighted(:crush_or_union_dmg_range)
        
        skill["Heart cost"] = 0 if skill_global_id == 0x68 # Dominus union shouldn't cost hearts
      else
        skill["Mana cost"] = named_rand_range_weighted(:skill_mana_cost_range) unless progress_skill
        skill["DMG multiplier"] = named_rand_range_weighted(:skill_dmg_range)
      end
      
      skill["Soul Scaling"] = rng.rand(0..4) if GAME == "dos"
      
      if skill["?/Swings/Union"]
        union_type = skill["?/Swings/Union"] >> 2
        if union_type != 0x13 # Don't randomize Dominus glyphs (union type 13)
          union_type = rng.rand(0x01..0x12)
          low_two_bits = skill["?/Swings/Union"] & 0b11
          skill["?/Swings/Union"] = (union_type << 2) | low_two_bits
        end
      end
      
      if GAME == "por" && skill["Type"] == 0
        skills_that_must_be_used_by_original_player = [
          "Puppet Master",
          "Stonewall",
          "Gnebu",
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
        
        # Set either the sub or spell bit in the damage types bitfield to let enemies know what this is now.
        is_spell = skill["??? bitfield"][2]
        is_sub = !is_spell
        skill["Effects"][25] = is_sub   # "Is a subweapon" bit
        skill["Effects"][26] = is_spell # "Is a spell" bit
      end
      
      case GAME
      when "dos"
        if (0xCE..0x102).include?(skill_global_id) && !progress_skill
          soul_extra_data = game.items[skill_global_id+0x7B]
          soul_extra_data["Max at once"] = named_rand_range_weighted(:skill_max_at_once_range)
          soul_extra_data["Bonus max at once"] = rand_range_weighted(0..2)
          soul_extra_data.write_to_rom()
        end
      when "por"
        if (0x150..0x1A0).include?(skill_global_id)
          skill_extra_data = game.items[skill_global_id+0x6C]
          
          unless progress_skill
            max_at_once = named_rand_range_weighted(:skill_max_at_once_range)
            is_spell = skill["??? bitfield"][2]
            if is_spell
              charge_time = named_rand_range_weighted(:spell_charge_time_range)
              skill_extra_data["Max at once/Spell charge"] = (charge_time<<4) | max_at_once
              skill_extra_data["SP to Master"] = 0
            else
              mastered_bonus_max_at_once = rand_range_weighted(1..6)
              skill_extra_data["Max at once/Spell charge"] = (mastered_bonus_max_at_once<<4) | max_at_once
              skill_extra_data["SP to Master"] = named_rand_range_weighted(:subweapon_sp_to_master_range)/100*100
            end
          end
          
          skill_extra_data["Price (1000G)"] = (named_rand_range_weighted(:skill_price_range)/1000.0).to_f
          
          skill_extra_data.write_to_rom()
        end
      when "ooe"
        if (0x37..0x4E).include?(skill_global_id)
          # Back glyphs can't be properly toggled off if max at once is greater than 1. (Except Agartha.)
          skill["Max at once"] = 1
        else
          skill["Max at once"] = named_rand_range_weighted(:skill_max_at_once_range)
        end
        
        skill["Delay"] = named_rand_range_weighted(:glyph_attack_delay_range) unless progress_skill
      end
      
      iframes = named_rand_range_weighted(:weapon_iframes_range)
      set_skill_iframes(skill, skill_global_id, iframes)
      
      
      if GAME == "ooe" && rng.rand() >= 0.40
        # Increase the chance of a pure physical glyph in OoE.
        damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,2], [1, 1, 1, 1, 1, 1, 2])
      else
        damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,8], [1, 1, 1, 2, 2, 3, 4])
      end
      
      if damage_types_to_set.length < 4 && rng.rand() <= 0.10
        # 10% chance to add a status effect.
        damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][8,8], [1])
      end
      
      # Add extra bits.
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1])
      
      skill["Effects"].names.each_with_index do |bit_name, i|
        if bit_name == "Cures vampirism & kills undead"
          # Don't want to randomize this or Sanctuary won't work. Also don't want to give any other spells besides Sanctuary this.
          next
        end
        
        if bit_name == "Is a spell" && skill.name == "Sanctuary"
          # Always make sure Sanctuary has the spell bit set, in case it's a Jonathan skill and it doesn't get set automatically.
          skill["Effects"][i] = true
          next
        elsif bit_name == "Is a subweapon" || bit_name == "Is a spell"
          # Don't randomize these bits, they're necessary for skills to work properly.
          next
        end
        
        if damage_types_to_set.include?(bit_name)
          skill["Effects"][i] = true
        else
          skill["Effects"][i] = false
        end
      end
      
      if GAME == "por" && skill_global_id == 0x155 # Grand Cross
        # Grand Cross normally can't be used by Charlotte, so we unset a few bits so that it can be.
        skill["Unwanted States"].value = 0x78C418
      end
      
      skill["Unwanted States"].names.each_with_index do |bit_name, i|
        # 50% chance to make a state that was originally not allowed be allowed.
        # But don't make a state that was originally allowed be not allowed.
        next if skill["Unwanted States"][i] == false
        skill["Unwanted States"][i] = [true, false].sample(random: rng)
      end
      
      skill.write_to_rom()
    end
    
    ooe_handle_glyph_tiers()
  end
  
  def ooe_handle_glyph_tiers
    return unless GAME == "ooe"
    
    # Sorts the damage, iframes, attack delay, and max at once of the tiers in each glyph family.
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    skills_by_family = skills.group_by{|skill| skill.name.match(/^(?:Vol |Melio )?(.*)$/)[1]}
    skills_by_family = skills_by_family.values.select{|family| family.size > 1}
    skills_by_family = skills_by_family.reject!{|family| ["---", ""].include?(family.first.name)}
    
    skills_by_family.each do |family|
      sorted_dmg_mults = family.map{|skill| skill["DMG multiplier"]}.sort
      sorted_iframes = family.map{|skill| skill["IFrames"]}.sort.reverse
      sorted_delays = family.map{|skill| skill["Delay"]}.sort.reverse
      sorted_max_at_onces = family.map{|skill| skill["Max at once"]}.sort
      
      prev_tier_damage_types = nil
      family.each do |skill|
        skill["DMG multiplier"] = sorted_dmg_mults.shift
        iframes = sorted_iframes.shift
        set_skill_iframes(skill, skill["Item ID"], iframes)
        skill["Delay"] = sorted_delays.shift
        skill["Max at once"] = sorted_max_at_onces.shift
        
        if prev_tier_damage_types
          # Copy the lower tier's damage types to the higher tiers.
          skill["Effects"] = prev_tier_damage_types
          
          current_damage_types = []
          skill["Effects"].names.each_with_index do |bit_name, i|
            break if i > 11
            current_damage_types << bit_name if skill["Effects"][i]
          end
          
          if rng.rand() >= 0.50 && current_damage_types.length < 4
            # 50% chance for Vol to have one more damage type than normal, and for Melio to have one more damage type than Vol.
            possible_new_damage_types = ITEM_BITFIELD_ATTRIBUTES["Effects"][0,16]
            possible_new_damage_types -= current_damage_types
            new_damage_type_name = get_n_damage_types(possible_new_damage_types, [1]).first
            skill["Effects"].names.each_with_index do |bit_name, i|
              if new_damage_type_name == bit_name
                skill["Effects"][i] = true
              end
            end
          end
        end
        
        prev_tier_damage_types = skill["Effects"]
        
        skill.write_to_rom()
      end
    end
  end
  
  def set_skill_iframes(skill, skill_global_id, iframes)
    case GAME
    when "dos"
      dos_set_skill_iframes(skill, skill_global_id, iframes)
    when "por"
      por_set_skill_iframes(skill, skill_global_id, iframes)
    when "ooe"
      ooe_set_skill_iframes(skill, skill_global_id, iframes)
    end
  end
  
  def dos_set_skill_iframes(skill, skill_global_id, iframes)
    skill_iframes_location = case skill_global_id
    when 0xD2 # Skeleton
      0x02207744
    when 0xD3 # Zombie
      0x02207F64
    when 0xD4 # Axe Armor
      0x0220C5D4
    when 0xD5 # Student Witch
      0x0220DF4C
    when 0xD6 # Warg
      0x0220A214
    when 0xD7 # Bomber Armor
      0x0220BD40
    when 0xD8 # Amalaric Sniper
      0x0220E3CC
    when 0xD9 # Cave Troll
      0x0220CDA4
    when 0xDA # Waiter Skeleton
      0x0220BB0C
    when 0xDB # Slime
      0x0220B628
    when 0xDC # Yorick
      0x022074F0
    when 0xDD # Une
      0x02206838
    when 0xDE # Mandragora
      0x0220ABE8
    when 0xDF # Rycuda
      0x02204750
    when 0xE0 # Fleaman
      0x0220A974
    when 0xE1 # Ripper
      # ???
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x0220A704, [iframes2].pack("C"))
      
      # ???
      0x0220A72C
    when 0xE2 # Guillotiner
      # Head?
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x02203CAC, [iframes2].pack("C"))
      
      # Body?
      0x02203B9C
    when 0xE3 # Killer Clown
      0x02206020
    when 0xE4 # Malachi
      0x02209C64
    when 0xE5 # Disc Armor
      0x0220B198
    when 0xE6 # Great Axe Armor
      0x0220A37C
    when 0xE7 # Slaughterer
      0x0220913C
    when 0xE8 # Hell Boar
      0x0220913C # same as slaughterer
    when 0xE9 # Frozen Shade
      0x02208BAC
    when 0xEA # Merman
      0x022087E8
    when 0xEB # Larva
      0x02203FD4
    when 0xEC # Ukoback
      0x02207120
    when 0xED # Decarabia
      0x02206B00
    when 0xEE # Succubus
      0x0220C924
    when 0xEF # Slogra
      0x0220652C
    when 0xF0 # Erinys
      0x02205CC0
    when 0xF1 # Homunculus
      0x02205998
    when 0xF2 # Witch
      0x02205604
    when 0xF3 # Fish Head
      0x0220546C
    when 0xF4 # Mollusca
      0x02204AA0
    when 0xF5 # Dead Mate
      0x02204418
    when 0xF6 # Killer Fish
      0x022037DC
    when 0xF7 # Malacoda
      0x02207AF4
    when 0xF8 # Flame Demon
      0x02209388
    when 0xF9 # Aguni
      0x02208244
    when 0xFA # Abaddon
      0x022097BC
    when 0xFB # Hell Fire
      # Need to change it to a normal constant mov, instead of copying an already used variable to r1.
      game.fs.write(0x022035CC, [0xE3A01001].pack("V"))
      
      0x022035CC
    when 0xFD # Holy Flame
      0x02203138
    when 0xFE # Blue Splash
      0x02202C64
    when 0xFF # Holy Lightning
      0x02202738
    when 0x100 # Cross
      0x022021DC
    when 0x101 # Holy Water
      0x02201B38
    when 0x102 # Grand Cross
      0x02201438
    when 0x105 # Black Panther
      0x021E6980
    when 0x106 # Armor Knight
      0x021E492C
    when 0x107 # Spin Devil
      0x021DB510
    when 0x108 # Skull Archer
      0x021DEFB0
    when 0x10A # Yeti
      0x021E50B8
    when 0x10B # Buer
      0x021DC2B0
    when 0x10C # Manticore
      0x021DFC4C
    when 0x10D # Mushussu
      0x021DFC4C # Same as Manticore
    when 0x10E # White Dragon
      0x021DCE44
    when 0x10F # Catoblepas
      0x021DCE44 # Same as White Dragon
    when 0x110 # Gorgon
      0x021DCE44 # Same as White Dragon
    when 0x111 # Persephone
      0x021DB8A4
    when 0x117 # Alura Une
      0x021E111C
    when 0x118 # Iron Golem
      0x021E5EC8
    when 0x119 # Bone Ark
      0x021DE7D8
    when 0x11A # Barbariccia
      0x021E067C
    when 0x11B # Valkyrie
      0x021E067C # Same as Barbariccia
    when 0x11C # Bat
      0x021DC868
    when 0x11D # Great Armor
      0x021E4448
    when 0x11E # Mini Devil
      0x021E4024
    when 0x11F # Harpy
      0x021E387C
    when 0x120 # Corpseweed
      0x021E3124
    when 0x121 # Quetzalcoatl
      # Head
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x021E1BAC, [iframes2].pack("C"))
      
      # Body
      0x021E1EF4
    when 0x122 # Needles
      0x021DD354
    when 0x123 # Alastor
      0x021DAE0C
    when 0x124 # Gaibon
      0x021DD868
    when 0x125 # Gergoth
      0x021DDE24
    when 0x126 # Death
      0x021DBB10
    else
      return
    end
    
    game.fs.write(skill_iframes_location, [iframes].pack("C"))
  end
  
  def por_set_skill_iframes(skill, skill_global_id, iframes)
    if [0x156, 0x15A, 0x163, 0x164, 0x167].include?(skill_global_id)
      # Not hardcoded.
      skill["Var A"] = iframes
      return
    end
    
    skill_iframes_location = case skill_global_id
    when 0x152 # Axe (Richter)
      0x02212AE0
    when 0x153 # Cross (Richter)
      0x02212518
    when 0x154 # Holy Water (Richter)
      0x02211E68
    when 0x155 # Grand Cross
      0x02211404
      0x022119EC
    when 0x156 # Seiryu
      # Not hardcoded
      return
    when 0x157 # Suzaku
      0x0220B220
    when 0x158 # Byakko
      0x0220AFDC
    when 0x159 # Genbu
      0x0220D714 # doesn't matter?
    when 0x15A # Knife
      # Not hardcoded
      return
    when 0x15B # Axe
      0x022110A8
    when 0x15C # Cross
      0x02210CB4
    when 0x15D # Holy Water
      0x02211E68 # same as richter's
    when 0x15E # Bible
      0x02210784
    when 0x15F # Javelin
      0x02210490
    when 0x160 # Ricochet Rock
      0x0220FF68
    when 0x161 # Boomerang
      0x0220F7E4
    when 0x162 # Bwaka Knife
      0x0220F4F0
    when 0x163 # Shuriken
      # Not hardcoded
      return
    when 0x164 # Yagyu Shuriken
      # Not hardcoded
      return
    when 0x165 # Discus
      0x0220B5AC
    when 0x166 # Kunimitsu
      0x0220EE38
    when 0x167 # Kunai
      # Not hardcoded
      return
    when 0x168 # Paper Airplane
      0x0220E8A0
    when 0x169 # Cream Pie
      0x0220EB8C
    when 0x16A # Crossbow
      0x0220BAC0
    when 0x16B # Dart
      0x0220E444
    when 0x16C # Grenade
      0x0220DF10
    when 0x16D # Steel Ball
      0x0220DAB4
    when 0x16E # Stonewall
      0x0220D714 # doesn't matter? same as genbu
    when 0x172 # Wrecking Ball
      0x0220C9D0
    when 0x173 # Rampage
      0x0220C6A0
    when 0x174 # Knee Strike
      # Uses the player's iframes
      return
    when 0x175 # Aura Blast
      0x0220C014
    when 0x176 # Rocket Slash
      0x0220C31C
    when 0x177 # Toad Morph
      0x021EEA88 # doesn't matter
    when 0x179 # Sanctuary
      0x021ED630
    when 0x17A # Speed Up
      0x021EDE74
    when 0x17C # Eye for an Eye
      0x021EBA20
    when 0x17D # Clear Skies
      0x021F1280
    when 0x188 # Gale Force
      0x021EC2CC
    when 0x189 # Rock Riot
      0x021EBE00
    when 0x18A # Raging Fire
      0x021EF984
    when 0x18B # Ice Fang
      0x021E9748
    when 0x18C # Thunderbolt
      0x021ED364
    when 0x18D # Spirit of Light
      0x021F019C
    when 0x18E # Dark Rift
      0x021EAE1C
    when 0x18F # Tempest
      0x021EA6CC
    when 0x190 # Stone Circle
      0x021ECEBC
    when 0x191 # Ice Needle
      0x021EC870
    when 0x192 # Explosion
      0x021F08F4
    when 0x193 # Chain Lightning
      0x021EFB2C
    when 0x194 # Piercing Beam
      0x021EA060
    when 0x195 # Nightmare
      0x021E9148
    when 0x196 # Summon Medusa
      0x021E8B9C
    when 0x197 # Acidic Bubbles
      0x021E876C
    when 0x198 # Hex
      0x021E82B0
    when 0x199 # Salamander
      # ???
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x021E79D0, [iframes2].pack("C"))
      
      # ???
      0x021E7DA8
    when 0x19A # Cocytus
      0x021E9C00
    when 0x19B # Thor's Bellow
      0x021EB310
    when 0x19C # Summon Crow
      0x021E73D0
    when 0x19D # Summon Ghost
      # ???
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x021E73D0, [iframes2].pack("C"))
      
      # ???
      0x021E6F4C
    when 0x19E # Summon Skeleton
      0x021E6C70
    when 0x19F # Summon Gunman
      0x021E68FC
    when 0x1A0 # Summon Frog
      0x021E640C
    when 0x1A2 # Rush
      0x021E26CC # ??? CHECK
    when 0x1A3 # Holy Lightning
      0x021E1FB0
    when 0x1A4 # Axe Bomber
      0x021E1668
    when 0x1A5 # 1,000 Blades
      0x021E0FE0
    when 0x1A6 # Volcano
      0x021E0B98
    when 0x1A7 # Meteor
      0x021E027C
    when 0x1A8 # Grand Cruz
      0x021DFF90
    when 0x1A9 # Divine Storm
      0x021DF5F8
    when 0x1AA # Dark Gate
      0x021DEC24
    when 0x1AB # Greatest Five
      0x021DE91C
    else
      return
    end
    
    game.fs.write(skill_iframes_location, [iframes].pack("C"))
  end
  
  def ooe_set_skill_iframes(skill, skill_global_id, iframes)
    if skill["IFrames"]
      skill["IFrames"] = iframes
    end
    
    skill_iframes_location = case skill_global_id
    when 0x19, 0x1A, 0x1B # Scutums
      0x0207943C # useless
    when 0x1C # Redire
      0x020767B4
    when 0x1D # Cubus
      0x02078AC4
    when 0x1E # Torpor
      0x02079068
    when 0x1F # Lapiste
      0x0207142C
    when 0x20 # Pneuma
      0x02071EC4
    when 0x21 # Ignis
      0x02072318
    when 0x22 # Vol Ignis
      0x02072788
    when 0x23 # Grando
      0x02072B70
    when 0x24 # Vol Grando
      0x0207342C
    when 0x25 # Fulgur
      0x020742E8
    when 0x26 # Vol Fulgur
      0x02073F30
    when 0x27 # Luminatio
      0x0207483C
    when 0x28 # Vol Luminatio
      0x02074CD4
    when 0x29 # Umbra
      0x02075978
    when 0x2A # Vol Umbra
      0x02075248
    when 0x2B # Morbus
      0x020762DC
    when 0x2C # Nitesco
      0x02076DB8
    when 0x2D # Acerbatus
      0x020796E4
    when 0x2E # Globus
      0x0207A088
    when 0x2F # Dextro Custos
      0x02077328
    when 0x30 # Sinestro Custos
      0x02077328
    when 0x31 # Dominus Hatred
      # The first projectile you shoot up.
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x02077A08, [iframes2].pack("C"))
      
      # The rain of projectiles that comes down.
      0X02077910
    when 0x32 # Dominus Anger
      0x02077F34
    when 0x33 # Cat Tackle
      0x02070AB0
    when 0x34 # Cat Tail
      0x02070E68
    when 0x3B # Rapidus Fio
      0x0207DCB0
    when 0x47 # Fidelis Caries
      0x020834A4
    when 0x48 # Fidelis Alate
      0x02082630
    when 0x49 # Fidelis Polkir
      0x0207EAC0
    when 0x4A # Fidelis Noctua
      0x02082A9C
    when 0x4B # Fidelis Medusa
      0x0207D554
    when 0x4C # Fidelis Aranea
      iframes += 30 # The game subtracts 15 iframes per level up, so we need to make sure it can't go below 0.
      0x0207D744
    when 0x4D # Fidelis Mortus
      0x0207FE0C
    when 0x4F # Agartha
      0x02083918
    when 0x55 # Pneuma union
      0x020A0014
    when 0x56 # Lapiste union
      0x020A081C
    when 0x57 # Ignis union
      0x020A0E54
    when 0x58 # Grando union
      0x020A18B8
    when 0x59 # Fulgur union
      # ???
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x02073F30, [iframes2].pack("C"))
      
      # ???
      0x02073FFC
    when 0x5A # Fire+ice union
      # Circling ice and fire parts
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x020A243C, [iframes2].pack("C"))
      
      # Center
      0x020A25E4
    when 0x5B # Light union
      0x020A2AF4
    when 0x5C # Dark union
      0x020A372C
    when 0x5D # Light+dark union
      0x020A3DC8
    when 0x66 # Nitesco union
      0x020A5DF0
    when 0x68 # Dominus union
      0x020A7170
    when 0x6A # Albus's optical shot
      0x020A7E60
    when 0x6C # Knife union
      0x020A8748
    when 0x6D # Confodere union
      # This uses the iframes from the item data for the blade, but the petals have hardcoded iframes.
      0x020A8F08
    when 0x6E # Arcus union
      # Single upwards arrow
      iframes2 = named_rand_range_weighted(:weapon_iframes_range)
      game.fs.write(0x020A9458, [iframes2].pack("C"))
      
      # Rain of arrows
      0x020A9268
    else
      return
    end
    
    game.fs.write(skill_iframes_location, [iframes].pack("C"))
  end
end
