
module WeaponSynthRandomizer
  def randomize_weapon_synths
    return unless GAME == "dos"
    
    items_by_type = []
    items_by_type << (0x42..0x90).to_a # Weapons
    items_by_type << (0x91..0xAE).to_a # Body armor
    items_by_type << (0xAF..0xCD).to_a # Accessories
    
    # For consumables, we separate different types of consumables into separate lists.
    # This is so HP restoratives only upgrade to better HP restoratives, etc.
    consumables_by_type = (0x00..0x41).to_a.group_by do |item_id|
      item = game.items[item_id]
      case item["Type"]
      when 0
        :restores_hp
      when 1
        :restores_mp
      when 2
        # Cures status effect.
        # Randomly group these in with one of the other groups, since this group by itself would be too small.
        [:restores_hp, :restores_mp, :subtracts_hp].sample(random: rng)
      when 3
        :subtracts_hp
      when 4
        :unusable
      end
    end
    consumables_by_type.delete(:unusable) # Don't allow unusable items to appear in weapon synths.
    items_by_type += consumables_by_type.values
    items_by_type.map! do |item_list_for_type|
      item_list_for_type & all_non_progression_pickups
    end
    
    available_souls = all_non_progression_pickups & SKILL_GLOBAL_ID_RANGE.to_a
    available_souls.map!{|global_id| global_id - 0xCE}
    
    WEAPON_SYNTH_CHAIN_NAMES.each_index do |index|
      chain = WeaponSynthChain.new(index, game.fs)
      
      item_types_with_enough_items = items_by_type.select do |item_list_for_type|
        item_list_for_type.length >= chain.synths.length+1
      end
      items_available_for_this_chain = item_types_with_enough_items.sample(random: rng)
      
      items_for_this_chain = []
      (chain.synths.length+1).times do
        item_id = items_available_for_this_chain.sample(random: rng)
        items_available_for_this_chain.delete(item_id)
        items_for_this_chain << item_id
      end
      items_for_this_chain.sort_by! do |item_id|
        item = game.items[item_id]
        case item_id
        when 0x00..0x41
          if item["Type"] == 2
            # Curative, subtract 4 from var A so these are always sorted lower than restoratives since they're in the same list.
            item["Var A"] - 4
          else
            # Restoratives, sort by amount restored
            item["Var A"]
          end
        when 0x42..0x90
          # Weapons, sort by attack
          item["Attack"]
        when 0x91..0xAE
          # Body armor, sort by defense
          item["Defense"]
        when 0xAF..0xCD
          # Accessories, sort by all stats
          item["Defense"] + item["Strength"] + item["Constitution"]/2.0 + item["Intelligence"] + item["Luck"]
        end
      end
      
      chain.synths.each_with_index do |synth, i|
        req_item = items_for_this_chain[i]
        created_item = items_for_this_chain[i+1]
        
        # Remove the chosen items from the list of available items so it's never chosen again.
        # Note that this doesn't only affect this chain, but all other chains as well, so a given item never appears multiple times in the synth screen.
        items_available_for_this_chain.delete(req_item)
        items_available_for_this_chain.delete(created_item)
        
        synth.required_item_id = req_item + 1
        synth.required_soul_id = available_souls.sample(random: rng)
        synth.created_item_id = created_item + 1
        
        synth.write_to_rom()
      end
    end
  end
end
