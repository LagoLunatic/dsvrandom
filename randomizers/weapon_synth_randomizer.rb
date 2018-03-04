
module WeaponSynthRandomizer
  def randomize_weapon_synths
    return unless GAME == "dos"
    
    items_by_type = {}
    items_by_type[:weapons] = (0x42..0x90).to_a
    items_by_type[:body_armor] = (0x91..0xAE).to_a
    items_by_type[:accessories] = (0xAF..0xCD).to_a
    
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
    items_by_type.merge!(consumables_by_type)
    
    items_by_type = items_by_type.map do |type_name, item_list_for_type|
      [type_name, item_list_for_type & all_non_progression_pickups]
    end.to_h
    
    available_souls = all_non_progression_pickups & SKILL_GLOBAL_ID_RANGE.to_a
    available_souls.map!{|global_id| global_id - 0xCE}
    
    item_type_names_for_each_chain = []
    
    WEAPON_SYNTH_CHAIN_NAMES.each_index do |index|
      chain = WeaponSynthChain.new(index, game.fs)
      
      item_types_with_enough_items = items_by_type.select do |type_name, item_list_for_type|
        item_list_for_type.length >= chain.synths.length+1
      end
      type_name_for_this_chain = item_types_with_enough_items.keys.sample(random: rng)
      items_available_for_this_chain = item_types_with_enough_items[type_name_for_this_chain]
      
      # Keep track of what type of items are in this chain for the names at the top of the screen.
      item_type_names_for_each_chain << type_name_for_this_chain
      
      items_for_this_chain = []
      (chain.synths.length+1).times do
        item_id = items_available_for_this_chain.sample(random: rng)
        items_for_this_chain << item_id
        
        # Remove the chosen item from the list of available items so it's never chosen again.
        # Note that this doesn't only affect this chain, but all other chains as well, so a given item never appears multiple times in the synth screen.
        items_available_for_this_chain.delete(item_id)
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
        
        synth.required_item_id = req_item + 1
        synth.required_soul_id = available_souls.sample(random: rng)
        synth.created_item_id = created_item + 1
        
        synth.write_to_rom()
      end
    end
    
    
    # Now update the image with the names of the synth categories.
    
    chain_names_image = ChunkyPNG::Image.from_file("./dsvrandom/assets/synth type names.png")
    chain_names_order_list = %i(weapons body_armor accessories restores_hp restores_mp subtracts_hp consumable restorative curative)
    
    gfx_pointer = 0x022D0B00 # /sc/f_mix_e.dat
    palette_pointer = 0x022C490C
    # Need to use palette 1 even though 3 is the correct one.
    # This is because a couple of colors in palette 3 are exactly the same, and saving as that palette would merge the two into one palette and the image would look wrong.
    palette_index = 1
    gfx_page = GfxWrapper.new(gfx_pointer, game.fs)
    palette = renderer.generate_palettes(palette_pointer, 16)[palette_index]
    image = renderer.render_gfx_1_dimensional_mode(gfx_page, palette)
    
    item_type_names_for_each_chain.each_with_index do |type_name, i|
      type_name_image_index = chain_names_order_list.index(type_name)
      name_image = chain_names_image.crop(0, type_name_image_index*16, 64, 16)
      image.compose!(name_image, 64, i*16)
    end
    
    renderer.save_gfx_page_1_dimensional_mode(image, gfx_page, palette_pointer, 16, palette_index, should_convert_image_to_palette: true)
    
    
    # Also, update palette 7 so grey ability souls render properly.
    # Note that there's a possibility palette 7 is used by something else and changing it like this will make that something else look wrong.
    # But as far as I can tell palettes 7-B are all just unused, and are simply a gradient from green to orange.
    colors = renderer.import_palette_from_palette_swatches_file("./dsvrandom/assets/synth grey souls palette_022C490C-07.png", 16)
    @renderer.save_palette(colors, palette_pointer, 7, 16)
  end
  
  def randomize_vanilla_weapon_synths_that_use_progression_souls
    return unless GAME == "dos"
    
    # Randomize only soul requirements that could result in softlocks because they use progression souls.
    
    available_souls = all_non_progression_pickups & SKILL_GLOBAL_ID_RANGE.to_a
    available_souls.map!{|global_id| global_id - 0xCE}
    
    WEAPON_SYNTH_CHAIN_NAMES.each_index do |index|
      chain = WeaponSynthChain.new(index, game.fs)
      
      chain.synths.each_with_index do |synth, i|
        if checker.all_progression_pickups.include?(0xCE + synth.required_soul_id)
          synth.required_soul_id = available_souls.sample(random: rng)
          synth.write_to_rom()
        end
      end
    end
  end
end
