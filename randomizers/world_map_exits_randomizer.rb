
module WorldMapExitsRandomizer
  WORLD_MAP_EXITS = [
    #"00-02-1B_000", # Exit from the castle. Don't randomize this, it should always unlock Large Cavern.
    "02-00-03_000", # Modified Ecclesia exit
    "04-00-03_000",
    "05-00-00_000",
    "06-00-0A_000",
    "06-01-00_000",
    "07-00-0E_000",
    "08-02-07_000",
    "09-00-07_000",
    "0A-00-0A_000",
    "0A-00-13_000", # Alternate exit from Tymeo. In vanilla this unlocked the same thing as the first exit, but the rando makes them separate.
    "0B-00-10_000",
    "0D-00-09_000",
    "0F-00-00_000",
    "10-00-00_000", # Newly added Oblivion Ridge exit
    "11-00-08_000", # Newly added Skeleton Cave exit
    "12-00-14_000", # Newly added Monastery exit
  ]
  WORLD_MAP_ENTRANCES = {
       3 => "03-00-00_000", # Training Hall.
       4 => "04-00-00_000",
       5 => "05-00-03_000",
       6 => "06-00-00_000",
       7 => "07-00-00_000",
       8 => "08-00-00_000",
       9 => "09-00-00_000", # Lighthouse. My logic has a special case here due to the spikes but it can still be randomized.
     0xA => "0A-00-00_000",
     0xB => "0B-00-00_000",
     0xD => "0D-00-00_000",
     0xE => "0E-00-0C_000",
     0xF => "0F-00-08_000",
    0x10 => "10-01-06_000",
    0x11 => "11-00-00_000",
    0x12 => "12-01-00_000",
      -1 => "06-01-09_000", # Lower Kalidus entrance.
      #-2 => "0C-00-00_000", # Large Cavern. Not randomized because we don't randomize the castle exit.
  }
  
  def initialize_world_map_exit_randomization_variables
    @world_map_exit_rando_debug = false
    
    @world_map_exits_randomized = []
    @world_map_entrances_used = []
    @num_world_map_exits_lead_to_by_world_map_entrance = {}
    WORLD_MAP_ENTRANCES.each do |key, entrance_door_str|
      entrance_area_index = entrance_door_str[0..1].to_i(16)
      num_exits = WORLD_MAP_EXITS.count{|exit_door_str| exit_door_str.start_with?("%02X-" % entrance_area_index)}
      @num_world_map_exits_lead_to_by_world_map_entrance[entrance_area_index] = num_exits
    end
  end
  
  def randomize_accessible_world_map_exits(accessible_doors)
    randomized_any = false
    
    unused_accessible_exits = (accessible_doors & WORLD_MAP_EXITS) - @world_map_exits_randomized
    
    while unused_accessible_exits.any?
      randomized_any = true
      
      world_map_exit = unused_accessible_exits.sample(random: rng)
      unused_accessible_exits.delete(world_map_exit)
      
      exit_area_index = world_map_exit[0..1].to_i(16)
      if @num_world_map_exits_lead_to_by_world_map_entrance.key?(exit_area_index)
        @num_world_map_exits_lead_to_by_world_map_entrance[exit_area_index] -= 1
        if @num_world_map_exits_lead_to_by_world_map_entrance[exit_area_index] < 0
          raise "Wrong number of world map exits lead to by a world map entrance"
        end
      end
      
      unused_entrances = WORLD_MAP_ENTRANCES.keys - @world_map_entrances_used
      possible_entrances = unused_entrances
      
      # We need to prioritize placing entrances that lead to more exits.
      # Otherwise we would exhaust all the remaining exits and the player would have no way to progress.
      # (Unless this is the very last exit overall - in that case it's fine that we exhaust the last one.)
      
      #puts "Possible unfiltered: #{possible_entrances}" if @world_map_exit_rando_debug
      
      # First prioritize ones that lead to a new area (i.e. don't place the second entrance into Kalidus).
      possible_entrances_that_lead_to_a_new_area = possible_entrances.select do |unused_entrance_key|
        unused_area_index = WORLD_MAP_ENTRANCES[unused_entrance_key][0..1].to_i(16)
        @world_map_entrances_used.none? do |used_entrance_key|
          used_area_index = WORLD_MAP_ENTRANCES[used_entrance_key][0..1].to_i(16)
          used_area_index == unused_area_index
        end
      end
      #puts "Possible filtered 1: #{possible_entrances_that_lead_to_a_new_area}" if @world_map_exit_rando_debug
      if possible_entrances_that_lead_to_a_new_area.any?
        possible_entrances = possible_entrances_that_lead_to_a_new_area
      end
      
      # Next prioritize ones that lead to a new area that has more exits remaining.
      possible_entrances_that_lead_to_a_new_exit = possible_entrances.select do |unused_entrance_key|
        unused_area_index = WORLD_MAP_ENTRANCES[unused_entrance_key][0..1].to_i(16)
        @num_world_map_exits_lead_to_by_world_map_entrance[unused_area_index] > 0
      end
      #puts "Possible filtered 2: #{possible_entrances_that_lead_to_a_new_exit}" if @world_map_exit_rando_debug
      if possible_entrances_that_lead_to_a_new_exit.any?
        possible_entrances = possible_entrances_that_lead_to_a_new_exit
      end
      
      if possible_entrances.empty?
        raise "Ran out of world map entrances to make world map exits unlock!"
      end
      entrance = possible_entrances.sample(random: rng)
      
      set_world_map_exit_destination_area(world_map_exit, entrance)
      
      @world_map_exits_randomized << world_map_exit
      @world_map_entrances_used << entrance
    end
    
    return randomized_any
  end
  
  def set_world_map_exit_destination_area(world_map_exit_door_str, entrance_type)
    room_str = world_map_exit_door_str[0,8]
    room = game.room_by_str(room_str)
    area_exit = room.entities.find{|e| e.type == SPECIAL_OBJECT_ENTITY_TYPE && e.subtype == 0x2B}
    if entrance_type >= 0
      area_exit.var_a = entrance_type
      area_exit.var_b = 0
      
      if entrance_type == 6
        # When unlocking the front entrance of Kalidus, also need to set var B to 3 so our custom code knows to set the front entrance room as explored.
        area_exit.var_b = 3
      end
    else # Negative value indicates var B should be used instead of var A.
      area_exit.var_a = 0
      area_exit.var_b = -entrance_type
      
      if entrance_type == -1
        # When unlocking the back entrance of Kalidus, also need to unlock Kalidus on the world map.
        area_exit.var_a = 6
      end
    end
    area_exit.write_to_rom()
    
    entrance_door_str = WORLD_MAP_ENTRANCES[entrance_type]
    puts "Setting world map unlock: #{world_map_exit_door_str} -> #{entrance_door_str}" if @world_map_exit_rando_debug
    
    checker.set_world_map_exit_destination_area(world_map_exit_door_str, entrance_door_str)
    
    if world_map_exit_door_str == "02-00-03_000"
      # The Ecclesia exit. We need to update the Albus mode code to auto-unlock whatever entrance this leads to, in place of the vanilla Monastery unlock.
      if entrance_type > 0
        entrance_area_index = entrance_type
      elsif entrance_type == -1 # Back entrance of Kalidus
        entrance_area_index = 6
      else
        raise "Unsupported world map entrance type: #{entrance_type}"
      end
      
      game.fs.write(0x0223B818, [0xEBF9BC4F].pack("V")) # bl 020AA95Ch ; UnlockWorldMapArea (for Wygol, simplifying vanilla code)
      game.fs.write(0x0223B81C, [entrance_area_index].pack("C")) # Update what the other area to start Albus unlocked with is, instead of Monastery
      game.fs.write(0x0223B820, [0xE3A01001].pack("V")) # mov r1, 1h
      
      if entrance_type == 6 || entrance_type == -1
        # If the first area happens to be Kalidus, we need to add more code to properly unlock one of the two entrances.
        game.fs.write(0x0223B828, [0xE3A00006].pack("V")) # mov r0, 6h
        if entrance_type == 6
          # Front entrance
          game.fs.write(0x0223B82C, [0xE3A01000].pack("V")) # mov r1, 0h
          game.fs.write(0x0223B830, [0xE3A02000].pack("V")) # mov r2, 0h
        else
          # Back entrance
          game.fs.write(0x0223B82C, [0xE3A01001].pack("V")) # mov r1, 1h
          game.fs.write(0x0223B830, [0xE3A02009].pack("V")) # mov r2, 9h
        end
        game.fs.write(0x0223B834, [0xEBF82A42].pack("V")) # bl 02046144h ; MapSetRoomExplored
        game.fs.write(0x0223B838, [0xE1A00000].pack("V")) # nop
        game.fs.write(0x0223B83C, [0xE1A00000].pack("V")) # nop
      else  
        # Otherwise we don't need these extra lines.
        (0x0223B828..0x0223B83C).step(4) do |address|
          game.fs.write(address, [0xE1A00000].pack("V")) # nop
        end
      end
    end
  end
  
  def assert_all_world_map_entrances_and_exits_used
    unused_exits = WORLD_MAP_EXITS - @world_map_exits_randomized
    unused_entrances = WORLD_MAP_ENTRANCES.keys - @world_map_entrances_used
    
    puts "Unused world map exits: #{unused_exits.join(", ")}" if @world_map_exit_rando_debug
    puts "Unused world map entrances: #{unused_entrances.join(", ")}" if @world_map_exit_rando_debug
    
    if unused_exits.any? && unused_entrances.any?
      raise "Error: There are unplaced world map exits and entrances:\nExits: #{unused_exits.join(", ")}\nEntrances: #{unused_entrances.join(", ")}"
    elsif unused_exits.any?
      raise "Error: There are unplaced world map exits: #{unused_exits.join(", ")}"
    elsif unused_entrances.any?
      raise "Error: There are unplaced world map entrances: #{unused_entrances.join(", ")}"
    end
  end
end
