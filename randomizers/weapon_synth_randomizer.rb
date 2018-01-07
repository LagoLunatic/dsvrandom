
module WeaponSynthRandomizer
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
      items_available_for_this_chain = item_types_with_enough_items.sample(random: rng)
      
      chain.synths.each do |synth|
        req_item, created_item = items_available_for_this_chain.sample(2, random: rng)
        
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
