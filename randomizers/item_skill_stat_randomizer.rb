
module ItemSkillStatRandomizer
  def get_n_damage_types(all_damage_types, possible_n_values)
    known_damage_type_names = all_damage_types.select{|name| name !~ /\d$/}
    num_damage_types = possible_n_values.sample(random: rng)
    damage_types_to_set = known_damage_type_names.sample(num_damage_types, random: rng)
    damage_types_to_set
  end
  
  def randomize_equipment_stats
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
      
      if item.item_type_name == "Weapons"
        item["Attack"] = named_rand_range_weighted(:weapon_attack_range)
        
        extra_stats = ["Defense", "Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        
        # Clear all stats to 0 first before randomizing some of them.
        extra_stats.each do |stat_name|
          item[stat_name] = 0
        end
        
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted(0..total_num_extra_stats, average: 1)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = named_rand_range_weighted(:item_extra_stats_range)
          if item[stat_name] < 0 && stat_name == "Defense"
            # Defense is unsigned
            item[stat_name] = 0
          end
        end
        
        item.write_to_rom()
      elsif ["Armor", "Body Armor", "Head Armor", "Leg Armor", "Accessories"].include?(item.item_type_name)
        item["Defense"] = named_rand_range_weighted(:armor_defense_range) unless item.name == "Heavy Armor"
        
        extra_stats = ["Strength", "Constitution", "Intelligence", "Luck"]
        extra_stats << "Mind" if GAME == "por" || GAME == "ooe"
        
        # Don't randomize some extreme stats that are part of the identity of the item.
        if item.name == "Death Ring"
          extra_stats -= ["Strength", "Constitution", "Intelligence", "Mind"]
        end
        if item.name == "Berserker Mail"
          extra_stats -= ["Strength", "Constitution", "Mind"]
        end
        if item.name == "Heavy Armor"
          extra_stats -= ["Mind"]
        end
        
        # Clear all stats to 0 first before randomizing some of them.
        extra_stats.each do |stat_name|
          item[stat_name] = 0
        end
        
        total_num_extra_stats = extra_stats.length
        
        num_extra_stats_for_this_item = rand_range_weighted(0..total_num_extra_stats, average: 1)
        extra_stats.sample(num_extra_stats_for_this_item, random: rng).each do |stat_name|
          item[stat_name] = named_rand_range_weighted(:item_extra_stats_range)
          if item[stat_name] < 0 && stat_name == "Attack"
            # Attack is unsigned
            item[stat_name] = 0
          end
        end
        
        if GAME == "por" && item.name != "Casual Clothes"
          item["Equippable by"].value = rng.rand(1..3) if GAME == "por"
          if item.name == "Master Ring"
            item["Equippable by"].value |= 1 # Always let Jonathan use Master Ring
            if options[:allow_mastering_charlottes_skills]
              item["Equippable by"].value |= 2 # Always let Charlotte use Master Ring too, if she can master skills.
            end
          end
          if item.name == "Sorceress Crest"
            item["Equippable by"].value |= 2 # Always let Charlotte use Sorceress Crest
          end
        end
        
        damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Resistances"], [0, 0, 0, 0, 0, 0, 1])
        item["Resistances"].names.each_with_index do |bit_name, i|
          if damage_types_to_set.include?(bit_name)
            item["Resistances"][i] = true
          else
            item["Resistances"][i] = false
          end
        end
        
        item.write_to_rom()
        update_equipment_description(item)
      end
    end
  end
  
  def randomize_weapons
    (ITEM_GLOBAL_ID_RANGE.to_a - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS).each do |item_global_id|
      item = game.items[item_global_id]
      
      # Don't randomize unequip/starting items.
      if item.name == "---" || item.name == "Bare knuckles" || item.name == "Encyclopedia"
        next
      end
      case GAME
      when "dos"
        next if item.name == "Knife"
      when "por"
        next if item["Item ID"] == 0x61 # starting Vampire Killer
      end
      
      if item.item_type_name == "Weapons"
        if options[:randomize_weapon_behavior]
          randomize_weapon_behavior(item, item_global_id)
        end
        
        if options[:randomize_weapon_and_skill_elements]
          randomize_weapon_damage_types(item, item_global_id)
        end
        
        item.write_to_rom()
        update_weapon_description(item)
      end
    end
  end
  
  def center_weapon_sprite_on_origin(item)
    # Centers a weapon sprite on the origin point so that it works properly with the Heaven Sword/Tori effect.
    
    weapon_gfx = WeaponGfx.new(item["Sprite"], game.fs)
    sprite = Sprite.new(weapon_gfx.sprite_file_pointer, game.fs)
    
    return if sprite.animations.empty?
    
    anim = sprite.animations[0]
    frames = anim.frame_delays.map{|frame_delay| sprite.frames[frame_delay.frame_index]}
    
    widest_hitbox = nil
    frames.each do |frame|
      frame.hitboxes.each do |hitbox|
        if widest_hitbox.nil? || hitbox.width > widest_hitbox.width
          widest_hitbox = hitbox
        end
      end
    end
    
    center_x = widest_hitbox.x_pos + widest_hitbox.width/2
    center_y = widest_hitbox.y_pos + widest_hitbox.height/2
    offset_amount_x = -center_x
    offset_amount_y = -center_y
    
    parts_and_hitboxes = frames.map{|frame| frame.parts + frame.hitboxes}.flatten.uniq
    parts_and_hitboxes.each do |part_or_hitbox|
      part_or_hitbox.x_pos += offset_amount_x
      part_or_hitbox.y_pos += offset_amount_y
    end
    
    sprite.write_to_rom()
  end
  
  def randomize_consumable_behavior
    (ITEM_GLOBAL_ID_RANGE.to_a - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS).each do |item_global_id|
      item = game.items[item_global_id]
      
      progress_item = checker.all_progression_pickups.include?(item_global_id)
      
      if needs_infinite_magical_tickets?
        next if item.name == "Magical Ticket"
      end
      
      if GAME == "dos" && item.name == "Magical Ticket"
        next
      end
      
      if item.item_type_name == "Consumables"
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
          elsif GAME == "por" && item.name == "Magical Ticket"
            # Always make magical tickets have the magical ticket type. Otherwise they will still act as magical tickets, but the description will be misleading.
            possible_types = [5]
          elsif GAME == "por" && item.name.start_with?("Record ")
            # Always make records have the record type. Otherwise they will still act as records, but the description will be misleading.
            possible_types = [5]
          end
          
          if @max_up_items[0] == item["Item ID"]
            # HP Max Up
            possible_types = [7]
          elsif @max_up_items[1] == item["Item ID"]
            # MP Max Up
            possible_types = [8]
          end
          
          if item["Item ID"] == @shop_cheap_healing_item_id
            # Make the guaranteed cheap healing item always restore HP.
            possible_types = [0]
          end
          
          item["Type"] = possible_types.sample(random: rng)
          
          case item["Type"]
          when 0, 1, 3 # Restores HP/restores MP/subtracts HP
            item["Var A"] = named_rand_range_weighted(:restorative_amount_range)
          when 2 # Cures status effect
            item["Var A"] = [1, 1, 1, 2, 2, 2, 4].sample(random: rng)
          end
          
          if item["Item ID"] == @shop_cheap_healing_item_id
            # Always make the guaranteed cheap healing item restore a decent but not too large amount of HP.
            item["Var A"] = rng.rand(80..200)
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
          if item.name == "Poor Photo"
            # Don't allow poor photo to restore HP, hearts, or increase attribute points. Infinite access to these is OP.
            possible_types -= [0, 2, 0xB]
          end
          
          # If the player has an infinite magical ticket, don't bother letting any other items be magical tickets too.
          if needs_infinite_magical_tickets?
            possible_types.delete(0xA)
          end
          
          if (0x9C..0xA0).include?(item["Item ID"]) && rng.rand >= 0.60
            # Drops. These are the only ones that can be AP increasers, so give them a 60% to be an AP increaser.
            possible_types = [0xB]
          end
          
          if progress_item
            # Always make progression items unusable so the player can't accidentally eat one and softlock themself.
            possible_types = [8]
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
          
          if item["Item ID"] == @shop_cheap_healing_item_id
            # Make the guaranteed cheap healing item always restore HP.
            possible_types = [0]
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
          
          if item["Item ID"] == @shop_cheap_healing_item_id
            # Always make the guaranteed cheap healing item restore a decent but not too large amount of HP.
            item["Var A"] = rng.rand(80..200)
          end
        end
        
        item.write_to_rom()
        update_consumable_description(item)
      end
    end
  end
  
  def randomize_skills
    SKILL_GLOBAL_ID_RANGE.each do |skill_global_id|
      skill = game.items[skill_global_id]
      
      if @ooe_starter_glyph_id
        next if skill_global_id == @ooe_starter_glyph_id
      else
        next if skill.name == "Confodere"
      end
      
      if options[:randomize_skill_stats]
        randomize_skill_stats(skill, skill_global_id)
      end
      
      if options[:randomize_skill_behavior]
        randomize_skill_behavior(skill, skill_global_id)
      elsif GAME == "ooe"
        skill_iframes_locations = HARDCODED_SKILL_IFRAMES_LOCATIONS[skill_global_id]
        if skill_iframes_locations
          orig_iframes = game.fs.read(skill_iframes_locations[0], 1).unpack("C")[0]
          skill["IFrames"] = orig_iframes
        end
      end
      
      if options[:randomize_weapon_and_skill_elements]
        randomize_skill_damage_types(skill, skill_global_id)
      end
      
      skill.write_to_rom()
    end
    
    ooe_handle_glyph_tiers()
    
    # Must update the skill descriptions after the glyph families have been reordered.
    SKILL_GLOBAL_ID_RANGE.each do |skill_global_id|
      skill = game.items[skill_global_id]
      
      update_skill_description(skill)
    end
  end
  
  def randomize_weapon_behavior(item, item_global_id)
    progress_item = checker.all_progression_pickups.include?(item_global_id)
    
    # We'll need this list of duplicate weapon sprites later.
    other_weapons_with_same_sprite = game.items.select do |other_item|
      other_item.item_type_name == "Weapons" && other_item["Sprite"] == item["Sprite"]
    end
    other_weapons_with_same_sprite -= [item]
    
    item["IFrames"] = named_rand_range_weighted(:weapon_iframes_range)
    
    case GAME
    when "dos"
      unless [9, 0xA, 0xB].include?(item["Swing Anim"])
        # Only randomize swing anim if it wasn't originally a throwing/firing weapon.
        # Throwing/firing weapon sprites have no hitbox, so they won't be able to damage anything if they don't remain a throwing/firing weapon.
        available_swing_anims = (0..0xC).to_a
        if item.name == "Whip"
          # If the whip turns into a projectile weapon Julius can't break Balore blocks, so ban those swing anims.
          available_swing_anims -= [0x9, 0xA, 0xB]
          if !options[:no_touch_screen]
            # If the no touch screen option is off, only the whip swing anim works to break Balore blocks.
            available_swing_anims = [0xC]
          end
        end
        if other_weapons_with_same_sprite.any?
          # The throwing weapon swing anim require the weapon's sprite to be recentered to the origin.
          # That would cause issues if this weapon's sprite is shared by any other weapons, so don't allow this swing anim in that case.
          available_swing_anims -= [0xA]
        end
        
        item["Swing Anim"] = available_swing_anims.sample(random: rng)
        
        if [0xA].include?(item["Swing Anim"])
          # If a normal weapon gets the throwing weapon swing anim, we need to recenter this weapon's sprite and hitboxes to be on the origin so it's not spinning around where its actual hitbox is.
          center_weapon_sprite_on_origin(item)
        end
      end
      item["Super Anim"] = rng.rand(0..0xE) unless progress_item
    when "por"
      if [0x61, 0x6C].include?(item["Item ID"]) || item.name == "---"
        # Don't randomize who can equip the weapons Jonathan and Charlotte start out already equipped with, or the --- unequipped placeholder.
      elsif item["Equippable by"].value == 1 && progress_item
        # Don't randomize Jonathan's glitch progress weapons (Cinquedia, Axe, etc) to be for Charlotte because Charlotte may not be accessible with "Don't randomize Change Cube".
      else
        item["Equippable by"].value = rng.rand(1..3) if GAME == "por"
      end
      
      item["Swing Anim"] = rng.rand(0..9)
      
      unless progress_item
        palette = item["Crit type/Palette"] & 0xC0
        crit_type = rng.rand(0..0x13)
        item["Crit type/Palette"] = palette | crit_type
      end
      
      if item.name == "Heaven's Sword" || item.name == "Tori"
        # Heaven's Sword and Tori need to have either the Heaven's Sword or Tori effect in order to go anywhere, otherwise they'll just be at the player's feet.
        item["Special Effect"] = [5, 7].sample(random: rng)
      elsif rng.rand <= 0.50 # 50% chance to have a special effect
        possible_special_effects = (1..7).to_a
        if item["Item ID"] == 0x6B # Richter's Vampire Killer
          # Heaven's Sword and Illusion Fist effects don't work so well with it, and Richter can't switch to any other weapon, so don't allow those 2 special effects.
          possible_special_effects -= [5, 6]
        end
        if other_weapons_with_same_sprite.any?
          # Heaven's Sword and Tori effects require the weapon's sprite to be recentered to the origin.
          # That would cause issues if this weapon's sprite is shared by any other weapons, so don't allow those 2 special effects in that case.
          possible_special_effects -= [5, 7]
        end
        
        # Nebula effect only activates when the weapon animation reaches keyframe index 9.
        weapon_gfx = WeaponGfx.new(item["Sprite"], game.fs)
        sprite = Sprite.new(weapon_gfx.sprite_file_pointer, game.fs)
        if sprite.animations[0] && sprite.animations[0].frame_delays.size >= 10
          # This sprite's first animation has at least 10 frames so the Nebula effect would work.
        else
          # This sprite's first animation doesn't exist or has less than 10 frames. Nebula effect would never activate.
          possible_special_effects -= [1]
        end
        
        item["Special Effect"] = possible_special_effects.sample(random: rng)
        
        if [5, 7].include?(item["Special Effect"])
          # If a normal weapon gets the Heaven's Sword or Tori special effect, we need to recenter this weapon's sprite and hitboxes to be on the origin so it's not floating higher than it should.
          center_weapon_sprite_on_origin(item)
        end
      else
        item["Special Effect"] = 0
      end
    end
    
    player_can_move = nil
    item["Swing Modifiers"].names.each_with_index do |bit_name, i|
      next if bit_name == "Shaky weapon" && GAME == "dos" # This makes the weapon appear too high up
      
      if bit_name == "Player can move"
        # 5% chance of the Valmanway effect.
        bit_chance = 1/20.0
      elsif GAME == "dos" && item["Swing Anim"] == 0xA && bit_name == "Weapon floats in place"
        # This bit must be set for throwing weapons to throw correctly.
        # But instead we give it a 10% chance of not being set so you can get throwing weapons stuck at your feet sometimes.
        bit_chance = 9/10.0
      else
        # Otherwise, give all other bits a 25% chance.
        bit_chance = 1/4.0
      end
      
      item["Swing Modifiers"][i] = (rng.rand() <= bit_chance)
      
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
    
    if item["Special Effect"] == 5
      # The Heaven Sword "throw the weapon in front of you" effect only uses the first keyframe of the weapon sprite's first animation.
      # If the first frame has no hitbox the weapon won't be able to hit enemies.
      # So we reorder the keyframes so that one with a hitbox is first.
      weapon_gfx = WeaponGfx.new(item["Sprite"], game.fs)
      sprite = Sprite.new(weapon_gfx.sprite_file_pointer, game.fs)
      anim = sprite.animations.first
      if anim
        possible_keyframes = anim.frame_delays.select do |frame_delay|
          frame = sprite.frames[frame_delay.frame_index]
          frame.hitboxes.any?
        end
        if possible_keyframes.any?
          # Select the first frame with a hitbox.
          keyframe = possible_keyframes.first
          # Move that frame to the front.
          sprite.frame_delays.delete(keyframe)
          sprite.frame_delays.insert(anim.frame_delay_indexes.first, keyframe)
          sprite.write_to_rom()
        end
      end
    end
  end
  
  def randomize_weapon_damage_types(item, item_global_id)
    if rng.rand() >= 0.30
      # Increase the chance of a pure physical weapon.
      # (Only DoS and PoR have weapons, so the first 3 elements are physical.)
      damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,3], [1, 1, 1, 1, 1, 2, 3])
    else
      damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,8], [1, 1, 1, 2, 2, 3, 4])
    end
    
    if damage_types_to_set.length < 4 && rng.rand() <= 0.10
      # 10% chance to add a status effect.
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][8,8], [1])
    end
    
    if damage_types_to_set.length < 4 && rng.rand() <= 0.10
      # 10% chance to add an extra bit.
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [1])
    end
    
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
  end
  
  def randomize_skill_stats(skill, skill_global_id)
    progress_skill = !all_non_progression_pickups.include?(skill_global_id)
    
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
      skill["DMG multiplier"] = named_rand_range_weighted(:skill_dmg_range)
      if progress_skill
        # Don't randomize mana cost for progress skills.
      elsif GAME == "dos" && skill["Type"] == 1
        # Guardian souls should have lower mana costs than bullet souls.
        mana_cost = named_rand_range_weighted(:skill_mana_cost_range)
        mana_cost = (mana_cost / 4.0).round
        skill["Mana cost"] = mana_cost
      else
        skill["Mana cost"] = named_rand_range_weighted(:skill_mana_cost_range)
      end
    end
    
    if ["Black Panther", "Speed Up", "Rapidus Fio"].include?(skill.name)
      # Reduce damage of speed increasing skills so you can't oneshot every enemy by running into them.
      skill["DMG multiplier"] = skill["DMG multiplier"] / 5
      skill["DMG multiplier"] = 1 if skill["DMG multiplier"] < 1
    end
    if skill.name.include?("Culter")
      # Reduce damage of the knife glyphs since they usually throw multiple projectiles.
      skill["DMG multiplier"] = skill["DMG multiplier"] / 5
      skill["DMG multiplier"] = 1 if skill["DMG multiplier"] < 1
    end
  end
  
  def randomize_skill_behavior(skill, skill_global_id)
    progress_skill = !all_non_progression_pickups.include?(skill_global_id)
    
    if GAME == "dos"
      max_soul_scaling_type = 4
      if skill.name == "Persephone" || skill.name == "Axe Armor"
        # Persephone and Axe Armor don't have functional hitboxes at level 4+.
        max_soul_scaling_type = 2
      end
      soul_scaling_type = rng.rand(0..max_soul_scaling_type)
      skill["Soul Scaling"] = soul_scaling_type
    end
    
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
        "Puppet Master", # Charlotte can use it but the timing would be different due to charging it up
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
        skill["??? bitfield"][2] = [true, false].sample(random: rng) # Is spell
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
        
        if progress_skill
          max_at_once = (skill_extra_data["Max at once/Spell charge"] & 0xF)
        else
          max_at_once = named_rand_range_weighted(:skill_max_at_once_range)
        end
        
        is_spell = skill["??? bitfield"][2]
        if is_spell
          if progress_skill
            charge_time = (skill_extra_data["Max at once/Spell charge"] >> 4)
          else
            charge_time = named_rand_range_weighted(:spell_charge_time_range)
          end
          skill_extra_data["Max at once/Spell charge"] = (charge_time<<4) | max_at_once
        else
          mastered_bonus_max_at_once = rand_range_weighted(1..6)
          skill_extra_data["Max at once/Spell charge"] = (mastered_bonus_max_at_once<<4) | max_at_once
        end
        
        if is_spell && !options[:allow_mastering_charlottes_skills]
          skill_extra_data["SP to Master"] = 0
        else
          if NONOFFENSIVE_SKILL_NAMES.include?(skill.name)
            skill_extra_data["SP to Master"] = 0
          else
            skill_extra_data["SP to Master"] = named_rand_range_weighted(:subweapon_sp_to_master_range)/100*100
          end
        end
        
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
      
      if skill.item_type_name == "Arm Glyphs" && skill["Code"] == 0x02070890
        # Randomize the swing animation for melee weapons.
        skill["Var A"] = rng.rand(0..6)
      end
      
      if skill.name.include?("Culter")
        # Randomize the number of knives thrown.
        num_knives = rand_range_weighted(1..8, average: 3)
        skill["Var A"] = num_knives-1
      end
    end
    
    iframes = named_rand_range_weighted(:skill_iframes_range)
    if skill.name == "1,000 Blades"
      iframes = 1
    end
    set_skill_iframes(skill, skill_global_id, iframes)
    
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
  end
  
  def randomize_skill_damage_types(skill, skill_global_id)
    if GAME == "ooe" && rng.rand() >= 0.40
      # Increase the chance of a pure physical glyph in OoE.
      # (In OoE only the first 2 elements are physical.)
      damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,2], [1, 1, 1, 1, 1, 1, 2])
    else
      damage_types_to_set = get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][0,8], [1, 1, 1, 2, 2, 3, 4])
    end
    
    if damage_types_to_set.length < 4 && rng.rand() <= 0.10
      # 10% chance to add a status effect.
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][8,8], [1])
    end
    
    if damage_types_to_set.length < 4 && rng.rand() <= 0.10
      # 10% chance to add an extra bit.
      damage_types_to_set += get_n_damage_types(ITEM_BITFIELD_ATTRIBUTES["Effects"][16,16], [1])
    end
    
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
    
    if skill.name == "Knee Strike"
      # Knee Strike doesn't use its damage types properly, it just uses the player's body's damage types.
      # So we change its damage types to be the same as the player's so that it displays accurately in the skill's description.
      is_spell = skill["??? bitfield"][2]
      if is_spell
        player = game.players[1] # Charlotte
      else
        player = game.players[0] # Jonathan
      end
      skill["Effects"].value = player["Damage types"].value
    end
  end
  
  def update_consumable_description(item)
    description = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
    
    case GAME
    when "dos", "por"
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
  end
  
  def update_equipment_description(item)
    return unless options[:revise_item_descriptions]
    
    description = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
    
    new_desc = ""
    
    resistance_names = []
    item["Resistances"].names.each_with_index do |bit_name, i|
      break if i >= 16 # We don't want to display the special bits, like "Is a red soul" for example
      
      if item["Resistances"][i]
        resistance_names << bit_name
      end
    end
    if resistance_names.any?
      new_desc << "Resist: #{resistance_names.join(", ")}"
    else
      # If the item doesn't have any resistances to display, don't modify the original description at all.
      return
    end
    
    description.decoded_string = new_desc
  end
  
  def update_weapon_description(item)
    return unless options[:revise_item_descriptions]
    
    description = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
    
    new_desc = ""
    
    if GAME == "por" && item["Special Effect"] != 0
      special_effect_name = case item["Special Effect"]
      when 1
        "Nebula"
      when 5
        "Heaven Sword"
      when 6
        "Illusion Fist"
      when 7
        "Tori"
      else
        nil
      end
    end
    
    if item["Swing Modifiers"]["Player can move"]
      special_effect_name = "Valmanway"
    end
    
    if special_effect_name
      swing_anim_name = special_effect_name
    else
      swing_anim_name = WEAPON_SWING_ANIM_NAMES[item["Swing Anim"]]
    end
    new_desc << "Anim: #{swing_anim_name}"
    
    if GAME == "dos"
      super_name = WEAPON_SUPER_ANIM_NAMES[item["Super Anim"]]
      new_desc << ", Super: #{super_name}"
    elsif GAME == "por"
      crit_type = item["Crit type/Palette"] & 0x3F
      crit_name = WEAPON_SUPER_ANIM_NAMES[crit_type]
      new_desc << ", Crit: #{crit_name}"
    end
    
    damage_type_names = get_elements_list_for_descriptions(item["Effects"])
    
    if damage_type_names.any?
      new_desc << "\\nElements: #{damage_type_names.join(", ")}"
    end
    
    description.decoded_string = new_desc
  end
  
  def update_skill_description(skill)
    return unless options[:revise_item_descriptions]
    
    if GAME == "dos" && skill["Type"] >= 2
      # Yellow or ability soul.
      return
    end
    if GAME == "por" && skill["Type"] == 3
      # Relic.
      return
    end
    if GAME == "ooe" && NONOFFENSIVE_SKILL_NAMES.include?(skill.name)
      # Non-offensive back glyph.
      return
    end
    
    description = game.text_database.text_list[skill.description_text_id]
    
    new_desc = ""
    
    new_desc << "DMG: #{skill["DMG multiplier"]}"
    
    if GAME == "por"
      new_desc << ", MP: #{skill["Mana cost"]}"
    end
    
    if GAME == "por" && skill["Type"] == 0
      is_spell = skill["??? bitfield"][2]
      if is_spell
        skill_extra_data = game.items[skill.index+0x150+0x6C]
        charge_time = skill_extra_data["Max at once/Spell charge"] >> 4
        charge_time_in_seconds = (charge_time/60.0).round(1)
        new_desc << ", Charge: #{charge_time_in_seconds}s"
      end
    end
    
    if GAME == "ooe" && skill.item_type_name == "Arm Glyphs"
      union_type = skill["?/Swings/Union"] >> 2
      union_type_name = WEAPON_SUPER_ANIM_NAMES[union_type]
      new_desc << ", Union: #{union_type_name}"
    end
    
    damage_type_names = get_elements_list_for_descriptions(skill["Effects"])
    
    if damage_type_names.any?
      if GAME == "dos"
        # Soul descriptions don't have very much room, so we have to cut out the word "Elements".
        new_desc << "\\n"
      else
        new_desc << "\\nElements: "
      end
      new_desc << "#{damage_type_names.join(", ")}"
    end
    
    description.decoded_string = new_desc
  end
  
  def get_elements_list_for_descriptions(effects_bitfield)
    damage_type_names = []
    
    effects_bitfield.names.each_with_index do |bit_name, i|
      if i >= 16 && bit_name != "Cures vampirism & kills undead"
        # Don't want to display the special bits, like "Is a red soul", with undead killing being the only exception
        next
      end
      
      if ["Lightning", "Electric"].include?(bit_name) # This name is too long
        bit_name = "Elec"
      end
      if bit_name == "Cures vampirism & kills undead"
        bit_name = "Red"
      end
      
      if effects_bitfield[i]
        damage_type_names << bit_name
      end
    end
    
    return damage_type_names
  end
  
  def ooe_handle_glyph_tiers
    # Sorts the damage, iframes, attack delay, and max at once of the tiers in each glyph family.
    # Also copies elemental damage types from lower tiers to higher tiers in each glyph family (and possibly adds more elements) if the option to randomize skill damage types is on.
    
    return unless GAME == "ooe"
    
    skills = game.items[SKILL_GLOBAL_ID_RANGE]
    skills_by_family = skills.group_by{|skill| skill.name.match(/^(?:Vol |Melio )?(.*)$/)[1]}
    skills_by_family = skills_by_family.values.select{|family| family.size > 1}
    skills_by_family = skills_by_family.reject!{|family| ["---", ""].include?(family.first.name)}
    
    skills_by_family.each do |family|
      sorted_dmg_mults = family.map{|skill| skill["DMG multiplier"]}.sort
      # Note about the "IFrames" field here: This should have the correct iframes value in it even for glyphs with hardcoded iframes, because when set_skill_iframes sets the hardcoded iframes it also sets this field.
      # And if skill behavior rando is off, we don't reorder iframes here at all.
      if options[:randomize_skill_behavior]
        sorted_iframes = family.map{|skill| skill["IFrames"]}.sort.reverse
      end
      sorted_delays = family.map{|skill| skill["Delay"]}.sort.reverse
      sorted_max_at_onces = family.map{|skill| skill["Max at once"]}.sort
      sorted_var_as = family.map{|skill| skill["Var A"]}.sort
      
      prev_tier_damage_types = nil
      family.each do |skill|
        skill["DMG multiplier"] = sorted_dmg_mults.shift
        if options[:randomize_skill_behavior]
          iframes = sorted_iframes.shift
          set_skill_iframes(skill, skill["Item ID"], iframes)
        end
        skill["Delay"] = sorted_delays.shift
        skill["Max at once"] = sorted_max_at_onces.shift
        if skill.name.include?("Culter")
          # Var A for knife glyphs is the number of knives thrown.
          skill["Var A"] = sorted_var_as.shift
        end
        
        if prev_tier_damage_types && options[:randomize_weapon_and_skill_elements]
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
        
        prev_tier_damage_types = skill["Effects"].dup
        
        skill.write_to_rom()
      end
    end
  end
  
  def set_skill_iframes(skill, skill_global_id, iframes)
    if GAME == "por" && [0x156, 0x15A, 0x163, 0x164, 0x167].include?(skill_global_id)
      # Not hardcoded.
      skill["Var A"] = iframes
      return
    end
    if GAME == "ooe" && skill_global_id == 0x4C # Fidelis Aranea
      # The game subtracts 15 iframes per level up, so we need to make sure it can't go below 0.
      iframes += 30
    end
    if GAME == "ooe" && skill["IFrames"]
      skill["IFrames"] = iframes
    end
    
    
    skill_iframes_locations = HARDCODED_SKILL_IFRAMES_LOCATIONS[skill_global_id]
    
    if skill_iframes_locations.nil?
      return
    end
    
    skill_iframes_locations.each do |skill_iframes_location|
      game.fs.write(skill_iframes_location, [iframes].pack("C"))
    end
  end
end
