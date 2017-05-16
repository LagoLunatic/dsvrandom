
module ShopRandomizer
  def randomize_shop
    available_shop_item_ids = all_non_progression_pickups.select do |item_id|
      next unless ITEM_GLOBAL_ID_RANGE.include?(item_id)
      item = game.items[item_id]
      next if item["Price"].nil?
      item["Price"] > 0
    end
    
    available_shop_item_ids += all_non_progression_pickups.select do |item_id|
      next unless (0x150..0x1A0).include?(item_id) # Dual crushes/relics can't have a price
      skill_extra_data = game.items[item_id+0x6C]
      if skill_extra_data["Price (1000G)"] == 0
        skill_extra_data["Price (1000G)"] = rng.rand(1..15)
        skill_extra_data.write_to_rom()
      end
      true
    end
    
    available_shop_item_ids.shuffle!(random: rng)
    
    game.shop_item_pools.each_with_index do |pool, pool_index|
      pool.item_ids.length.times do |i|
        if GAME == "por" && pool_index == 0 && i == 0
          pool.item_ids[i] = 0x4B+1 # Castle map 1 for the first quest
          available_shop_item_ids.delete(0x4B)
          next
        end
        
        pool.item_ids[i] = available_shop_item_ids.pop() + 1
      end
      
      pool.write_to_rom()
    end
  end
end
