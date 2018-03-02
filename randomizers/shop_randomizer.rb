
module ShopRandomizer
  def randomize_shop
    randomize_item_prices()
    
    available_shop_item_ids = all_non_progression_pickups.select do |item_id|
      next unless ITEM_GLOBAL_ID_RANGE.include?(item_id)
      item = game.items[item_id]
      next if item["Price"].nil?
      item["Price"] > 0
    end
    
    if GAME == "por"
      # Skills can be in the shop in PoR.
      available_shop_item_ids += all_non_progression_pickups.select do |item_id|
        next unless (0x150..0x1A0).include?(item_id) # Dual crushes/relics can't have a price
        skill_extra_data = game.items[item_id+0x6C]
        if skill_extra_data["Price (1000G)"] == 0
          skill_extra_data["Price (1000G)"] = rng.rand(1..15)
          skill_extra_data.write_to_rom()
        end
        true
      end
    end
    
    available_shop_item_ids.shuffle!(random: rng)
    
    available_arm_shifted_immediate_shop_item_ids = available_shop_item_ids.select do |item_id|
      game.fs.check_integer_can_be_an_arm_shifted_immediate?(item_id+1)
    end
    
    game.shop_item_pools.each_with_index do |pool, pool_index|
      pool.item_ids.length.times do |i|
        if pool_index == 0 && i == 0
          # Make sure the guaranteed cheap healing item is always in the shop at the start.
          pool.item_ids[i] = @shop_cheap_healing_item_id+1
          available_shop_item_ids.delete(0)
          next
        elsif GAME == "por" && pool_index == 0 && i == 1
          pool.item_ids[i] = 0+1 # Potion for the first quest
          available_shop_item_ids.delete(0)
          next
        elsif GAME == "por" && pool_index == 0 && i == 2
          pool.item_ids[i] = 0x4B+1 # Castle map 1 for the first quest
          available_shop_item_ids.delete(0x4B)
          next
        elsif pool.slot_is_arm_shifted_immediate?(i)
          # This is a hardcoded slot that must be an arm shifted immediate.
          item_id = available_arm_shifted_immediate_shop_item_ids.pop()
          pool.item_ids[i] = item_id + 1
          available_shop_item_ids.delete(item_id)
          next
        end
        
        item_id = available_shop_item_ids.pop()
        pool.item_ids[i] = item_id + 1
        available_arm_shifted_immediate_shop_item_ids.delete(item_id)
      end
      
      pool.write_to_rom()
    end
  end
  
  def randomize_item_prices
    (ITEM_GLOBAL_ID_RANGE.to_a - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS).each do |item_global_id|
      item = game.items[item_global_id]
      
      progress_item = checker.all_progression_pickups.include?(item_global_id)
      
      if progress_item
        # Always make progression items be worth 0 gold so they can't be sold on accident.
        item["Price"] = 0
      elsif item.name == "Encyclopedia"
        # Don't let Charlotte's base unequip weapon be sold, since having zero weapons can cause bugs and crashes.
        item["Price"] = 0
      elsif item.name == "CASTLE MAP 1" && GAME == "por"
        # Don't randomize castle map 1 in PoR so it doesn't cost a lot to buy for the first quest.
      elsif item_global_id == @shop_cheap_healing_item_id
        # Make the guaranteed cheap healing item reasonably priced (100-300).
        item["Price"] = rng.rand(100..399)/100*100
      else
        item["Price"] = named_rand_range_weighted(:item_price_range)/100*100
      end
      
      item.write_to_rom()
    end
  end
end
