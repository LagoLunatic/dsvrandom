
module Tweaks
  def apply_pre_randomization_tweaks
    @tiled = TMXInterface.new
    
    if GAME == "dos"
      # Make the drawbridge stay permanently down once the player has lowered it.
      game.apply_armips_patch("dos_drawbridge_stays_down")
      
      # And also modify the level design of the drawbridge room so you can go up and down even when the drawbridge is closed.
      filename = "./dsvrandom/roomedits/dos_room_rando_00-00-15.tmx"
      room = game.areas[0].sectors[0].rooms[0x15]
      tiled.read(filename, room)
    end
    
    if GAME == "dos"
      # Modify the level design of the room after Flying Armor to not require a backdash jump to go from right to left.
      filename = "./dsvrandom/roomedits/dos_00-00-08.tmx"
      room = game.areas[0].sectors[0].rooms[8]
      tiled.read(filename, room)
    end
    
    if GAME == "ooe" && options[:open_world_map]
      game.apply_armips_patch("ooe_nonlinear")
    end
    
    if GAME == "ooe" && options[:open_world_map] && !room_rando?
      # Fix some broken platforms in Tristis Pass so the player cannot become permastuck.
      layer = game.areas[0xB].sectors[0].rooms[2].layers.first
      layer.tiles[0xD1].index_on_tileset = 0x378
      layer.tiles[0xD2].index_on_tileset = 0x378
      layer.write_to_rom()
      layer = game.areas[0xB].sectors[0].rooms[4].layers.first
      layer.tiles[0x31].index_on_tileset = 0x37C
      layer.tiles[0x32].index_on_tileset = 0x37C
      layer.tiles[0x121].index_on_tileset = 0x378
      layer.tiles[0x122].index_on_tileset = 0x378
      layer.tiles[0x1BD].index_on_tileset = 0x37C
      layer.tiles[0x1BE].index_on_tileset = 0x37C
      layer.tiles[0x2AD].index_on_tileset = 0x378
      layer.tiles[0x2AE].index_on_tileset = 0x378
      layer.write_to_rom()
    end
    
    if GAME == "ooe"
      # Fixes a crash that happens if you exit the Lighthouse and enter Kalidus without having entered Kalidus before the Lighthouse.
      game.apply_armips_patch("ooe_fix_kalidus_back_entrance_crash")
    end
    
    if GAME == "ooe"
      # We need to unset the prerequisite event flag for certain events manually.
      # The ooe_nonlinear patch does this but we might already have those rooms cached by now in memory so the changes won't get read in correctly.
      # Also, we unset these event flags even if the nonlinear option is off just in case the player sequence breaks the game somehow.
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && [0x69, 0x6B, 0x6C, 0x6F, 0x71, 0x74, 0x7E, 0x85].include?(entity.subtype)
            entity.var_b = 0
            entity.write_to_rom()
          end
        end
      end
    end
    
    if GAME == "dos" && room_rando?
      # Remove the special code for the slide puzzle.
      game.fs.write(0x0202738C, [0xE3A00000, 0xE8BD41F0, 0xE12FFF1E].pack("V*"))
      
      # Next we remove the walls on certain rooms so the dead end rooms are accessible and fix a couple other things in the level design.
      [0xE, 0xF, 0x14, 0x15, 0x19].each do |room_index|
        # 5 room: Remove floor and move the item off where the floor used to be.
        # 6 room: Remove left wall.
        # 11 room: Remove right wall.
        # 12 room: Remove ceiling.
        # Empty room: Add floor so the player can't fall out of bounds.
        
        room = game.areas[0].sectors[1].rooms[room_index]
        filename = "./dsvrandom/roomedits/dos_room_rando_00-01-%02X.tmx" % room_index
        tiled.read(filename, room)
      end
      
      # Now remove the wall entities in each room and the control panel entity.
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && [0x0C, 0x0D].include?(entity.subtype)
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
      
      # Change regular Gergoth's code to act like boss rush Gergoth and not break the floor.
      # (We can't just use boss rush Gergoth himself because he wakes up whenever you're in the room, even if you're in a lower part of the tower.)
      game.fs.load_overlay(36)
      game.fs.write(0x02303AB4, [0xE3A01000].pack("V")) # mov r1, 0h
      game.fs.write(0x02306D70, [0xE3A00000].pack("V")) # mov r0, 0h
      # And modify the code of the floors to not care if Gergoth's boss death flag is set, and just always be in place.
      game.fs.write(0x0219EF40, [0xE3A00000].pack("V")) # mov r0, 0h
      
      # Apply a patch to make Gergoth move to the right if the player enters from the left so he's not on top of the player.
      game.apply_armips_patch("dos_gergoth_either_side")
      
      # When starting a new game, don't unlock the Lost Village warp by default.
      game.fs.write(0x021F6054, [0xE1A00000].pack("V"))
    end
    
    if GAME == "por" && room_rando?
      # Modify several split doors, where there are two different gaps in the level design, to only have one gap instead.
      # This is because the logic doesn't support multi-gap doors.
      ["07-00-07", "07-00-0A", "07-00-0B", "07-00-0D", "08-02-18", "08-02-19"].each do |room_str|
        room = game.room_by_str(room_str)
        filename = "./dsvrandom/roomedits/por_room_rando_#{room_str}.tmx"
        tiled.read(filename, room)
      end
    end
    
    if GAME == "ooe" && room_rando?
      # Make the frozen waterfall always be unfrozen. (Only the bottom part, the part at the top will still be frozen.)
      game.fs.load_overlay(57)
      game.fs.write(0x022C2CAC, [0xE3E01000].pack("V"))
      
      # The Giant Skeleton boss room will softlock the game if the player enters from the right side.
      # So we get rid of the searchlights that softlock the game and modify the Giant Skeleton boss's AI to wake up like a non-boss Giant Skeleton.
      searchlights = game.entity_by_str("08-00-02_03")
      searchlights.type = 0
      searchlights.write_to_rom()
      game.fs.write(0x02277EFC, [0xE3A01000].pack("V"))
      
      # Modify the level design of three Tymeo rooms where they have a platform at the bottom door, but only on either the left or right edge of the screen.
      # If the upwards door connected to one of these downwards doors doesn't have a platform on the same side of the screen, the player won't be able to get up.
      # So we place a large platform across the center of the bottom of these three rooms so the player can walk across it.
      [0x8, 0xD, 0x12].each do |room_index|
        room = game.areas[0xA].sectors[0].rooms[room_index]
        filename = "./dsvrandom/roomedits/ooe_room_rando_0A-00-%02X.tmx" % room_index
        tiled.read(filename, room)
      end
    end
    
    case GAME
    when "por", "ooe"
      game.each_room do |room|
        room.entities.each_with_index do |entity, entity_index|
          if entity.type == 8 && entity.byte_8 == 0
            # This is an entity hider that removes all remaining entities in the room.
            if entity_index == room.entities.size - 1
              # If the entity hider is the last entity in the room we just remove it entirely since it's not doing anything and we can't have it remove 0 entities.
              entity.type = 0
              entity.write_to_rom()
            else
              # Otherwise, we need to change it to only remove the number of entities remaining in the vanilla game.
              # This way, even if we add new entities to this room later, the new entity will show up.
              entity.byte_8 = room.entities.size - entity_index - 1
              entity.write_to_rom()
            end
          end
        end
      end
    when "dos"
      game.each_room do |room|
        room.entities.each_with_index do |entity, entity_index|
          if entity.type == 6
            # This is an entity hider. In DoS, entity hiders always remove all remaining entities in the room.
            if entity_index == room.entities.size - 1
              # If the entity hider is the last entity in the room we just remove it entirely since it's not doing anything and we can't have it remove 0 entities.
              entity.type = 0
              entity.write_to_rom()
            elsif room.room_str == "00-01-20"
              # Mini-Paranoia room. This hides the item inside Mini-Paranoia's mirror until Paranoia is dead.
              # We remove this so the item appears always.
              entity.type = 0
              entity.write_to_rom()
            else
              # Otherwise, there's no easy way to fix this problem like in PoR/OoE, since in DoS entity hiders always hide all remaining entities.
              # So just do nothing and hope this isn't an issue. It probably won't be since it's only a few event rooms and boss rooms that use these anyway.
              # TODO?
            end
          end
        end
      end
    end
    
    if GAME == "dos"
      # Remove the event where Yoko talks to you outside Flying Armor's room.
      # This event can look weird and make the player think the game has softlocked if the player views it after killing Flying Armor.
      room = game.room_by_str("00-00-0E")
      [9, 0xA, 0xB].each do |entity_index| # Event, font loader, and entity hider
        entity = room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    end
    
    if GAME == "dos"
      # Remove the event with Celia, Julius and Arikado in Cursed Clock Tower.
      # This event is useless, and it can softlock if the map randomizer blocks off the left wall because that prevents Arikado from leaving the room.
      room = game.room_by_str("00-08-1E")
      [2, 3, 4].each do |entity_index| # Event, font loader, and entity hider
        entity = room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    end
    
    if GAME == "dos" && options[:randomize_rooms_map_friendly]
      # Remove the cutscene where Yoko gives you a magic seal in the drawbridge room for map rando.
      # This cutscene puts you in the topleft door - but that door might be removed and blocked off in map rando, in which case the player will be put out of bounds.
      room = game.room_by_str("00-00-15")
      [9, 0xC, 0xD].each do |entity_index| # Event, font loader, and entity hider
        # TODO: the entity indexes got shifted around beforehand, so this removes the wrong entity
        entity = room.entities[entity_index]
        entity.type = 0
        entity.write_to_rom()
      end
    end
    
    if GAME == "dos"
      # Hellfire's iframes line was originally coded to just copy register r4 (containing 1) into register r1.
      # Change this to a constant "mov r1, 1h" so the iframes value can be directly written to when skill behavior rando is on.
      game.fs.write(0x022035CC, [0xE3A01001].pack("V"))
    end
    
    if GAME == "ooe" && options[:gain_extra_attribute_points]
      # Make every enemy give 25x more AP than normal.
      game.enemy_dnas.each do |enemy|
        enemy["AP"] = 1 if enemy["AP"] < 1
        enemy["AP"] *= 25
        enemy["AP"] = 0xFF if enemy["AP"] > 0xFF
        enemy.write_to_rom()
      end
      
      # Make absorbing a glyph give 25 AP instead of 1.
      game.fs.write(0x0206D994, [25].pack("C"))
    end
    
    # Add a free space overlay so we can add entities as much as we want.
    if !game.fs.has_free_space_overlay?
      game.add_new_overlay()
    end
    
    # Now apply any ASM patches that go in the free space overlay first.
    
    if options[:add_magical_tickets] && GAME == "dos"
      dos_implement_magical_tickets()
    end
    
    if GAME == "por" && options[:randomize_portraits]
      # We apply a patch in portrait randomizer that will show a text popup when the player tries to enter the Forest of Doom early.
      # Without this patch there is no indication as to why you can't enter the portrait, as the normal event doesn't work outside the sector the portrait is normally in.
      game.apply_armips_patch("por_show_popup_for_locked_portrait")
      game.text_database.text_list[0x4BE].decoded_string = "You must beat Stella and talk to Wind\\nto unlock the Forest of Doom."
      game.text_database.write_to_rom()
    end
    
    # Fix the bugs where an incorrect map tile would get revealed when going through doors in the room randomizer (or sliding puzzle in vanilla DoS).
    if GAME == "dos"
      game.apply_armips_patch("dos_fix_map_explore_bug")
    end
    if GAME == "por"
      game.apply_armips_patch("por_fix_map_explore_bug")
    end
    
    # When portrait rando is on we need to be able to change the X/Y pos each return portrait places you at individually.
    # This patch recodes how the X/Y dest pos work so that they can be easily changed by the pickup randomizer later.
    if GAME == "por" && options[:randomize_portraits]
      game.apply_armips_patch("por_distinct_return_portrait_positions")
    end
    
    if GAME == "ooe" && room_rando?
      # Fix softlocks that happen when entering the Lighthouse from the wrong door.
      # If entering from the bottom right there's a wall that blocks it. That is removed.
      # If entering from the top there are the breakable ceilings, so the player is teleported down to the bottom in that case.
      game.apply_armips_patch("ooe_fix_lighthouse_other_entrances")
    end
    
    if options[:randomize_enemy_sprites] || options[:randomize_boss_sprites]
      # Add a new function to load multi-gfx sprites that has the same function signature as the one that loads single-gfx sprites.
      game.apply_armips_patch("#{GAME}_custom_load_sprite_func")
    end
    
    if GAME == "dos" && options[:dos_new_style_map]
      # Make DoS maps look like PoR and OoE, with a hole in the doors and different colors.
      game.apply_armips_patch("dos_add_hole_to_map_doors")
      
      colors = renderer.read_single_palette(0x02079D5C, 16)
      colors[1] = ChunkyPNG::Color.rgba(0x14<<3, 8<<3, 0x10<<3, 255) # Room fill color
      colors[3] = ChunkyPNG::Color.rgba(0x1B<<3, 0x1B<<3, 0x1B<<3, 255) # Door color
      renderer.save_palette_by_specific_palette_pointer(0x02079D5C, colors)
    end
    
    if GAME == "dos" && options[:randomize_bosses]
      game.apply_armips_patch("dos_balore_face_player")
    end
    
    # Then tell the free space manager that the entire file is available for free use, except for the parts we've already used with the above patches.
    new_overlay_path = "/ftc/overlay9_#{NEW_OVERLAY_ID}"
    new_overlay_file = game.fs.files_by_path[new_overlay_path]
    new_overlay_size = new_overlay_file[:size]
    game.fs.mark_space_unused(new_overlay_path, new_overlay_size, NEW_OVERLAY_FREE_SPACE_MAX_SIZE-new_overlay_size)
  end
  
  def apply_tweaks
    # Adds the seed to the start a new game menu text.
    game_start_text_id = case GAME
    when "dos"
      0x421
    when "por"
      0x5BC
    when "ooe"
      0x4C5
    end
    text = game.text_database.text_list[game_start_text_id]
    text.decoded_string = "Starts a new game. Seed:\\n#{@seed}"
    game.text_database.write_to_rom()
    
    if GAME == "dos"
      # Modify that one pit in the Demon Guest House so the player can't get stuck in it without double jump.
      
      layer = game.areas[0].sectors[1].rooms[0x26].layers.first
      layer.tiles[0x17].index_on_tileset = 0x33
      layer.tiles[0x18].index_on_tileset = 0x33
      layer.tiles[0x18].horizontal_flip = true
      layer.tiles[0x27].index_on_tileset = 0x43
      layer.tiles[0x28].index_on_tileset = 0x43
      layer.tiles[0x28].horizontal_flip = true
      layer.write_to_rom()
    end
    
    if GAME == "dos"
      # Move the boss door to the left of Zephyr's room to the correct spot so it's not offscreen.
      boss_door = game.areas[0].sectors[8].rooms[0xD].entities[1]
      boss_door.x_pos = 0xF0
      boss_door.write_to_rom()
    end
    
    if (options[:randomize_boss_souls] || options[:randomize_bosses]) && GAME == "dos"
      # If the player beats Balore but doesn't own Balore's soul they will appear stuck. (Though they could always escape with suspend.)
      # Also if Balore is put in a random room the blocks won't fit at all in that room.
      # So get rid of the line of code Balore runs when he dies that recreates the Balore blocks in the room.
      
      game.fs.load_overlay(23)
      game.fs.write(0x02300808, [0xE1A00000].pack("V"))
    end
    
    if GAME == "dos" && options[:randomize_bosses]
      # When you kill a boss, they depend on the magic seal being created properly, otherwise they softlock the game and never die.
      # Death has so many GFX pages that if there are any other things in the room with him (such as Gergoth's floors) the magic seal doesn't have enough extra memory to load in.
      # So when boss randomizer is on we need to make the magic seal still set 020F6E0B,1 on to indicate the magic seal was completed.
      # In MakeMagicSeal, nop out the 2 lines that would return early if the magic seals's GFX couldn't be loaded.
      # Even without its graphics, the magic seal still functions as normal - it's just the "completed visual" won't show up.
      # Also, Death's body and scythes get sucked into the upper left corner of the room instead of the magic seal, since the magic seal doesn't exist.
      game.fs.write(0x02215800, [0xE1A00000].pack("V"))
      game.fs.write(0x02215804, [0xE1A00000].pack("V"))
    end
    
    if options[:randomize_enemies] && GAME == "por"
      # Remove the line of code that spawns the sand to go along with Sand Worm/Poison Worm.
      # This sand can cause various bugs depending on the room, such as teleporting the player out of bounds, preventing the player from picking up items, and turning the background into an animated rainbow.
      
      game.fs.load_overlay(69)
      game.fs.write(0x022DA394, [0xE3A00000].pack("V"))
    end
    
    if GAME == "dos"
      # Always apply the patch to fix the first ability soul giving you multiple abilities.
      game.apply_armips_patch("dos_fix_first_ability_soul")
    end
    
    if GAME == "dos" && options[:no_touch_screen]
      game.apply_armips_patch("dos_skip_drawing_seals")
      game.apply_armips_patch("dos_melee_balore_blocks")
      game.apply_armips_patch("dos_skip_name_signing")
    end
    
    if GAME == "dos" && options[:fix_luck]
      game.apply_armips_patch("dos_fix_luck")
    end
    
    if GAME == "dos" && options[:remove_slot_machines]
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && entity.subtype == 0x26
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
    end
    
    if GAME == "dos" && options[:unlock_boss_doors]
      game.apply_armips_patch("dos_skip_boss_door_seals")
    end
    
    if GAME == "dos" && options[:always_start_with_rare_ring]
      # Make the game think AoS is always in the GBA slot.
      game.fs.write(0x02000D84, [0xE3A00001].pack("V"))
    end
    
    if GAME == "dos" && options[:randomize_pickups]
      game.apply_armips_patch("dos_julius_start_with_tower_key")
    end
    
    if GAME == "por" && options[:fix_infinite_quest_rewards]
      game.apply_armips_patch("por_fix_infinite_quest_rewards")
    end
    
    if GAME == "por" && options[:skip_emblem_drawing]
      game.apply_armips_patch("por_skip_emblem_drawing")
    end
    
    if GAME == "por" && options[:por_nerf_enemy_resistances]
      game.apply_armips_patch("por_nerf_enemy_resistances")
    end
    
    if GAME == "por" && options[:por_short_mode]
      portraits_needed_to_open_studio_portrait = PickupRandomizer::PORTRAIT_NAMES - [:portraitnestofevil] - @portraits_to_remove
      boss_flag_checking_code_locations = [0x02076B84, 0x02076BA4, 0x02076BC4, 0x02076BE4]
      portraits_needed_to_open_studio_portrait.each_with_index do |portrait_name, i|
        new_boss_flag = case portrait_name
        when :portraitcityofhaze
          0x2
        when :portraitsandygrave
          0x80
        when :portraitnationoffools
          0x20
        when :portraitforestofdoom
          0x40
        when :portraitdarkacademy
          0x200
        when :portraitburntparadise
          0x800
        when :portraitforgottencity
          0x400
        when :portrait13thstreet
          0x100
        else
          raise "Invalid portrait name: #{portrait_name}"
        end
        
        code_location = boss_flag_checking_code_locations[i]
        game.fs.replace_arm_shifted_immediate_integer(code_location, new_boss_flag)
      end
    end
    
    if GAME == "por" && options[:randomize_portraits]
      # The 13 Street and Burnt Paradise portraits try to use the blue flame animation of object 5F when they're still locked.
      # But object 5F's sprite is not loaded unless object 5F is in the room and before the portrait, so trying to use a sprite that's not loaded causes a crash on no$gba and probably real hardware.
      # So we change the flames to use an animation in the common sprite, which is always loaded, so we still have a visual indicator of the portraits being locked without a crash.
      game.fs.write(0x020767DC, [0xEBFEA5BA].pack("V")) # Change this call to LoadCommonSprite
      game.fs.write(0x02076804, [0x21].pack("C")) # Change the animation to 21
      
      # We also raise the z-pos of the portrait frame so that it doesn't appear behind room tiles.
      game.fs.write(0x0207B9C0, [0x5380].pack("V"))
    end
    
    if GAME == "por" && (options[:randomize_portraits] || options[:por_short_mode])
      game.areas.each do |area|
        map = game.get_map(area.area_index, 0)
        map.tiles.each do |tile|
          room = game.areas[area.area_index].sectors[tile.sector_index].rooms[tile.room_index]
          
          if room.room_str == "00-0B-00"
            # The studio portrait room. Always mark this as having a portrait.
            tile.is_entrance = true
            next
          end
          
          tile_x_off = (tile.x_pos - room.room_xpos_on_map) * SCREEN_WIDTH_IN_PIXELS
          tile_y_off = (tile.y_pos - room.room_ypos_on_map) * SCREEN_HEIGHT_IN_PIXELS
          tile.is_entrance = room.entities.find do |e|
            if e.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(e.subtype)
              # Portrait.
              # Clamp the portrait's X and Y within the bounds of the room so we can detect that it's on a tile even if it's slightly off the edge of the room.
              x = [0, e.x_pos, room.width*SCREEN_WIDTH_IN_PIXELS-1].sort[1] # Clamp the portrait's X within the room
              y = [0, e.y_pos, room.height*SCREEN_HEIGHT_IN_PIXELS-1].sort[1] # Clamp the portrait's Y within the room
              
              # Then check if the clamped X and Y are within the current tile.
              (tile_x_off..tile_x_off+SCREEN_WIDTH_IN_PIXELS-1).include?(x) && (tile_y_off..tile_y_off+SCREEN_HEIGHT_IN_PIXELS-1).include?(y)
            else
              false
            end
          end
        end
        map.write_to_rom()
      end
    end
    
    if GAME == "por" && (options[:randomize_portraits] || options[:por_short_mode])
      # Remove the cutscene where the player characters talk about the first portrait they find that leads to City of Haze.
      # It bugs out the game pretty seriously if there's no portrait in the room.
      first_portrait_cutscene = game.entity_by_str("00-01-00_01")
      first_portrait_cutscene.type = 0
      first_portrait_cutscene.write_to_rom()
    end
    
    if GAME == "por"
      # If the portrait randomizer or short mode remove all 4 portraits from the studio portrait room, going into the studio portrait crashes on real hardware.
      # This is because it needs part of the small square-framed portrait's sprite.
      # So in this case we just add a dummy portrait out of bounds so it loads its sprite.
      studio_portrait_room = game.room_by_str("00-0B-00")
      square_framed_portrait = studio_portrait_room.entities.find{|e| e.is_special_object? && [0x76, 0x87].include?(e.subtype)}
      if square_framed_portrait.nil?
        dummy_portrait = Entity.new(studio_portrait_room, game.fs)
        
        dummy_portrait.x_pos = 0
        dummy_portrait.y_pos = -0x100
        dummy_portrait.type = 2
        dummy_portrait.subtype = 0x76
        dummy_portrait.var_a = 0
        dummy_portrait.var_b = 0
        
        studio_portrait_room.entities << dummy_portrait
        studio_portrait_room.write_entities_to_rom()
      end
    end
    
    if GAME == "por" && options[:randomize_portraits]
      # Portraits that return to the castle from 13th Street/Forgotten City/Burnt Paradise/Dark Academy (object 87) place the player at a different X position than other portraits.
      # Those other positions aren't taken into account by the logic, so change these to use the same X pos (80) as the others.
      game.fs.replace_arm_shifted_immediate_integer(0x02078EA0, 0x80)
      game.fs.replace_arm_shifted_immediate_integer(0x02078E98, 0x80)
      game.fs.replace_arm_shifted_immediate_integer(0x02078EA8, 0x80)
      game.fs.replace_arm_shifted_immediate_integer(0x02078EB0, 0x80)
    end
    
    if GAME == "por"
      # The conditions for unlocking the second tier of portraits is different in Richter/Sisters/Old Axe Armor mode compared to Jonathan mode.
      # The logic only takes Jonathan mode into account, so change the second tier of portraits to always use the Jonathan mode conditions even in the other modes.
      game.fs.write(0x02078F98, [0xE3A01000].pack("V"))
    end
    
    if GAME == "por"
      # Fix a bug in the base game where you have a couple seconds after picking up the cog where you can use a magical ticket to skip fighting Legion.
      # To do this we make Legion's horizontal boss doors turn on global flag 2 (in the middle of a boss fight, prevents magical ticket use) as soon as you enter the room, in the same line that it was turning on global flag 1.
      game.fs.load_overlay(98)
      game.fs.write(0x022E88E4, [3].pack("C"))
    end
    
    if GAME == "por"
      # Fix a bug in the base game where skipping the cutscene after you kill Death too quickly will prevent Death's boss death flag from being set.
      game.fs.load_overlay(64)
      game.fs.write(0x022D8B18, [0xE1A00000].pack("V")) # nop out the line that waits 2 seconds before making Death put down his arms and set his boss death flag.
    end
    
    if GAME == "por"
      # Allow Jonathan and Charlotte to use weapons with swing anims they originally couldn't use.
      
      # Normally Jonathan cannot use books because he doesn't have any book swing anims specified.
      # Copy his punch swing anims to his book swing anims so that he can.
      jonathan = game.players[0]
      punch_swing_anims_ptr = game.fs.read(jonathan["Swing anims ptr"] + 7*4, 4).unpack("V").first
      game.fs.write(jonathan["Swing anims ptr"] + 9*4, [punch_swing_anims_ptr].pack("V*"))
      
      # Normally Charlotte cannot use any weapons besides books and punches because she doesn't have swing anims specified for most types of weapons.
      # Copy her book swing anims to all her other types so that she can.
      charlotte = game.players[1]
      book_swing_anims_ptr = game.fs.read(charlotte["Swing anims ptr"] + 9*4, 4).unpack("V").first
      game.fs.write(charlotte["Swing anims ptr"], ([book_swing_anims_ptr]*10).pack("V*"))
    end
    
    if GAME == "por"
      # Give Charlotte the ability to jumpkick and superjump so she's on par with Jonathan in terms of mobility.
      charlotte = game.players[1]
      charlotte["Actions"][5] = true # Can jumpkick
      charlotte["Actions"][6] = true # Can superjump
      # And set her state anims for both of those to be the broom animation.
      # For superjumping the broom looks appropriate.
      # For jumpkicking none of her animations look appropriate, so go with the broom anyway since it looks ridiculous.
      state_anims = game.state_anims_for_player(1)
      state_anims[0x0E] = 0x0A # Superjumping
      state_anims[0x33] = 0x0A # Jumpkicking straight down
      state_anims[0x34] = 0x0A # Jumpkicking diagonally down
      game.save_state_anims_for_player(1, state_anims)
      
      # Also give her the ability to use critical arts.
      # To do this we must enable her "Can combo tech" bit.
      charlotte["??? bitfield"][3] = true # Can combo tech
      # But enabling that bit causes an issue - by default that bit means she can do *all* combo techs, but we only want her to do critical art.
      # So we need to specify a list of combo techs that she can and can't do, so we can set them all to 00 to specify that she can't do them.
      # Get 4 bytes of free space for Charlotte's combo techs list.
      charlotte["Combo tech ptr"] = game.fs.get_free_space(4)
      # Then set all four to 0.
      game.fs.write(charlotte["Combo tech ptr"], [0, 0, 0, 0].pack("CCCC"))
      
      charlotte.write_to_rom()
    end
    
    if GAME == "por" && room_rando?
      # In room rando, unlock the bottom passage in the second room of the game by default to simplify the logic. (The one that usually needs you to complete the Nest of Evil quest.)
      game.fs.load_overlay(78)
      game.fs.write(0x022E8988, [0xE3E00000].pack("V")) # mvn r0, 0h
    end
    
    if GAME == "por" && room_rando?
      balore_room = game.room_by_str("09-00-0A")
      unless @unused_rooms.include?(balore_room)
        right_door_out = balore_room.doors.find{|d| d.direction == :right}
        if right_door_out
          left_door_in = right_door_out.destination_door
          
          # Left door that leads into Balore's room in Nest of Evil.
          # If the player enters through this door they will be behind Balore, unable to get into the room, and Balore can't hit them.
          # The player can still kill Balore but there's no challenge in that.
          # So we make the door leave the player on the left half of the room, in front of Balore on the ground.
          left_door_in.dest_x_2 = -0xC0
          left_door_in.dest_y_2 = 0x30
          left_door_in.write_to_rom()
        end
      end
      
      gergoth_room = game.room_by_str("09-00-14")
      unless @unused_rooms.include?(gergoth_room)
        right_door_out = gergoth_room.doors.find{|d| d.direction == :right}
        if right_door_out
          left_door_in = right_door_out.destination_door
          
          # Do the same thing for the door into Gergoth's room as we did for the one into Balore's room.
          left_door_in.dest_x_2 = -0xC0
          left_door_in.dest_y_2 = 0x30
          left_door_in.write_to_rom()
        end
      end
    end
    
    if GAME == "por" && (options[:randomize_starting_room] || options[:randomize_rooms_map_friendly])
      # If the starting room (or map) is randomized, we need to lower the drawbridge by default or the player can't ever reach the first few rooms of the entrance.
      # Do this by making the drawbridge think the game mode is Richter mode, since it automatically lowers itself in that case.
      game.fs.load_overlay(78)
      game.fs.write(0x022E8880, [0xE3A01001].pack("V")) # mov r1, 1h
    end
    
    if GAME == "por" && (options[:randomize_area_connections] || options[:randomize_rooms_map_friendly])
      # Some bosses (e.g. Stella) connect directly to a transition room.
      # This means the boss door gets placed in whatever transition room gets connected to the boss by the area randomizer.
      # But almost all transition room hiders have a higher Z-position than boss doors, hiding the boss door.
      # We want the boss door to be visible as a warning for the boss. So change all boss doors to have a higher Z-pos.
      # Boss doors normally have 0x4F80 Z-pos, we raise it to 0x65A0 (which has the side effect of putting it on top of the player too, who is at 0x5B00).
      game.fs.write(0x020718CC, [0x65A0].pack("V"))
    end
    
    if GAME == "por" && options[:randomize_portraits] && options[:randomize_room_connections]
      # Room rando can make it hard to know where to go to find portraits, so reveal all portrait tiles on the map by default.
      game.apply_armips_patch("por_reveal_all_portraits_on_map")
    end
    
    if GAME == "por" && room_rando?
      # In room rando, get rid of the left wall of the sisters boss fight and replace it with a boss door instead.
      # If the player entered the room from the left they would get stuck in the wall otherwise.
      entity = game.entity_by_str("00-0B-01_01")
      entity.subtype = BOSS_DOOR_SUBTYPE
      entity.y_pos = 0xB0
      entity.var_a = 1
      entity.var_b = 0xE
      entity.write_to_rom()
    end
    
    if GAME == "dos" && options[:randomize_starting_room]
      # If a soul candle gets placed in a starting save room, it will appear behind the save point's graphics.
      # We need to raise the sould candle's Z-pos from 5200 to 5600 so it appears on top of the save point.
      game.fs.write(0x021A4444, [0x56].pack("C"))
      # Note that this also affects other candles besides soul candles. Hopefully it doesn't make them look weird in any rooms.
    end
    
    if GAME == "ooe" && options[:always_dowsing]
      game.apply_armips_patch("ooe_always_dowsing")
    end
    
    if GAME == "ooe" && options[:summons_gain_extra_exp]
      # Increase the rate that summons gain EXP.
      # Normally they gain 3 EXP every time they hit an enemy, and need 0x7FFF to level up once.
      # So we significantly increase that 3 per hit so they level up faster.
      game.fs.write(0x0207D438, [64].pack("C"))
    end
    
    if GAME == "por" && !options[:randomize_skill_behavior]
      # If the SP needed to master subweapons isn't randomized, reduce it to 1/4 vanilla so it's more attainable in a run.
      (0x150..0x1A0).each do |skill_global_id|
        skill = game.items[skill_global_id]
        is_spell = skill["??? bitfield"][2]
        next if is_spell
        
        skill_extra_data = game.items[skill_global_id+0x6C]
        skill_extra_data["SP to Master"] /= 4
        skill_extra_data.write_to_rom()
      end
    end
    
    if GAME == "por" && options[:allow_mastering_charlottes_skills]
      game.apply_armips_patch("por_allow_mastering_spells")
      
      if !options[:randomize_skill_behavior]
        # If skill behavior rando is off, give all spells a default SP to master of 500.
        (0x150..0x1A0).each do |skill_global_id|
          skill = game.items[skill_global_id]
          is_spell = skill["??? bitfield"][2]
          next unless is_spell
          next if NONOFFENSIVE_SKILL_NAMES.include?(skill.name)
          
          skill_extra_data = game.items[skill_global_id+0x6C]
          case skill.name
          when "Sanctuary", "Speed Up", "Eye for an Eye", "Summon Medusa", "Salamander", "Cocytus", "Thor's Bellow"
            skill_extra_data["SP to Master"] = 150
          when "Dark Rift", "Summon Ghost", "Summon Skeleton", "Summon Frog"
            skill_extra_data["SP to Master"] = 300
          else
            skill_extra_data["SP to Master"] = 500
          end
          skill_extra_data.write_to_rom()
        end
      end
    end
    
    if GAME == "ooe" && !options[:randomize_skill_stats]
      # If skill damage isn't randomized, buff familiar summons to 5x vanilla damage so they're not completely useless.
      (0x47..0x4D).each do |skill_global_id|
        skill = game.items[skill_global_id]
        skill["DMG multiplier"] *= 5
        skill.write_to_rom()
      end
    end
    
    if GAME == "ooe"
      # Remove the bottom left boss door in Brachyura's boss room.
      # This is so the player can escape from the room even if they accidentally went in there before they could fight Brachyura.
      boss_door = game.entity_by_str("09-00-05_03")
      boss_door.type = 0
      boss_door.write_to_rom()
    end
    
    if options[:name_unnamed_skills]
      game.fix_unnamed_skills()
    end
    
    if options[:unlock_all_modes]
      game.apply_armips_patch("#{GAME}_unlock_everything")
    end
    
    if options[:reveal_breakable_walls]
      game.apply_armips_patch("#{GAME}_reveal_breakable_walls")
    end
    
    if options[:reveal_bestiary]
      game.apply_armips_patch("#{GAME}_reveal_bestiary")
    end
    
    if GAME == "por" && options[:always_show_drop_percentages]
      game.apply_armips_patch("por_always_show_drop_percentages")
    end
    
    if GAME == "dos"
      # When you walk over an item you already have 9 of, the game plays a sound effect every 0.5 seconds.
      # We change it to play once a second so it's less annoying.
      game.fs.write(0x021E8B30, [0x3C].pack("C"))
    end
    
    if GAME == "por"
      # PoR Malphas has leftover code from DoS to set the "during a boss fight" global game flag.
      # We need to remove the line that sets this flag, otherwise portraits and magical tickets won't work in any room he is in.
      game.fs.load_overlay(46)
      game.fs.write(0x022D7A10, [0xE1A00000].pack("V")) # nop
    end
    
    if GAME == "dos" && options[:randomize_weapon_synths]
      # Fix the stat difference display in the weapon synth screen.
      # It assumes that all items are weapons and displays a weapon's stats by default.
      # This change tells it to make no assumptions and calculate what the item type actually is.
      game.fs.write(0x02032A2C, [0xE3E00000].pack("V")) # mvn r0, 0h
      game.fs.write(0x02032A3C, [0xE3E00000].pack("V")) # mvn r0, 0h
    end
    
    if GAME == "dos" && options[:randomize_starting_room]
      # Fix the HUD disappearing with the starting room rando.
      game.fs.write(0x021D9910, [0xE3C11081].pack("V")) # This line normally disables global game flag 0x1, we change it to disable both 0x1 and 0x80 (which hides the HUD).
      game.fs.write(0x021C782C, [0xE1A00000].pack("V")) # This line explicitly resets 0x80 later on, so nop it out.
      game.fs.write(0x021C7518, [0xE1A00000].pack("V")) # Same as above, but this is for if the player watched the cutscene instead of skipping it.
    end
    
    if GAME == "dos" && options[:randomize_rooms_map_friendly]
      # The game doesn't let you explore the center of the Abyss map because that's where Menace's room normally is.
      # We need to allow exploring the center since other rooms can get placed there by the map rando.
      game.fs.write(0x02023264, [0xE1A00000].pack("V"))
      
      # Also, the position of the Abyss warp room on the Abyss map is hardcoded. So we must update that as well.
      room = game.room_by_str("00-0B-23")
      game.fs.write(0x02024C9C, [room.room_xpos_on_map].pack("C"))
      game.fs.write(0x02024CA4, [room.room_ypos_on_map].pack("C"))
    end
    
    if GAME == "ooe" && room_rando?
      # If any player character other than Shanoa enters Eligor's fight, Eligor's code forces the player to walk to the right until they're on Eligor's back.
      # This is fine when entering from the left, but when entering from the right it softlocks the player walking into a wall forever.
      # So we remove this special code to automatically walk the player and make it behave the same way as it does for Shanoa.
      game.fs.load_overlay(31)
      game.fs.write(0x022BA47C, [0xEA000002].pack("V")) # Make branch unconditional, so it works for any player character, not just Shanoa.
    end
    
    if options[:remove_area_names]
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && entity.subtype == AREA_NAME_SUBTYPE
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
    end
    
    if GAME == "dos" && options[:menace_to_somacula]
      dos_set_soma_mode_final_boss(:somacula)
    end
    
    if room_rando?
      center_bosses_for_room_rando()
    end
    
    update_hardcoded_enemy_attributes()
    
    if needs_infinite_magical_tickets?
      room_rando_give_infinite_magical_tickets()
    end
  end
  
  def dos_implement_magical_tickets
    # Codes magical tickets in DoS, replacing Castle Map 0.
    
    game.apply_armips_patch("dos_magical_ticket")
    
    item = game.items[0x2B] # Castle Map 0
    
    name = game.text_database.text_list[TEXT_REGIONS["Item Names"].begin + item["Item ID"]]
    desc = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
    name.decoded_string = "Magical Ticket"
    desc.decoded_string = "An old pass that returns\\nyou to the Lost Village."
    game.text_database.write_to_rom()
    
    gfx_file = game.fs.files_by_path["/sc/f_item2.dat"]
    palette_pointer = 0x022C4684
    palette_index = 2
    gfx = GfxWrapper.new(gfx_file[:asset_pointer], game.fs)
    palette = renderer.generate_palettes(palette_pointer, 16)[palette_index]
    image = renderer.render_gfx_1_dimensional_mode(gfx, palette)
    magical_ticket_sprites = ChunkyPNG::Image.from_file("./dsvrandom/assets/dos_magical_ticket.png")
    image.compose!(magical_ticket_sprites, 32, 0)
    renderer.save_gfx_page_1_dimensional_mode(image, gfx, palette_pointer, 16, palette_index)
    
    item["Icon"] = 0x0282
    
    item["Type"] = 5 # Invalid type which will hit the "else" clause of the switch statement and go to our magical ticket code.
    item.write_to_rom()
  end
  
  def room_rando_give_infinite_magical_tickets
    # Give the player a magical ticket to start the game with, and make magical tickets not be consumed when used.
    game.apply_armips_patch("#{GAME}_infinite_magical_tickets")
    
    # Then change the magical ticket code to bring you to the starting room instead of the shop/village.
    area_index = @starting_room.area_index
    sector_index = @starting_room.sector_index
    room_index = @starting_room.room_index
    case GAME
    when "dos"
      game.fs.write(0x02308920+0x24, [sector_index].pack("C"))
      game.fs.write(0x02308920+0x28, [room_index].pack("C"))
    when "por"
      game.fs.write(0x0203A280, [0xE3A00000].pack("V")) # Change mov to constant mov instead of register mov
      game.fs.write(0x0203A280, [area_index].pack("C"))
      game.fs.write(0x0203A290, [sector_index].pack("C"))
      game.fs.write(0x0203A294, [room_index].pack("C"))
    when "ooe"
      game.fs.write(0x02037B08, [0xE3A01001].pack("V")) # Change mov to constant mov instead of register mov
      game.fs.write(0x02037B00, [area_index].pack("C"))
      game.fs.write(0x02037B08, [sector_index].pack("C"))
      game.fs.write(0x02037B0C, [room_index].pack("C"))
      
      if area_index != 1
        # Starting room is not in Wygol, so make the magical ticket change to the normal map screen, instead of the Wygol map screen.
        game.fs.write(0x02037B38, [0x05].pack("C"))
        game.fs.write(0x02037B4C, [0x05].pack("C"))
      end
    end
    
    # Also change the magical ticket's destination x/y position.
    # The x/y are going to be arm shifted immediates, so they need to be rounded down to the nearest 0x10 to make sure they don't use too many bits.
    if options[:randomize_starting_room]
      x_pos = @starting_x_pos
      y_pos = @starting_y_pos
    else
      # If starting room rando is off, don't use the actual starting x/y, we want to place the player near a door on the ground instead of in mid air.
      case GAME
      when "dos"
        x_pos = 0x200 - 0x10
        y_pos = 0x80
      when "por"
        x_pos = 0x300 - 0x10
        y_pos = 0x80
      when "ooe"
        x_pos = 0x30
        y_pos = 0x230
      end
    end

    if x_pos > 0x100
      x_pos = x_pos/0x10*0x10
    end
    if y_pos > 0x100
      y_pos = y_pos/0x10*0x10
    end
    game.fs.replace_arm_shifted_immediate_integer(MAGICAL_TICKET_X_POS_OFFSET, x_pos)
    game.fs.replace_arm_shifted_immediate_integer(MAGICAL_TICKET_Y_POS_OFFSET, y_pos)
    
    case GAME
    when "dos"
      item = game.items[0x2B]
    when "por"
      item = game.items[0x45]
    when "ooe"
      item = game.items[0x7C]
    end
    
    # Change the description to reflect that it returns you to your starting room instead of the shop/village.
    desc = game.text_database.text_list[TEXT_REGIONS["Item Descriptions"].begin + item["Item ID"]]
    case GAME
    when "dos"
      desc.decoded_string = "An old pass that returns\\nyou to your starting room."
    when "por"
      desc.decoded_string = "An enchanted ticket that returns\\nyou to your starting room."
    when "ooe"
      desc.decoded_string = "A one-way pass to return\\nto your starting room immediately."
    end
    game.text_database.write_to_rom()
    
    # Also set the magical ticket's price to 0 so it can't be sold.
    item["Price"] = 0
    
    item.write_to_rom()
  end
end
