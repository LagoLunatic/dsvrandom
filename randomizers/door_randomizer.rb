
module DoorRandomizer
  class NotAllRoomsAreConnectedError < StandardError ; end
  
  def randomize_transition_doors
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      all_area_transition_rooms = @transition_rooms.select do |transition_room|
        transition_room.area_index == area.area_index
      end
      
      if all_area_transition_rooms.size <= 2
        # Not enough transition rooms in this area to properly randomize it. Need at least 3.
        next
      end
      
      all_area_subsectors = []
      area.sectors.each do |sector|
        subsectors = get_subsectors(sector, include_transitions: true)
        all_area_subsectors += subsectors
      end
      
      normal_door_to_subroom_door = {}
      all_area_subsectors.each do |subsector_rooms|
        subsector_rooms.each do |room|
          room.doors.each do |door|
            if door.is_a?(RoomRandoDoor)
              normal_door_to_subroom_door[door.original_door] = door
            end
          end
        end
      end
      
      remaining_transitions = {
        left: [],
        right: [],
      }
      
      other_transitions_in_same_subsector = {}
      accessible_unused_transitions = []
      transition_doors_by_subsector = Array.new(all_area_subsectors.size){ [] }
      
      starting_transition = nil
      
      # First we make a list of the transition doors, specifically the left door in a transition room, and the right door that leads into that transition room.
      all_area_transition_rooms.each do |transition_room|
        if GAME == "por" && transition_room.room_str == "00-01-01"
          # The first transition room between the outside and inside parts of the Entrance.
          # Don't randomize this connection, so the shop and Wind are always close to the start of the game.
          next
        end
        if GAME == "por" && transition_room.room_str == "00-0A-00"
          # The transition room leading to the Throne Room behind the barrier.
          # Don't randomize this connection, always have the Throne Room behind the barrier.
          next
        end
        if GAME == "ooe" && ["00-0A-00", "00-0A-07", "00-0A-13"].include?(transition_room.room_str)
          # The transition rooms in the Final Approach.
          # Don't randomize these connections, since it could result in progression being impossible.
          next
        end
        transition_door = transition_room.doors.find{|door| door.direction == :left}
        dest_door = transition_door.destination_door
        remaining_transitions[transition_door.direction] << transition_door
        remaining_transitions[dest_door.direction] << dest_door
      end
      
      # Then we go through each transition door and keep track of what subsector it's located in.
      remaining_transitions.values.flatten.each do |transition_door|
        if transition_door.direction == :right
          # The door leading right into a transition room.
          # This is part of the sector proper, so we just use this room itself to detect the proper subsector.
          door_in_desired_subsector = transition_door
        else
          # The door leading left out of the transition room.
          # We want the subsector to the right. But since this is in the transition room, we have no idea what subsector the transition room itself is in.
          # So follow the right door out of the transition room, and use the room there to detect the proper subsector.
          right_door = transition_door.room.doors.find{|d| d.direction == :right}
          door_in_desired_subsector = right_door.destination_door
        end
        
        dest_subroom_door_in_desired_subsector = normal_door_to_subroom_door[door_in_desired_subsector]
        if dest_subroom_door_in_desired_subsector
          # If this room has subrooms we need to use those instead of the regular room.
          room_in_desired_subsector = dest_subroom_door_in_desired_subsector.room
        else
          room_in_desired_subsector = door_in_desired_subsector.room
        end
        
        all_area_subsectors.each_with_index do |subsector_rooms, subsector_index|
          if subsector_rooms.include?(room_in_desired_subsector)
            transition_doors_by_subsector[subsector_index] << transition_door
            other_transitions_in_same_subsector[transition_door] = transition_doors_by_subsector[subsector_index]
            break
          end
        end
        
        if other_transitions_in_same_subsector[transition_door].nil?
          #puts all_area_subsectors.flatten.map{|x| x.room_str}
          raise "#{transition_door.door_str} can't be found in any subsector"
        end
      end
      
      #other_transitions_in_same_subsector.each do |k, v|
      #  puts "#{k.door_str}: #{v.map{|d| d.door_str}.join(", ")}"
      #end
      
      starting_transition = remaining_transitions.values.flatten.sample(random: rng)
      
      on_first = true
      while true
        debug = false
        #debug = (area.area_index == 5)
        
        if on_first
          inside_transition_door = starting_transition
          on_first = false
        else
          inside_transition_door = accessible_unused_transitions.sample(random: rng)
        end
        
        puts "(area connections) inside door: #{inside_transition_door.door_str}" if debug
        
        inside_door_opposite_direction = case inside_transition_door.direction
        when :left
          :right
        when :right
          :left
        end
        inaccessible_remaining_matching_doors = remaining_transitions[inside_door_opposite_direction] - accessible_unused_transitions
        inaccessible_remaining_matching_doors -= other_transitions_in_same_subsector[inside_transition_door]
        
        inaccessible_remaining_matching_doors_with_other_exits = inaccessible_remaining_matching_doors.select do |door|
          new_subsector_exits = (other_transitions_in_same_subsector[door] & remaining_transitions.values.flatten) - [door]
          new_subsector_exits.any?
        end
        
        if inaccessible_remaining_matching_doors_with_other_exits.any?
          # There are doors we can swap with that allow more progress to new subsectors.
          possible_dest_doors = inaccessible_remaining_matching_doors_with_other_exits
          
          puts "TRANSITION TYPE 1" if debug
        elsif inaccessible_remaining_matching_doors.any?
          # There are doors we can swap with that will allow you to reach one new subsector which is a dead end.
          possible_dest_doors = inaccessible_remaining_matching_doors
          
          puts "TRANSITION TYPE 2" if debug
        elsif remaining_transitions[inside_door_opposite_direction].any?
          # This door direction doesn't have any more matching doors left to swap with that will result in progress.
          # So just pick any matching door.
          possible_dest_doors = remaining_transitions[inside_door_opposite_direction]
          
          puts "TRANSITION TYPE 3" if debug
        else
          # This door direction doesn't have any matching doors left.
          
          puts "TRANSITION TYPE 4" if debug
          
          raise "Area connections randomizer: Could not link all subsectors!"
        end
        
        outside_transition_door = possible_dest_doors.sample(random: rng)
        
        puts "(area connections) outside door: #{outside_transition_door.door_str}" if debug
        
        remaining_transitions[inside_transition_door.direction].delete(inside_transition_door)
        remaining_transitions[outside_transition_door.direction].delete(outside_transition_door)
        
        if queued_door_changes[inside_transition_door].any?
          puts "changed inside transition door twice: #{inside_transition_door.door_str}"
          raise "Changed a transition door twice"
        end
        if queued_door_changes[outside_transition_door].any?
          puts "changed outside transition door twice: #{outside_transition_door.door_str}"
          raise "Changed a transition door twice"
        end
        
        queued_door_changes[inside_transition_door]["destination_room_metadata_ram_pointer"] = outside_transition_door.room.room_metadata_ram_pointer
        queued_door_changes[inside_transition_door]["dest_x"] = outside_transition_door.destination_door.dest_x
        queued_door_changes[inside_transition_door]["dest_y"] = outside_transition_door.destination_door.dest_y
        queued_door_changes[outside_transition_door]["destination_room_metadata_ram_pointer"] = inside_transition_door.room.room_metadata_ram_pointer
        queued_door_changes[outside_transition_door]["dest_x"] = inside_transition_door.destination_door.dest_x
        queued_door_changes[outside_transition_door]["dest_y"] = inside_transition_door.destination_door.dest_y
        
        #puts "accessible_unused_transitions before: #{accessible_unused_transitions.map{|d| d.door_str}}"
        accessible_unused_transitions.delete(inside_transition_door)
        accessible_unused_transitions.delete(outside_transition_door)
        accessible_unused_transitions += (other_transitions_in_same_subsector[inside_transition_door] & remaining_transitions.values.flatten)
        accessible_unused_transitions += (other_transitions_in_same_subsector[outside_transition_door] & remaining_transitions.values.flatten)
        accessible_unused_transitions.uniq!
        #puts "accessible_unused_transitions after: #{accessible_unused_transitions.map{|d| d.door_str}}"
        
        if accessible_unused_transitions.empty?
          if remaining_transitions.values.flatten.size == 0
            break
          else
            raise "Area connections randomizer: Not all sectors connected: #{remaining_transitions.values.flatten.map{|door| door.door_str}}"
          end
        end
      end
    end
    
    
    doors_to_line_up = []
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      unless doors_to_line_up.include?(door.destination_door)
        doors_to_line_up << door
      end
      
      door.write_to_rom()
    end
    
    lined_up_door_strs = []
    doors_to_line_up.each do |door|
      next if lined_up_door_strs.include?(door.destination_door.door_str)
      lined_up_door_strs << door.door_str
      
      line_up_door(door)
    end
  end
  
  def randomize_non_transition_doors
    # We make sure every room in an area is accessible. This is to prevent infinite loops of a small number of rooms that connect to each other with no way to progress.
    # Loop through each room. search for remaining rooms that have a matching door. But the room we find must also have remaining doors in it besides the one we swap with so it's not a dead end, or a loop. If there are no rooms that meet those conditions, then we go with the more lax condition of just having a matching door, allowing dead ends.
    
    # Make a list of doors that lead into transition rooms so we can tell these apart from regular doors.
    transition_doors = []
    @transition_rooms.each do |room|
      room.doors.each do |inside_door|
        transition_doors << inside_door.destination_door
      end
    end
    
    @randomize_up_down_doors = true
    
    queued_door_changes = Hash.new{|h, k| h[k] = {}}
    
    game.areas.each do |area|
      if GAME == "ooe" && area.area_index == 2
        # Don't randomize Ecclesia.
        next
      end
      
      area.sectors.each do |sector|
        if GAME == "ooe" && area.area_index == 7 && sector.sector_index == 1
          # Don't randomize Rusalka's sector. It's too small to do anything with properly.
          next
        end
        
        # First get the "subsectors" in this sector.
        # A subsector is a group of rooms in a sector that can access each other.
        # This separates certains sectors into multiple parts like the first sector of PoR.
        subsectors = get_subsectors(sector)
        
        redo_counts_for_subsector = Hash.new(0)
        subsectors.each_with_index do |subsector_rooms, subsector_index|
          orig_queued_door_changes = queued_door_changes.dup
          begin
            randomize_non_transition_doors_for_subsector(subsector_rooms, subsector_index, area, sector, queued_door_changes, transition_doors)
          rescue NotAllRoomsAreConnectedError => e
            redo_counts_for_subsector[subsector_index] += 1
            if redo_counts_for_subsector[subsector_index] > @max_room_rando_subsector_redos
              raise "Bug: Door randomizer failed to connect all rooms in subsector #{subsector_index} in %02X-%02X more than #{@max_room_rando_subsector_redos} times" % [area.area_index, sector.sector_index]
            end
            puts "Door randomizer needed to redo subsector #{subsector_index} in %02X-%02X" % [area.area_index, sector.sector_index]
            queued_door_changes = orig_queued_door_changes
            redo
          end
        end
      end
    end
    
    doors_to_line_up = []
    
    queued_door_changes.each do |door, changes|
      changes.each do |attribute_name, new_value|
        door.send("#{attribute_name}=", new_value)
      end
      
      unless doors_to_line_up.include?(door.destination_door)
        doors_to_line_up << door
      end
      
      door.write_to_rom()
    end
    
    lined_up_door_strs = []
    doors_to_line_up.each do |door|
      next if lined_up_door_strs.include?(door.destination_door.door_str)
      lined_up_door_strs << door.door_str
      
      line_up_door(door)
    end
    
    replace_outer_boss_doors()
  end
  
  def randomize_non_transition_doors_for_subsector(subsector_rooms, subsector_index, area, sector, queued_door_changes, transition_doors)
    if GAME == "por" && area.area_index == 0 && sector.sector_index == 0 && subsector_index == 0
      # Don't randomize first subsector in PoR.
      return
    end
    if GAME == "por" && area.area_index == 5 && sector.sector_index == 2 && subsector_index == 0
      # Don't randomize the middle sector in Nation of Fools with Legion.
      # The randomizer never connects all the rooms properly, and Legion further complicates things anyway, so don't bother.
      return
    end
    
    prioritize_up_down = true
    if GAME == "por" && area.area_index == 6 && sector.sector_index == 0 && [1, 3].include?(subsector_index)
      # The center-left and center-right parts of Burnt Paradise. These only have a few left/right doors, so it screws up if we prioritize up/down doors.
      prioritize_up_down = false
    end
    
    #if sector.sector_index == 2
    #  puts "On subsector: #{subsector_index}"
    #  puts "Subsector rooms:"
    #  subsector_rooms.each do |room|
    #    puts "  %08X" % room.room_metadata_ram_pointer
    #  end
    #end
    
    remaining_doors = get_valid_doors(subsector_rooms, sector)
    
    if remaining_doors[:left].size != remaining_doors[:right].size
      raise "Subsector #{subsector_index} of %02X-%02X has an unmatching number of left/right doors!\nleft: #{remaining_doors[:left].size}, right: #{remaining_doors[:right].size}, up: #{remaining_doors[:up].size}, down: #{remaining_doors[:down].size}," % [area.area_index, sector.sector_index]
    end
    if remaining_doors[:up].size != remaining_doors[:down].size
      raise "Subsector #{subsector_index} of %02X-%02X has an unmatching number of up/down doors!\nleft: #{remaining_doors[:left].size}, right: #{remaining_doors[:right].size}, up: #{remaining_doors[:up].size}, down: #{remaining_doors[:down].size}," % [area.area_index, sector.sector_index]
    end
    
    #if sector.sector_index == 1
    #  remaining_doors.values.flatten.each do |door|
    #    puts "  #{door.door_str}"
    #  end
    #  puts "num doors: #{remaining_doors.values.flatten.size}"
    #  gets
    #end
    
    all_randomizable_doors = remaining_doors.values.flatten
    all_rooms = all_randomizable_doors.map{|door| door.room}.uniq
    if all_rooms.empty?
      # No doors in this sector
      return
    end
    unvisited_rooms = all_rooms.dup
    accessible_remaining_doors = []
    
    current_room = unvisited_rooms.sample(random: rng)
    
    while true
      debug = false
      #debug = (area.area_index == 0x6 && sector.sector_index == 0 && subsector_index == 1)
      
      #puts remaining_doors[:down].map{|d| d.door_str} if debug
      #gets if debug
      
      puts "on room #{current_room.room_str}" if debug
      
      unvisited_rooms.delete(current_room)
      
      accessible_remaining_doors += remaining_doors.values.flatten.select{|door| door.room == current_room}
      accessible_remaining_doors.uniq!
      accessible_remaining_doors = accessible_remaining_doors & remaining_doors.values.flatten
      
      if accessible_remaining_doors.empty?
        break
      end
      
      accessible_remaining_updown_doors = accessible_remaining_doors.select{|door| [:up, :down].include?(door.direction)}
      if accessible_remaining_updown_doors.any?
        # Always prioritize doing up and down doors first.
        inside_door = accessible_remaining_updown_doors.sample(random: rng)
      else
        inside_door = accessible_remaining_doors.sample(random: rng)
      end
      remaining_doors[inside_door.direction].delete(inside_door)
      accessible_remaining_doors.delete(inside_door)
      accessible_remaining_leftright_doors = accessible_remaining_doors.select{|door| [:left, :right].include?(door.direction)}
      
      puts "inside door chosen: #{inside_door.door_str}" if debug
      
      inside_door_opposite_direction = case inside_door.direction
      when :left
        :right
      when :right
        :left
      when :up
        :down
      when :down
        :up
      end
      
      inaccessible_remaining_matching_doors = remaining_doors[inside_door_opposite_direction] - accessible_remaining_doors
      #puts "REMAINING: #{remaining_doors[inside_door_opposite_direction].map{|x| "  #{x.door_str}\n"}}"
      
      inaccessible_remaining_matching_doors_with_other_exits = inaccessible_remaining_matching_doors.select do |door|
        ((door.room.doors & all_randomizable_doors) - transition_doors).length > 1 && unvisited_rooms.include?(door.room)
      end
      
      inaccessible_remaining_matching_doors_with_updown_door_exits_via_leftright = []
      inaccessible_remaining_matching_doors_with_no_leftright_door_exits = []
      inaccessible_remaining_matching_doors_with_no_leftright_door_exits_and_other_exits = []
      if [:left, :right].include?(inside_door.direction)
        # If we're on a left/right door, prioritize going to new rooms that have an up/down door so we don't get locked out of having any up/down doors to work with.
        
        inaccessible_remaining_matching_doors_with_updown_door_exits_via_leftright = inaccessible_remaining_matching_doors_with_other_exits.select do |door|
          if door.direction == :left || door.direction == :right
            ((door.room.doors & all_randomizable_doors) - transition_doors).any?{|x| x.direction == :up || x.direction == :down}
          end
        end
      else
        # If we're on an up/down door, prioritize going to new rooms that DON'T have any usable left/right doors in them.
        # This is because those rooms with left/right doors are more easily accessible via left/right doors. We need to prioritize the ones that only have up/down doors as they're trickier to make the logic place.
        
        inaccessible_remaining_matching_doors_with_no_leftright_door_exits = inaccessible_remaining_matching_doors.select do |door|
          if door.direction == :up || door.direction == :down
            ((door.room.doors & all_randomizable_doors) - transition_doors).none?{|x| x.direction == :left || x.direction == :right}
          end
        end
        
        inaccessible_remaining_matching_doors_with_no_leftright_door_exits_and_other_exits = inaccessible_remaining_matching_doors_with_other_exits.select do |door|
          if door.direction == :up || door.direction == :down
            ((door.room.doors & all_randomizable_doors) - transition_doors).none?{|x| x.direction == :left || x.direction == :right}
          end
        end
        
        if debug && inaccessible_remaining_matching_doors_with_no_leftright_door_exits.any?
          puts "Found up/down doors with no left/right exits in destination:"
          inaccessible_remaining_matching_doors_with_no_leftright_door_exits.each{|x| puts "  #{x.door_str}"}
        end
      end
      
      remaining_inaccessible_rooms_with_up_down_doors = (remaining_doors[:up] + remaining_doors[:down] - accessible_remaining_doors).map{|d| d.room}.uniq
      
      if inaccessible_remaining_matching_doors_with_no_leftright_door_exits_and_other_exits.any? && remaining_inaccessible_rooms_with_up_down_doors.size > 1 && prioritize_up_down
        # There are doors we can swap with that allow you to reach a new room which allows more progress, but only via up/down doors.
        # We want to prioritize these because they can't be gotten into via left/right doors like rooms that have at least one left/right.
        possible_dest_doors = inaccessible_remaining_matching_doors_with_no_leftright_door_exits_and_other_exits
        
        puts "TYPE 1" if debug
      elsif inaccessible_remaining_matching_doors_with_no_leftright_door_exits.any? && accessible_remaining_leftright_doors.size >= 1
        # There are doors we can swap with that allow you to reach a new room which is a dead end, but is a dead end with only up/down doors.
        # We want to prioritize these because they can't be gotten into via left/right doors like rooms that have at least one left/right.
        # Note that we also only take this option if there's at least 1 accessible left/right door for us to still use. If there's not this would deadend us instantly.
        possible_dest_doors = inaccessible_remaining_matching_doors_with_no_leftright_door_exits
        
        puts "TYPE 2" if debug
      elsif inaccessible_remaining_matching_doors_with_updown_door_exits_via_leftright.any? && remaining_inaccessible_rooms_with_up_down_doors.size > 1 && prioritize_up_down
        # There are doors we can swap with that allow more progress, and also allow accessing a new up/down door from a left/right door.
        possible_dest_doors = inaccessible_remaining_matching_doors_with_updown_door_exits_via_leftright
        
        puts "TYPE 3" if debug
      elsif inaccessible_remaining_matching_doors_with_other_exits.any?
        # There are doors we can swap with that allow more progress.
        possible_dest_doors = inaccessible_remaining_matching_doors_with_other_exits
        
        puts "TYPE 4" if debug
      elsif inaccessible_remaining_matching_doors.any?
        # There are doors we can swap with that will allow you to reach one new room which is a dead end.
        possible_dest_doors = inaccessible_remaining_matching_doors
        
        puts "TYPE 5" if debug
      elsif remaining_doors[inside_door_opposite_direction].any?
        # This door direction doesn't have any more matching doors left to swap with that will result in progress.
        # So just pick any matching door.
        possible_dest_doors = remaining_doors[inside_door_opposite_direction]
        
        puts "TYPE 6" if debug
      else
        # This door direction doesn't have any matching doors left.
        # Don't do anything to this door.
        
        puts "TYPE 7" if debug
        
        #puts "#{inside_door.direction} empty"
        #
        #accessible_rooms = accessible_remaining_doors.map{|door| door.room}.uniq
        #accessible_rooms -= [current_room]
        #
        #current_room = accessible_rooms.sample(random: rng)
        #p accessible_remaining_doors.size
        #gets
        
        raise "No remaining matching doors to connect to! Door #{inside_door.door_str}, subsector #{subsector_index} of %02X-%02X" % [area.area_index, sector.sector_index]
        
        current_room = unvisited_rooms.sample(random: rng)
        
        if current_room.nil?
          current_room = all_rooms.sample(random: rng)
        end
        
        if remaining_doors.values.flatten.empty?
          break
        end
        
        next
      end
      
      if !@randomize_up_down_doors && [:up, :down].include?(inside_door.direction)
        # Don't randomize up/down doors. This is a temporary hacky measure to greatly reduce failures at connecting all rooms in a subsector.
        new_dest_door = inside_door.destination_door
        # Also need to convert this door to a subroomdoor, if applicable.
        new_dest_door = all_randomizable_doors.find{|subroomdoor| subroomdoor.door_str == new_dest_door.door_str}
      else
        new_dest_door = possible_dest_doors.sample(random: rng)
      end
      remaining_doors[new_dest_door.direction].delete(new_dest_door)
      
      current_room = new_dest_door.room
      
      if queued_door_changes[inside_door].any? || queued_door_changes[new_dest_door].any?
        raise "Changed a door twice"
      end
      
      queued_door_changes[inside_door]["destination_room_metadata_ram_pointer"] = new_dest_door.room.room_metadata_ram_pointer
      queued_door_changes[inside_door]["dest_x"] = new_dest_door.destination_door.dest_x
      queued_door_changes[inside_door]["dest_y"] = new_dest_door.destination_door.dest_y
      
      queued_door_changes[new_dest_door]["destination_room_metadata_ram_pointer"] = inside_door.room.room_metadata_ram_pointer
      queued_door_changes[new_dest_door]["dest_x"] = inside_door.destination_door.dest_x
      queued_door_changes[new_dest_door]["dest_y"] = inside_door.destination_door.dest_y
      
      if debug
        puts "inside_door: #{inside_door.door_str}"
        #puts "old_outside_door: %08X" % old_outside_door.door_ram_pointer
        #puts "inside_door_to_swap_with: %08X" % inside_door_to_swap_with.door_ram_pointer
        puts "new_outside_door: #{new_dest_door.door_str}"
        puts "dest room: #{new_dest_door.room.room_str}"
        puts
        #break
      end
    end
    
    if unvisited_rooms.any?
      puts "Failed to connect the following rooms:"
      unvisited_rooms.each do |room|
        puts "  #{room.room_str}"
      end
      raise NotAllRoomsAreConnectedError.new("Room connections randomizer failed to connect some rooms.")
    end
  end
  
  def get_subsectors(sector, include_transitions: false)
    subsectors = []
    
    debug = false
    #debug = (sector.area_index == 5 && sector.sector_index == 2)
    
    transition_room_strs = @transition_rooms.map{|room| room.room_str}
    if options[:randomize_rooms_map_friendly]
      room_strs_unused_by_map_rando = @rooms_unused_by_map_rando.map{|room| room.room_str}
    end
    
    if room_rando?
      # First convert the rooms to subrooms.
      sector_subrooms = checker.convert_rooms_to_subrooms(sector.rooms)
    else
      sector_subrooms = sector.rooms
    end
    
    remaining_rooms_to_check = sector_subrooms.dup
    remaining_rooms_to_check -= @transition_rooms unless include_transitions
    while remaining_rooms_to_check.any?
      current_subsector = []
      puts "STARTING NEW SUBSECTOR" if debug
      current_room = remaining_rooms_to_check.first
      while true
        puts "Current room: #{current_room.room_str}" if debug
        
        remaining_rooms_to_check.delete(current_room)
        
        if options[:randomize_rooms_map_friendly] && room_strs_unused_by_map_rando.include?(current_room.room_str)
          # Skip rooms not used by the map friendly room randomizer.
          remaining_subsector_rooms = current_subsector & remaining_rooms_to_check
          break if remaining_subsector_rooms.empty?
          current_room = remaining_subsector_rooms.first
          
          next
        end
        
        current_room_doors = current_room.doors.reject{|door| checker.inaccessible_doors.include?(door.door_str)}
        current_room_doors = current_room_doors.reject{|door| door.destination_room_metadata_ram_pointer == 0} # Door dummied out by the map-friendly room randomizer.
        
        if current_room_doors.empty?
          # Unused room with no door. Don't add it to the list of rooms in the subsector.
          remaining_subsector_rooms = current_subsector & remaining_rooms_to_check
          break if remaining_subsector_rooms.empty?
          current_room = remaining_subsector_rooms.first
          
          next
        end
        
        current_subsector << current_room
        
        connected_dest_door_strs = current_room_doors.map{|door| door.destination_door.door_str}
        connected_rooms = sector_subrooms.select do |room|
          (room.doors.map{|d| d.door_str} & connected_dest_door_strs).any?
        end
        if GAME == "dos" && current_room.sector.name == "Condemned Tower & Mine of Judgment"
          # Need to split Condemned Tower from Mine of Judgement into separate subsectors.
          if current_room.room_ypos_on_map >= 0x17
            # Current subsector is Mine of Judgement, so remove Condemned Tower rooms.
            connected_rooms.reject!{|room| room.room_ypos_on_map < 0x17}
          else
            # Current subsector is Condemned Tower, so remove Mine of Judgement rooms.
            connected_rooms.reject!{|room| room.room_ypos_on_map >= 0x17}
          end
        end
        unless include_transitions
          connected_rooms.reject!{|connected_room| transition_room_strs.include?(connected_room.room_str)}
        end
        current_subsector += connected_rooms
        current_subsector.uniq!
        
        puts "Current subsector so far: #{current_subsector.map{|room| room.room_str}}" if debug
        puts "Remaining rooms to check: #{remaining_rooms_to_check.map{|room| room.room_str}}" if debug
        
        puts "A: #{current_subsector.map{|x| x.class.to_s}.join(", ")}" if debug
        puts "B: #{remaining_rooms_to_check.map{|x| x.class.to_s}.join(", ")}" if debug
        
        remaining_subsector_rooms = current_subsector & remaining_rooms_to_check
        break if remaining_subsector_rooms.empty?
        current_room = remaining_subsector_rooms.first
      end
      subsectors += [current_subsector]
    end
    
    return subsectors
  end
  
  def get_valid_doors(rooms, sector)
    remaining_doors = {
      left: [],
      up: [],
      right: [],
      down: []
    }
    
    map = game.get_map(sector.area_index, sector.sector_index)
    
    rooms.each do |room|
      next if @transition_rooms.include?(room)
      
      room.doors.each do |door|
        next if @transition_rooms.include?(door.destination_door.room)
        next if checker.inaccessible_doors.include?(door.door_str)
        
        if GAME == "dos" && ["00-01-1C_001", "00-01-20_000"].include?(door.door_str)
          # Don't randomize the door connecting Paranoia and Mini-Paranoia.
          next
        end
        if GAME == "dos" && ["00-05-0C_001", "00-05-18_000"].include?(door.door_str)
          # Don't randomize the up/down door connecting Condemned Tower and Mine of Judgement.
          next
        end
        if GAME == "por" && ["00-01-04_001", "00-01-03_005", "00-01-03_000", "00-01-18_000", "00-01-03_004", "00-01-06_000", "00-01-06_001", "00-01-09_000"].include?(door.door_str)
          # Don't randomize the rooms around the Entrance hub (warp room, Wind, shop, etc).
          next
        end
        if GAME == "ooe" && ["0C-00-0E_000", "0C-00-0F_000", "0C-00-0F_001", "0C-00-10_000"].include?(door.door_str)
          # Don't randomize the doors in Large Cavern connecting the warp room, one-way room, and boss room.
          next
        end
        
        map_tile_x_pos = room.room_xpos_on_map
        map_tile_y_pos = room.room_ypos_on_map
        
        if door.x_pos == 0xFF
          # Do nothing
        elsif door.x_pos >= room.main_layer_width
          map_tile_x_pos += room.main_layer_width - 1
        else
          map_tile_x_pos += door.x_pos
        end
        if door.y_pos == 0xFF
          # Do nothing
        elsif door.y_pos >= room.main_layer_height
          map_tile_y_pos += room.main_layer_height - 1
        else
          map_tile_y_pos += door.y_pos
        end
        
        map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos &&  tile.y_pos == map_tile_y_pos}
        
        if map_tile.nil?
          # Door that's not on the map, just an unused door.
          next
        end
        
        # If the door is shown on the map as a wall, skip it.
        # Those are leftover doors not intended to be used, and are inaccessible (except with warp glitches).
        case door.direction
        when :left
          next if map_tile.left_wall
        when :right
          next if map_tile.right_wall
          if GAME == "dos" || GAME == "aos"
            # Right walls in DoS are handled as the left wall of the tile to the right.
            right_map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos+1 &&  tile.y_pos == map_tile_y_pos}
            next if right_map_tile.left_wall
          end
        when :up
          next if map_tile.top_wall
        when :down
          next if map_tile.bottom_wall
          if GAME == "dos" || GAME == "aos"
            # Bottom walls in DoS are handled as the top wall of the tile below.
            below_map_tile = map.tiles.find{|tile| tile.x_pos == map_tile_x_pos &&  tile.y_pos == map_tile_y_pos+1}
            next if below_map_tile.top_wall
          end
        end
        
        remaining_doors[door.direction] << door
      end
    end
    
    return remaining_doors
  end
  
  def remove_door_blockers
    obj_subtypes_to_remove = case GAME
    when "dos"
      [0x43, 0x44, 0x46, 0x57, 0x1E, 0x2B, 0x26, 0x2A, 0x29, 0x45, 0x24, 0x37, 0x04]
    when "por"
      [0x37, 0x30, 0x89, 0x38, 0x2F, 0x36, 0x32, 0x31, 0x88, 0x26, 0x46, 0x41, 0x2E, 0x40, 0x83]
    when "ooe"
      [0x5B, 0x5A, 0x59]
    end
    
    breakable_wall_subtype = case GAME
    when "dos"
      nil # All breakable walls are path blocking in DoS, so they're instead included in obj_subtypes_to_remove.
    when "por"
      0x3B
    when "ooe"
      0x5C
    end
    
    game.each_room do |room|
      room.entities.each do |entity|
        if entity.is_special_object? && obj_subtypes_to_remove.include?(entity.subtype)
          entity.type = 0
          entity.write_to_rom()
        elsif entity.is_special_object? && entity.subtype == breakable_wall_subtype
          case GAME
          when "por"
            PATH_BLOCKING_BREAKABLE_WALLS.each do |wall_data|
              if entity.var_a == wall_data[:var_a] && entity.room.area_index == wall_data[:area_index] && (entity.room.area_index != 0 || entity.room.sector_index == wall_data[:sector_index])
                entity.type = 0
                entity.write_to_rom()
                break
              end
            end
          when "ooe"
            PATH_BLOCKING_BREAKABLE_WALLS.each do |wall_vars|
              if entity.var_a == wall_vars[:var_a] && entity.var_b == wall_vars[:var_b]
                entity.type = 0
                entity.write_to_rom()
                break
              end
            end
          end
        end
      end
    end
    
    case GAME
    when "dos"
      # Remove the water from the drawbridge room.
      drawbridge_room_waterlevel = game.entity_by_str("00-00-15_04")
      drawbridge_room_waterlevel.type = 0
      drawbridge_room_waterlevel.write_to_rom()
      
      # Remove the cutscene with Yoko before Flying Armor since it doesn't work properly if you don't have Yoko with you.
      pre_flying_armor_room = game.room_by_str("00-00-0E")
      [9, 0xA, 0xB].each do |entity_index|
        entity = pre_flying_armor_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
      
      # Remove the cutscene with Dmitrii because it doesn't work properly when you enter from the left side.
      dmitrii_room = game.room_by_str("00-04-10")
      [3, 4, 6, 7].each do |entity_index|
        entity = dmitrii_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
      # And change Dmitrii to boss rush Dmitrii so he doesn't crash when there's no event.
      dmitrii = dmitrii_room.entities[5]
      dmitrii.var_a = 0
      dmitrii.write_to_rom()
      
      # Remove the cutscene with Dario because it doesn't work properly when you enter from the left side.
      dario_room = game.room_by_str("00-03-0B")
      [2, 3, 4, 6].each do |entity_index|
        entity = dario_room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    when "por"
      # The whole drill cart puzzle from City of Haze was removed.
      # So let's also remove the entity hider so that the enemies from the alternate game modes appear.
      drill_room_entity_hider = game.entity_by_str("01-01-04_02")
      drill_room_entity_hider.type = 0
      drill_room_entity_hider.write_to_rom()
    when "ooe"
      # Remove the small gate in Forsaken Cloiser, but not the big gate in Final Approach.
      forsaken_cloister_gate = game.entity_by_str("00-09-06_00")
      forsaken_cloister_gate.type = 0
      forsaken_cloister_gate.write_to_rom()
    end
    
    # Remove breakable walls from the map as well so it matches visually with the level design.
    maps = []
    if GAME == "dos"
      maps << game.get_map(0, 0)
      maps << game.get_map(0, 0xA)
    else
      AREA_INDEX_TO_OVERLAY_INDEX.keys.each do |area_index|
        maps << game.get_map(area_index, 0)
      end
    end
    maps.each do |map|
      map.tiles.each do |tile|
        if tile.left_secret
          tile.left_secret = false
          tile.left_door = true
        end
        if tile.top_secret
          tile.top_secret = false
          tile.top_door = true
        end
        if tile.right_secret
          tile.right_secret = false
          tile.right_door = true
        end
        if tile.bottom_secret
          tile.bottom_secret = false
          tile.bottom_door = true
        end
      end
      map.write_to_rom()
    end
  end
  
  def replace_outer_boss_doors
    boss_rooms = []
    if GAME == "dos"
      boss_rooms << game.room_by_str("00-03-0E") # Doppelganger event room
    end
    
    # Make a list of boss rooms to fix the boss doors for.
    game.each_room do |room|
      next if room.area.name == "Ecclesia"
      next if room.area.name == "Unused Boss Rush"
      
      if options[:randomize_rooms_map_friendly] && @rooms_unused_by_map_rando.include?(room)
        # Skip rooms not used by the map friendly room randomizer.
        next
      end
      
      room.entities.each do |entity|
        if entity.is_boss_door?
          if entity.var_a == 0
            # Boss door outside a boss room. Remove it.
            entity.type = 0
            entity.write_to_rom()
          elsif GAME == "dos" || entity.var_a == 1
            # Boss door inside a boss room. Keep track of it.
            boss_rooms << room
          elsif entity.var_a == 2
            if room.entities.any?{|e| e.is_enemy?}
              # Nest of Evil/Large Cavern enemy room. (Or PoR Dracula's boss room.)
              boss_rooms << room
            else
              # Nest of Evil/Large Cavern empty room. Remove the boss door.
              entity.type = 0
              entity.write_to_rom()
            end
          end
        end
      end
    end
    
    
    # Replace boss doors.
    boss_rooms.uniq.each do |boss_room|
      if GAME == "dos" && boss_room.room_str == "00-03-0E"
        # Doppelganger event room. Put two boss doors as a warning that it might get you a bad ending if you're not prepared.
        boss_index = 0xE
        num_boss_doors_on_each_side = 2
      else
        boss_index = boss_room.entities.find{|e| e.is_boss_door?}.var_b
        num_boss_doors_on_each_side = 1
      end
      if GAME == "dos" && boss_room.room_str == "00-09-01"
        # Aguni's boss room. Put two boss doors since this can also lead to a bad ending.
        num_boss_doors_on_each_side = 2
      end
      if GAME == "por" && boss_room.room_str == "00-0B-01"
        # Sisters' boss room. Put two boss doors since this can also lead to a bad ending.
        num_boss_doors_on_each_side = 2
      end
      
      doors = boss_room.doors
      if GAME == "dos" && boss_index == 7 # Gergoth
        doors = doors[0..1] # Only do the top two doors in the tower.
      end
      
      doors.each do |door|
        next unless [:left, :right].include?(door.direction)
        next if checker.inaccessible_doors.include?(door.door_str)
        
        dest_door = door.destination_door
        dest_room = dest_door.room
        
        # Don't add a boss door when two boss rooms are connected to each other, that would result in overlapping boss doors.
        if boss_rooms.include?(dest_room)
          if GAME == "dos" && dest_room.room_str == "00-05-07"
            # Special exception for Gergoth's boss room connecting back in on another lower part of his tower.
            # We do add the boss door in this case.
          else
            next
          end
        end
        
        gap_start_index, gap_end_index, tiles_in_biggest_gap = get_biggest_door_gap(dest_door)
        gap_end_offset = gap_end_index * 0x10 + 0x10
        
        num_boss_doors_on_each_side.times do |dup_boss_door_num|
          new_boss_door = Entity.new(dest_room, game.fs)
          new_boss_door.x_pos = door.dest_x
          new_boss_door.y_pos = door.dest_y + gap_end_offset
          if door.direction == :left
            new_boss_door.x_pos += 0xF0 - dup_boss_door_num*0x10
          else
            new_boss_door.x_pos += dup_boss_door_num*0x10
          end
          
          new_boss_door.type = 2
          new_boss_door.subtype = BOSS_DOOR_SUBTYPE
          new_boss_door.var_a = 0
          new_boss_door.var_b = boss_index
          
          dest_room.entities << new_boss_door
          dest_room.write_entities_to_rom()
        end
      end
    end
    
    
    # Fix Nest of Evil/Large Cavern boss doors.
    game.each_room do |room|
      next unless room.area.name == "Nest of Evil" || room.area.name == "Large Cavern"
      
      room_has_enemies = room.entities.find{|e| e.type == 1}
      
      room.entities.each do |entity|
        if entity.is_boss_door? && entity.var_a == 2
          # Boss door in Nest of Evil/Large Cavern that never opens.
          if room_has_enemies
            # We switch these to the normal ones that open when the room is cleared so the player can progress even with rooms randomized.
            entity.var_a = 1
          else
            # This is one of the vertical corridors with no enemies. A normal boss door wouldn't open here since there's no way to clear a room with no enemies.
            # So instead just delete the door.
            entity.type = 0
          end
          entity.write_to_rom()
        end
      end
    end
  end
  
  def center_bosses_for_room_rando
    # Move some bosses to the center of their room so the player doesn't get hit by them as soon as they enter from the wrong side.
    case GAME
    when "dos"
      abaddon = game.entity_by_str("00-0B-13_00")
      abaddon.x_pos = 0x80
      abaddon.write_to_rom()
    when "por"
      behemoth = game.entity_by_str("00-00-09_02")
      behemoth.x_pos = 0x100
      behemoth.write_to_rom()
      
      creature = game.entity_by_str("08-00-04_00")
      creature.x_pos = 0x100
      creature.write_to_rom()
      
      abaddon = game.entity_by_str("09-00-2F_02")
      abaddon.x_pos = 0x80
      abaddon.write_to_rom()
    when "ooe"
      arthroverta = game.entity_by_str("12-00-13_00")
      arthroverta.x_pos = 0x80
      arthroverta.write_to_rom()
      
      # If you enter Gravedorcus's room from the left he appears on top of you.
      # So we change his initial state from 2 (appearing at the left and moving through the sand to the right) to 5 (appearing and spitting to the right).
      game.fs.load_overlay(33)
      game.fs.write(0x022B8568, [5].pack("C"))
      # Also skip the intro when entering from the right so it's consistent with the lack of intro from the left. Remove the branch instruction that goes to the intro.
      game.fs.write(0x022BA230, [0xE1A00000].pack("V"))
    end
  end
  
  def line_up_door(door)
    # Sometimes two doors don't line up perfectly. For example if the opening is at the bottom of one room but the middle of the other.
    # We change the dest_x/dest_y of these so they line up correctly.
    
    dest_door = door.destination_door
    dest_room = dest_door.room
    
    case door.direction
    when :left
      left_door = door
      right_door = dest_door
    when :right
      right_door = door
      left_door = dest_door
    when :up
      up_door = door
      down_door = dest_door
    when :down
      down_door = door
      up_door = dest_door
    end
    
    if GAME == "por" && left_door && left_door.destination_room.room_str == "00-01-07"
      # Left door that leads into the Behemoth chase sequence room.
      # If the player enters through this door first instead of from the normal direction, they can get stuck in the gate at the right side of the room.
      # Give it an x offset 2 blocks to the left so the player gets past the gate.
      left_door.dest_x_2 -= 0x20
    end
    
    case door.direction
    when :left, :right
      left_first_tile_i, left_last_tile_i, left_tiles_in_biggest_gap = get_biggest_door_gap(left_door)
      right_first_tile_i, right_last_tile_i, right_tiles_in_biggest_gap = get_biggest_door_gap(right_door)
      
      unless left_last_tile_i == right_last_tile_i
        left_door_dest_y_offset = (right_last_tile_i - left_last_tile_i) * 0x10
        right_door_dest_y_offset = (left_last_tile_i - right_last_tile_i) * 0x10
        
        # We use the unused dest offsets because they still work fine and this way we don't mess up the code Door#destination_door uses to guess the destination door, since that's based off the used dest_x and dest_y.
        left_door.dest_y_2 = left_door_dest_y_offset
        right_door.dest_y_2 = right_door_dest_y_offset
      end
      
      # If the door is very tiny and the player must slide through it, then the player would get softlocked if the door was connected to a boss door on the other side.
      # This is because control is taken away from the player and the automatic walk AI isn't smart enough to slide to get out of the gap. (The boss cutscene removes the player's momentum, so even if the player entered the room sliding it wouldn't work.)
      # So we warp the player just slightly past the wall on the other side so sliding to get out isn't necessary.
      if left_tiles_in_biggest_gap.size <= 2
        left_door.dest_x_2 -= 0x10
      end
      if right_tiles_in_biggest_gap.size <= 2
        right_door.dest_x_2 += 0x10
      end
      
      # If the gaps are not the same size we need to block off part of the bigger gap so that they are the same size.
      # Otherwise the player could enter a room inside a solid wall, and get thrown out of bounds.
      if left_tiles_in_biggest_gap.size < right_tiles_in_biggest_gap.size
        num_tiles_to_remove = right_tiles_in_biggest_gap.size - left_tiles_in_biggest_gap.size
        tiles_to_remove = right_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        # For those huge doorways that take up the entire screen (e.g. Kalidus), we want to make sure the bottommost tile of that screen is solid so it's properly delineated from the doorway of the screen below.
        if right_tiles_in_biggest_gap.size == SCREEN_HEIGHT_IN_TILES
          # We move up the gap by one block.
          tiles_to_remove = tiles_to_remove[0..-2]
          tiles_to_remove << right_tiles_in_biggest_gap.last
          
          # Then we also have to readjust the dest y offsets.
          left_door.dest_y_2 -= 0x10
          right_door.dest_y_2 += 0x10
        end
        
        block_off_tiles(right_door.room, tiles_to_remove)
      elsif right_tiles_in_biggest_gap.size < left_tiles_in_biggest_gap.size
        num_tiles_to_remove = left_tiles_in_biggest_gap.size - right_tiles_in_biggest_gap.size
        tiles_to_remove = left_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        # For those huge doorways that take up the entire screen (e.g. Kalidus), we want to make sure the bottommost tile of that screen is solid so it's properly delineated from the doorway of the screen below.
        if left_tiles_in_biggest_gap.size == SCREEN_HEIGHT_IN_TILES
          # We move up the gap by one block.
          tiles_to_remove = tiles_to_remove[0..-2]
          tiles_to_remove << left_tiles_in_biggest_gap.last
          
          # Then we also have to readjust the dest y offsets.
          right_door.dest_y_2 -= 0x10
          left_door.dest_y_2 += 0x10
        end
        
        block_off_tiles(left_door.room, tiles_to_remove)
      end
      
      left_door.write_to_rom()
      right_door.write_to_rom()
    when :up, :down
      up_first_tile_i, up_last_tile_i, up_tiles_in_biggest_gap = get_biggest_door_gap(up_door)
      down_first_tile_i, down_last_tile_i, down_tiles_in_biggest_gap = get_biggest_door_gap(down_door)
      
      unless up_last_tile_i == down_last_tile_i
        up_door_dest_x_offset = (down_last_tile_i - up_last_tile_i) * 0x10
        down_door_dest_x_offset = (up_last_tile_i - down_last_tile_i) * 0x10
        
        # We use the unused dest offsets because they still work fine and this way we don't mess up the code Door#destination_door uses to guess the destination door, since that's based off the used dest_x and dest_y.
        up_door.dest_x_2 = up_door_dest_x_offset
        down_door.dest_x_2 = down_door_dest_x_offset
      end
      
      # If the gaps are not the same size we need to block off part of the bigger gap so that they are the same size.
      # Otherwise the player could enter a room inside a solid wall, and get thrown out of bounds.
      if up_tiles_in_biggest_gap.size < down_tiles_in_biggest_gap.size
        num_tiles_to_remove = down_tiles_in_biggest_gap.size - up_tiles_in_biggest_gap.size
        tiles_to_remove = down_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        block_off_tiles(down_door.room, tiles_to_remove)
      elsif down_tiles_in_biggest_gap.size < up_tiles_in_biggest_gap.size
        num_tiles_to_remove = up_tiles_in_biggest_gap.size - down_tiles_in_biggest_gap.size
        tiles_to_remove = up_tiles_in_biggest_gap[0, num_tiles_to_remove]
        
        block_off_tiles(up_door.room, tiles_to_remove)
      end
      
      up_door.write_to_rom()
      down_door.write_to_rom()
    end
  end
  
  def get_biggest_door_gap(door)
    coll = RoomCollision.new(door.room, game.fs)
    
    tiles = []
    
    case door.direction
    when :left, :right
      if door.direction == :left
        x = 0
      else
        x = door.x_pos*SCREEN_WIDTH_IN_TILES - 1
      end
      
      y_start = door.y_pos*SCREEN_HEIGHT_IN_TILES
      (y_start..y_start+SCREEN_HEIGHT_IN_TILES-1).each_with_index do |y, i|
        is_solid = coll[x*0x10,y*0x10].is_solid?
        tiles << {is_solid: is_solid, i: i, x: x, y: y}
      end
      
      # Keep track of gaps that extend all the way to the top/bottom of the room so we can ignore these gaps later.
      bottom_y_of_top_edge_gap = -1
      (0..door.room.height*SCREEN_HEIGHT_IN_TILES-1).each do |y|
        if coll[x*0x10,y*0x10].is_solid?
          break
        else
          bottom_y_of_top_edge_gap = y
        end
      end
      top_y_of_bottom_edge_gap = door.room.height*SCREEN_HEIGHT_IN_TILES
      (0..door.room.height*SCREEN_HEIGHT_IN_TILES-1).reverse_each do |y|
        if coll[x*0x10,y*0x10].is_solid?
          break
        else
          top_y_of_bottom_edge_gap = y
        end
      end
    when :up, :down
      if door.direction == :up
        y = 0
      else
        y = door.y_pos*SCREEN_HEIGHT_IN_TILES - 1
        
        if GAME == "por" && door.room.room_str == "03-01-01"
          # One specific room in sandy grave doesn't have any tiles at the very bottom row. Instead we use the row second closest to the bottom.
          y -= 1
        end
      end
      
      x_start = door.x_pos*SCREEN_WIDTH_IN_TILES
      (x_start..x_start+SCREEN_WIDTH_IN_TILES-1).each_with_index do |x, i|
        is_solid = coll[x*0x10,y*0x10].is_solid?
        tiles << {is_solid: is_solid, i: i, x: x, y: y}
      end
      
      
      # Keep track of gaps that extend all the way to the left/right of the room so we can ignore these gaps later.
      right_x_of_left_edge_gap = -1
      (0..door.room.width*SCREEN_WIDTH_IN_TILES-1).each do |x|
        if coll[x*0x10,y*0x10].is_solid?
          break
        else
          right_x_of_left_edge_gap = x
        end
      end
      left_x_of_right_edge_gap = door.room.width*SCREEN_WIDTH_IN_TILES
      (0..door.room.width*SCREEN_WIDTH_IN_TILES-1).reverse_each do |x|
        if coll[x*0x10,y*0x10].is_solid?
          break
        else
          left_x_of_right_edge_gap = x
        end
      end
    end
    
    chunks = tiles.chunk{|tile| tile[:is_solid]}
    gaps = chunks.select{|is_solid, tiles| !is_solid}.map{|is_solid, tiles| tiles}
    
    # Try to limit to gaps that aren't touching the edge of the room if possible.
    case door.direction
    when :left, :right
      gaps_not_on_room_edge = gaps.reject do |tiles|
        if tiles.first[:y] <= bottom_y_of_top_edge_gap
          true
        elsif tiles.last[:y] >= top_y_of_bottom_edge_gap
          true
        else
          false
        end
      end
    when :up, :down
      gaps_not_on_room_edge = gaps.reject do |tiles|
        if tiles.first[:x] <= right_x_of_left_edge_gap
          true
        elsif tiles.last[:x] >= left_x_of_right_edge_gap
          true
        else
          false
        end
      end
    end
    if gaps_not_on_room_edge.any?
      gaps = gaps_not_on_room_edge
    end
    
    if gaps.empty?
      raise "Door #{door.door_str} has no gaps."
    end
    
    size_of_biggest_gap = gaps.max_by{|tiles| tiles.length}.length
    possible_biggest_gaps = gaps.select{|tiles| tiles.length == size_of_biggest_gap}
    if possible_biggest_gaps.size == 1
      tiles_in_biggest_gap = possible_biggest_gaps.first
    else
      # There are multiple gaps that are all the biggest size.
      # We need to get the centermost gap.
      center_position_of_screen = case door.direction
      when :left, :right
        (SCREEN_HEIGHT_IN_TILES-1)/2.0
      when :up, :down
        (SCREEN_WIDTH_IN_TILES-1)/2.0
      end
      
      centermost_gap = gaps.min_by do |tiles|
        gap_center_position = tiles.inject(0){|sum, tile| sum + tile[:i]}.to_f / tiles.size
        (center_position_of_screen - gap_center_position).abs
      end
      
      tiles_in_biggest_gap = centermost_gap
    end
    first_tile_i = tiles_in_biggest_gap.first[:i]
    last_tile_i = tiles_in_biggest_gap.last[:i]
    
    return [first_tile_i, last_tile_i, tiles_in_biggest_gap]
  end
  
  def block_off_tiles(room, tiles)
    room.sector.load_necessary_overlay()
    coll_layer = room.layers.first
    solid_tile_index_on_tileset = SOLID_BLOCKADE_TILE_INDEX_FOR_TILESET[room.overlay_id][coll_layer.collision_tileset_pointer]
    
    tiles.each do |tile|
      tile_i = tile[:x] + tile[:y]*SCREEN_WIDTH_IN_TILES*coll_layer.width
      coll_layer.tiles[tile_i].index_on_tileset = solid_tile_index_on_tileset
      coll_layer.tiles[tile_i].horizontal_flip = false
      coll_layer.tiles[tile_i].vertical_flip = false
    end
    coll_layer.write_to_rom()
  end
end
