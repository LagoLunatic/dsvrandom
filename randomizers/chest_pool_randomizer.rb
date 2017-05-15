
module ChestPoolRandomizer
  AVAILABLE_COMMON_WOODEN_CHEST_ITEM_IDS = (0xBA..0xD1).to_a
  AVAILABLE_RARE_WOODEN_CHEST_ITEM_IDS = 
  
  def randomize_wooden_chests
    return unless GAME == "ooe"
    
    available_rare_wooden_chest_item_ids = [0x77, 0x7A, 0xCB, 0xCC, 0xCD, 0xD0, 0xD1]
    available_rare_wooden_chest_item_ids += (0x9C..0xA0).to_a # AP raisers (drops)
    available_rare_wooden_chest_item_ids *= 5 # Weight it towards these consumables
    equipment = all_non_progression_pickups.select{|item_id| item_id >= 0xE5}
    available_rare_wooden_chest_item_ids += equipment.select do |item_id|
      item = game.items[item_id]
      item["Price"] >= 4000
    end
    
    available_common_wooden_chest_item_ids = (0x75..0x7E).to_a + (0x82..0xA3).to_a + (0xBA..0xD1).to_a
    available_common_wooden_chest_item_ids -= available_rare_wooden_chest_item_ids
    
    available_common_wooden_chest_item_ids.shuffle!(random: rng)
    available_rare_wooden_chest_item_ids.shuffle!(random: rng)
    
    game.wooden_chest_item_pools.each_with_index do |pool, pool_index|
      next if pool_index == 0x15 # Skip rare pool A, which is never used
      
      (0..3).each do |i|
        if pool_index <= 0xA
          pool.item_ids[i] = available_common_wooden_chest_item_ids.pop() + 1
        else
          pool.item_ids[i] = available_rare_wooden_chest_item_ids.pop() + 1
        end
      end
      
      pool.write_to_rom()
    end
  end
end
