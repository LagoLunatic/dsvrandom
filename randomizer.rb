
require 'digest/md5'

require_relative 'tweaks'
require_relative 'constants/difficulty_options'

require_relative 'completability_checker'
require_relative 'door_completability_checker'
require_relative 'randomizers/pickup_randomizer'
require_relative 'randomizers/enemy_randomizer'
require_relative 'randomizers/drop_randomizer'
require_relative 'randomizers/player_randomizer'
require_relative 'randomizers/boss_randomizer'
require_relative 'randomizers/door_randomizer'
require_relative 'randomizers/shop_randomizer'
require_relative 'randomizers/chest_pool_randomizer'
require_relative 'randomizers/item_skill_stat_randomizer'
require_relative 'randomizers/enemy_stat_randomizer'
require_relative 'randomizers/weapon_synth_randomizer'
require_relative 'randomizers/starting_room_randomizer'
require_relative 'randomizers/enemy_ai_randomizer'
require_relative 'randomizers/starting_items_randomizer'
require_relative 'randomizers/skill_sprites_randomizer'
require_relative 'randomizers/enemy_anim_speed_randomizer'
require_relative 'randomizers/red_wall_randomizer'
require_relative 'randomizers/map_randomizer'

require_relative 'randomizers/cosmetic/bgm_randomizer'
require_relative 'randomizers/cosmetic/dialogue_randomizer'
require_relative 'randomizers/cosmetic/enemy_sprite_randomizer'

class Randomizer
  include Tweaks
  
  include PickupRandomizer
  include EnemyRandomizer
  include DropRandomizer
  include PlayerRandomizer
  include BossRandomizer
  include DoorRandomizer
  include ShopRandomizer
  include ChestPoolRandomizer
  include ItemSkillStatRandomizer
  include EnemyStatRandomizer
  include WeaponSynthRandomizer
  include StartingRoomRandomizer
  include EnemyAIRandomizer
  include StartingItemsRandomizer
  include SkillSpriteRandomizer
  include EnemyAnimSpeedRandomizer
  include RedWallRandomizer
  include MapRandomizer
  
  include BgmRandomizer
  include DialogueRandomizer
  include EnemySpriteRandomizer
  
  attr_reader :options,
              :seed,
              :rng,
              :spoiler_log,
              :non_spoiler_log,
              :game,
              :checker,
              :renderer,
              :tiled,
              :all_non_progression_pickups
  
  def initialize(seed, game, options, difficulty_level, difficulty_settings_averages)
    @seed = seed
    @game = game
    @options = options
    @renderer = Renderer.new(game.fs)
    
    if seed.nil? || seed.empty?
      raise "No seed given"
    end
    
    if options[:open_world_map]
      options[:randomize_world_map_exits] = false
    end
    if room_rando?
      options[:unlock_boss_doors] = true
      options[:add_magical_tickets] = true
    end
    if options[:randomize_rooms_map_friendly]
      # The map rando won't necessarily place the rooms containing the normal bosses/portraits/villagers.
      # So forcibly enable these options so these things can be placed wherever.
      options[:randomize_boss_souls] = true
      options[:randomize_portraits] = true
      options[:randomize_villagers] = true
    end
    
    if room_rando?
      @checker = DoorCompletabilityChecker.new(
        game,
        options[:enable_glitch_reqs],
        options[:open_world_map],
        options[:randomize_villagers],
        options[:randomize_portraits],
        options[:randomize_world_map_exits],
      )
    else
      @checker = CompletabilityChecker.new(
        game,
        options[:enable_glitch_reqs],
        options[:open_world_map],
        options[:randomize_villagers],
        options[:randomize_portraits],
      )
    end
    
    @int_seed = Digest::MD5.hexdigest(seed).to_i(16)
    @rng = Random.new(@int_seed)
    
    @weak_enemy_attack_threshold = 28
    @max_spawners_per_room = 1
    @max_room_rando_subsector_redos = 20
    @max_map_rando_sector_redos = 40
    @max_map_rando_area_redos = 5
    
    @difficulty_settings = {}
    DIFFICULTY_RANGES.each do |name, range|
      average = difficulty_settings_averages[name]
      
      unless range.include?(average)
        raise "#{average} is not within range #{range}"
      end
      
      if name.to_s.end_with?("range")
        @difficulty_settings[name] = [range, average]
      else
        @difficulty_settings[name] = average
      end
    end
    @difficulty_level = difficulty_level
    @user_given_difficulty_settings = difficulty_settings_averages
    
    @glyphs_placed_as_event_glyphs = []
    
    load_randomizer_constants()
    
    @transition_rooms = game.get_transition_rooms()
    @transition_rooms.reject! do |room|
      FAKE_TRANSITION_ROOMS.include?(room.room_metadata_ram_pointer)
    end
  end
  
  def load_randomizer_constants
    # Load game-specific randomizer constants.
    orig_verbosity = $VERBOSE
    $VERBOSE = nil
    case GAME
    when "dos"
      load './dsvrandom/constants/dos_randomizer_constants.rb'
    when "por"
      load './dsvrandom/constants/por_randomizer_constants.rb'
    when "ooe"
      load './dsvrandom/constants/ooe_randomizer_constants.rb'
    else
      raise "Unsupported game."
    end
    $VERBOSE = orig_verbosity
  end
  
  def reset_rng
    @rng = Random.new(@int_seed)
  end
  
  # Gets a random number with a range, but weighted towards a certain average.
  # It uses a normal distribution and rejects values outside the correct range.
  # Standard deviation is 1/5th the size of the range.
  def rand_range_weighted(range, average: (range.begin+range.end)/2)
    if average < range.begin || average > range.end
      raise "Bad random range! Average #{average} not within range #{range}."
    end
    
    if range.begin.is_a?(Float) || range.end.is_a?(Float)
      float_mode = true
    end
    
    theta = 2 * Math::PI * rng.rand()
    rho = Math.sqrt(-2 * Math.log(1 - rng.rand()))
    stddev = (range.end-range.begin).to_f/5
    scale = stddev * rho
    x = average + scale * Math.cos(theta)
    #y = average + scale * Math.sin(theta) # Don't care about the second value
    
    num = x
    num = x.round unless float_mode
    
    if num < range.begin
      # Retry until we get a value within the range.
      # Since this failed attempt at a number was too low, limit the next one to the lower half of the available range.
      new_range_end = (range.end-range.begin)/2 + range.begin
      new_range = (range.begin..new_range_end)
      if !new_range.include?(average)
        new_range = (range.begin..average)
        new_range = (new_range.begin.floor..new_range.end.ceil) unless float_mode
      end
      return rand_range_weighted(new_range, average: average)
    elsif num > range.end
      # Retry until we get a value within the range.
      # Since this failed attempt at a number was too high, limit the next one to the upper half of the available range.
      new_range_begin = (range.end-range.begin)/2 + range.begin
      new_range = (new_range_begin..range.end)
      if !new_range.include?(average)
        new_range = (average..range.end)
        new_range = (new_range.begin.floor..new_range.end.ceil) unless float_mode
      end
      return rand_range_weighted(new_range, average: average)
    else
      return num
    end
  end
  
  def named_rand_range_weighted(name)
    range, average = @difficulty_settings[name]
    rand_range_weighted(range, average: average)
  end
  
  def room_rando?
    options[:randomize_rooms_map_friendly] || options[:randomize_room_connections] || options[:randomize_area_connections] || options[:randomize_starting_room] || options[:randomize_world_map_exits]
  end
  
  def needs_infinite_magical_tickets?
    room_rando? || (GAME == "por" && options[:randomize_portraits])
  end
  
  def randomize
    options_completed = 0
    
    options_string = options.select{|k,v| v == true}.keys.join(", ")
    if DIFFICULTY_LEVELS.keys.include?(@difficulty_level)
      difficulty_settings_string = @difficulty_level
    else
      difficulty_settings_string = "Custom, settings:\n  " + @user_given_difficulty_settings.map{|k,v| "#{k}: #{v}"}.join("\n  ")
    end
    
    @spoiler_log = StringIO.new
    @non_spoiler_log = StringIO.new
    @logs = [spoiler_log, non_spoiler_log]
    
    @logs.each do |log|
      log.puts "Seed: #{@seed}, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
      log.puts "Selected options: #{options_string}"
      log.puts "Difficulty level: #{difficulty_settings_string}"
    end
    
    apply_pre_randomization_tweaks()
    
    @unused_rooms = [] # This will be a list of rooms unused by the map rando/PoR short mode.
    
    if GAME == "por"
      if options[:por_short_mode]
        reset_rng()
        
        @portraits_to_remove = []
        possible_portraits = (PORTRAIT_NAMES - [:portraitnestofevil])
        4.times do
          portrait_to_remove = possible_portraits.sample(random: rng)
          @portraits_to_remove << portrait_to_remove
          possible_portraits.delete(portrait_to_remove)
        end
        
        # Keep track of unused rooms (every room in the 4 unused portraits).
        @portraits_to_remove.each do |portrait_name|
          area_index = PORTRAIT_NAME_TO_DATA[portrait_name][:var_a]
          game.areas[area_index].sectors.each do |sector|
            @unused_rooms += sector.rooms
          end
        end
        
        checker.remove_13th_street_and_burnt_paradise_boss_death_prerequisites()
        
        if !options[:randomize_portraits]
          # If portrait randomizer is off, remove the portraits immediately.
          game.each_room do |room|
            room.entities.each do |entity|
              if entity.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(entity.subtype)
                @portraits_to_remove.each do |portrait_name|
                  portrait_data = PORTRAIT_NAME_TO_DATA[portrait_name]
                  if entity.subtype == portrait_data[:subtype] && entity.var_a == portrait_data[:var_a] && entity.var_b == portrait_data[:var_b]
                    entity.type = 0
                    entity.write_to_rom()
                    break
                  end
                end
              end
            end
          end
          @portrait_locations_to_remove = @portraits_to_remove.map do |portrait_name|
            PORTRAIT_NAME_TO_DEFAULT_ENTITY_LOCATION[portrait_name]
          end
        end
      else
        @portraits_to_remove = []
        @portrait_locations_to_remove = []
      end
      
      # Tell the completability checker which portraits to remove so the pickup randomizer doesn't place those portraits if the portrait randomizer is on.
      checker.set_removed_portraits(@portraits_to_remove)
    end
    
    # Now it's safe to initialize the list of progress items.
    checker.initialize_all_progression_pickups()
    
    @max_up_items = []
    if options[:randomize_consumable_behavior]
      reset_rng()
      
      case GAME
      when "por"
        possible_max_up_ids = (0..0x5F).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x00, 0x04] # Don't let starting items (potion and high tonic) be max ups.
        possible_max_up_ids -= [0x3F] # Don't let ground meat be a max up since you can farm it infinitely.
        possible_max_up_ids -= [0x4B] # Don't let castle map 1 be a max up since it will get put in the shop.
        possible_max_up_ids -= [0x4C, 0x4D] # Don't let castle maps 2 and 3 be max ups either since then they won't reveal the map
        possible_max_up_ids -= [0x45, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F] # Don't let magical tickets and records be max ups since other types of items can't be made magical tickets or max ups.
        2.times do
          max_up_id = possible_max_up_ids.sample(random: rng)
          possible_max_up_ids.delete(max_up_id)
          @max_up_items << max_up_id
        end
        
        # In the alternate game modes like Richter mode, max ups should still appear but not other items.
        # We need to tell the game what the new max up item IDs are for it to do this.
        game.fs.replace_arm_shifted_immediate_integer(0x021DD8C0, @max_up_items[0]) # HP Max Up
        game.fs.replace_arm_shifted_immediate_integer(0x021DD8C8, @max_up_items[1]) # MP Max Up
      when "ooe"
        possible_max_up_ids = (0x75..0xE4).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x75, 0x79] # Don't let starting items (potion and high tonic) be max ups.
        possible_max_up_ids -= [0xD2] # VIP card given to you by Jacob and put directly into your inventory.
        3.times do
          max_up_id = possible_max_up_ids.sample(random: rng)
          possible_max_up_ids.delete(max_up_id)
          @max_up_items << max_up_id
        end
      end
    else
      case GAME
      when "por"
        @max_up_items = [0x08, 0x09]
      when "ooe"
        @max_up_items = [0x7F, 0x80, 0x81]
      end
    end
    
    if GAME == "ooe" && options[:randomize_pickups]
      # Glyph given by Barlowe.
      # We randomize this, but only to a starter physical weapon glyph, not to any glyph.
      reset_rng()
      possible_starter_weapons = [0x01, 0x04, 0x07, 0x0A, 0x0D, 0x10, 0x13, 0x16]
      pickup_global_id = possible_starter_weapons.sample(random: rng)
      game.fs.load_overlay(42)
      game.fs.write(0x022C3980, [0xE3A01000].pack("V"))
      game.fs.write(0x022C3980, [pickup_global_id+1].pack("C"))
      checker.add_item(pickup_global_id)
      @ooe_starter_glyph_id = pickup_global_id # Tell other randomization options what this glyph is so they can handle it properly
    end
    
    options_completed += 2 # Initialization
    
    @red_wall_souls = []
    if GAME == "dos"
      if options[:randomize_red_walls]
        reset_rng()
        randomize_red_walls()
      else
        @red_wall_souls = [
          0xD2, # skeleton
          0xD4, # axe armor
          0xE3, # killer clown
          0xEC, # ukoback
        ]
      end
      
      # Tell the completability checker logic what souls are for what red walls on this seed.
      checker.set_red_wall_souls(@red_wall_souls)
    end
    
    # Now it's safe to initialize the list of non-progress items.
    initialize_all_non_progression_pickups()
    
    # Choose a healing item to be guaranteed cheap and decent in the shop.
    if options[:randomize_consumable_behavior]
      reset_rng()
      
      all_non_progression_consumables = []
      all_non_progression_pickups.each do |item_global_id|
        item = game.items[item_global_id]
        if item.item_type_name == "Consumables"
          all_non_progression_consumables << item_global_id
        end
      end
      
      @shop_cheap_healing_item_id = all_non_progression_consumables.sample(random: rng)
    else
      # If the consumable rando is off use the base Potion as the cheap healing item.
      @shop_cheap_healing_item_id = case GAME
      when "dos"
        0x0
      when "por"
        0x0
      when "ooe"
        0x75
      end
    end
    
    if options[:randomize_bosses]
      yield [options_completed, "Shuffling bosses..."]
      reset_rng()
      randomize_bosses()
      options_completed += 1
    end
    
    if room_rando?
      # Remove breakable walls and similar things that prevent you from going in certain doors.
      remove_door_blockers()
    end
    
    if options[:randomize_rooms_map_friendly]
      yield [options_completed, "Generating map..."]
      reset_rng()
      randomize_doors_no_overlap() do |percent|
        yield [options_completed+percent*75, "Generating map..."]
      end
      
      add_more_save_and_warp_rooms()
      regenerate_all_maps()
      options_completed += 75
    else
      if options[:randomize_area_connections]
        yield [options_completed, "Connecting areas..."]
        reset_rng()
        randomize_transition_doors()
        options_completed += 1
      end
      
      if options[:randomize_room_connections]
        yield [options_completed, "Connecting rooms..."]
        reset_rng()
        randomize_non_transition_doors()
        options_completed += 1
      end
    end
    
    # Preserve the original enemy DNAs so we know how hard rooms were in the base game.
    @original_enemy_dnas = []
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = EnemyDNA.new(enemy_id, game)
      @original_enemy_dnas << enemy_dna
    end
    
    # Calculate the average difficulty of common enemies in each subsector.
    if options[:randomize_starting_room]
      @enemy_difficulty_by_subsector = {}
      game.areas.each do |area|
        area.sectors.each do |sector|
          subsectors = get_subsectors(sector)
          subsectors.each do |rooms_in_subsector|
            sum_of_all_subsector_enemy_attacks = 0
            num_enemies_in_subsector = 0
            
            rooms_in_subsector.uniq!{|subroom| subroom.room_str} # Don't count entities in rooms with subrooms multiple times in a single subsector.
            
            rooms_in_subsector.each do |room|
              room.entities.select{|e| e.is_common_enemy?}.each do |enemy|
                num_enemies_in_subsector += 1
                
                enemy_dna = @original_enemy_dnas[enemy.subtype]
                sum_of_all_subsector_enemy_attacks += enemy_dna["Attack"]
              end
            end
            
            if num_enemies_in_subsector == 0
              average_enemy_attack = 0
            else
              average_enemy_attack = sum_of_all_subsector_enemy_attacks.to_f / num_enemies_in_subsector
            end
            
            @enemy_difficulty_by_subsector[rooms_in_subsector] = average_enemy_attack
          end
        end
      end
    end
    
    if options[:randomize_starting_room]
      yield [options_completed, "Selecting starting room..."]
      reset_rng()
      randomize_starting_room()
      options_completed += 1
    else
      @starting_room = case GAME
      when "dos"
        game.areas[0].sectors[0].rooms[1]
      when "por"
        game.areas[0].sectors[0].rooms[0]
      when "ooe"
        game.areas[2].sectors[0].rooms[4]
      end
      @starting_room_door_index = 0
      
      case GAME
      when "dos"
        @starting_x_pos = 0x200 - 0x10
        @starting_y_pos = 0x80
      when "por"
        # The cutscene teleports the player off to the right.
        # Need to put the items over there so the player picks them up right at the start, as opposed to during the actual cutscene which will crash the game.
        @starting_x_pos = 0x1F0
        @starting_y_pos = 0x60
      when "ooe"
        @starting_x_pos = 0xC0
        @starting_y_pos = 0x230
      end
    end
    if room_rando?
      checker.set_starting_room(@starting_room, @starting_room_door_index)
    end
    
    @used_pickup_flags = []
    
    # Specifies which pickup flags weren't used in the original game in case we need new ones for something.
    case GAME
    when "dos"
      # For DoS we sometimes need pickup flags for when a soul candle gets randomized into something that's not a soul candle.
      @unused_pickup_flags = (1..0x7F).to_a
      use_pickup_flag(0xA) # Strongman puzzle first reward
      use_pickup_flag(0xE) # Strongman puzzle second reward
      use_pickup_flag(0x11) # Strongman puzzle third reward
    when "por"
      # We don't need spare pickup flags for the pickup randomizer in PoR, but we do need it for the starting item randomizer.
      @unused_pickup_flags = (1..0x17F).to_a
      use_pickup_flag(2) # Call Cube isn't randomized
      use_pickup_flag(0x10) # Cog's pickup flag, Legion specifically checks this flag, not whether you own the cog.
    when "ooe"
      # For OoE we sometimes need pickup flags for when a glyph statue gets randomized into something that's not a glyph statue.
      @unused_pickup_flags = (0x71..0x15F).to_a
      # Pickup flags 160-16D and 170-17D exist but are used by no-damage blue chests so we don't use those. 16E, 16F, 17E, and 17F could probably be used by the randomizer safely but currently are not.
      use_pickup_flag(0xB5) # Pickup flag for the Strength Ring chest.
      use_pickup_flag(0xB2) # This appears to be used by something hardcoded, though I can't find what it is.
    end
    
    if GAME == "por" && !options[:randomize_portraits] && room_rando?
      # Room rando needs to have a list of return portraits.
      # If portrait rando is on, that list gets incrementally created as portraits are placed.
      # But when portrait rando is off, we need to create the whole thing here first.
      
      # Main return portraits.
      checker.add_return_portrait("01-00-1A", "00-01-00_00")
      checker.add_return_portrait("03-00-00", "00-04-12_00")
      checker.add_return_portrait("05-00-21", "00-06-01_00")
      checker.add_return_portrait("07-00-00", "00-08-01_02")
      checker.add_return_portrait("02-00-07", "00-0B-00_02")
      checker.add_return_portrait("04-00-00", "00-0B-00_01")
      checker.add_return_portrait("06-00-20", "00-0B-00_03")
      checker.add_return_portrait("08-01-06", "00-0B-00_04")
      checker.add_return_portrait("09-00-00", "00-00-05_00")
      
      # Bonus return portraits at the end of some areas.
      checker.add_return_portrait("02-02-16", "00-0B-00_02")
      checker.add_return_portrait("04-01-07", "00-0B-00_01")
      checker.add_return_portrait("06-00-06", "00-0B-00_03")
      checker.add_return_portrait("08-00-08", "00-0B-00_04")
    end
    
    
    if GAME == "dos"
      # Remove the enemy and the entity hider hiding that enemy during the intro cutscene from the first room of the vanilla game.
      # These two just cause more problems than they're worth - the hider can hide starting items, the enemy can hit you as soon as you enter the room, etc.
      entity_hider = game.entity_by_str("00-00-01_0B")
      entity_hider.type = 0
      entity_hider.write_to_rom()
      enemy = game.entity_by_str("00-00-01_0C")
      enemy.type = 0
      enemy.write_to_rom()
    end
    
    if GAME == "dos"
      # Always start the player with Doppelganger.
      add_bonus_item_to_starting_room(0x144) # Doppelganger
      checker.add_item(0x144)
    end
    
    if GAME == "por" && options[:dont_randomize_change_cube] && !room_rando?
      # Always start the player with Skill Cube.
      # (If change cube is randomized, Skill Cube takes Change Cube's place, so we don't need to put Skill Cube in the starting room in that case.)
      add_bonus_item_to_starting_room(0x1AE) # Skill Cube
      checker.add_item(0x1AE)
    end
    
    if room_rando?
      # We need to put certain items the logic assumes the player starts with in the player's starting room if they can't reach them.
      case GAME
      when "dos"
        # If the player can't access the drawbridge room give them Magic Seal 1.
        accessible_doors = checker.get_accessible_doors()
        if !accessible_doors.include?("00-00-15_000")
          #add_bonus_item_to_starting_room(0x3D) # Magic Seal 1
          # (Commented out because room rando unlocks all boss doors.)
        end
      when "por"
        # Always start with Lizard Tail, Call Cube, Skill Cube, and possibly Change Cube.
        # Even if the player technically could reach the vanilla location, they could be very far away on some seeds.
        add_bonus_item_to_starting_room(0x1B2) # Lizard Tail
        checker.add_item(0x1B2) # Lizard Tail
        
        add_bonus_item_to_starting_room(0x1AD) # Call Cube
        checker.add_item(0x1AD) # Call Cube
        
        add_bonus_item_to_starting_room(0x1AE) # Skill Cube
        checker.add_item(0x1AE) # Skill Cube
        
        if options[:dont_randomize_change_cube]
          add_bonus_item_to_starting_room(0x1AC) # Change Cube
          checker.add_item(0x1AC) # Change Cube
        end
      when "ooe"
        if options[:randomize_starting_room]
          # Put the glyph Barlowe would normally give you at the start in the randomized starting room.
          if @ooe_starter_glyph_id
            add_bonus_item_to_starting_room(@ooe_starter_glyph_id)
          else
            add_bonus_item_to_starting_room(1) # Confodere
          end
        end
      end
    end
    
    if options[:randomize_pickups]
      yield [options_completed, "Placing progression pickups..."]
      reset_rng()
      randomize_pickups_completably() do |percent|
        yield [options_completed+percent*20, "Placing progression pickups..."]
      end
      options_completed += 20
    end
    
    @unplaced_non_progression_pickups = all_non_progression_pickups.dup
    @unplaced_non_progression_pickups -= checker.current_items
    @used_non_progression_pickups = []
    @used_non_progression_pickups += checker.current_items
    
    if options[:scavenger_mode]
      remove_all_enemy_drops()
    else
      if options[:randomize_enemy_drops]
        yield [options_completed, "Randomizing enemy drops..."]
        reset_rng()
        randomize_enemy_drops()
        options_completed += 1
      end
    end
    
    if options[:randomize_pickups]
      yield [options_completed, "Randomizing other pickups..."]
      reset_rng()
      place_non_progression_pickups()
    end
    
    if room_rando? && options[:rebalance_enemies_in_room_rando]
      # Reorder boss stats so they're more appropriate for the order you progress in room rando.
      
      boss_ids_by_order_you_reach_them = []
      @rooms_by_progression_order_accessed.each do |progression_region|
        # A progression region is all the rooms you can access at a certain point on the main route in between getting progression items.
        
        boss_ids_by_order_you_reach_them_for_this_region = []
        progression_region.each do |room_str|
          room = game.room_by_str(room_str)
          bosses_in_room = room.entities.select do |e|
            e.is_enemy? && ORIGINAL_BOSS_IDS_ORDER.include?(e.subtype)
          end
          if GAME == "ooe"
            # Don't count common enemy Giant Skeleton as a boss.
            bosses_in_room.reject!{|e| e.subtype == 0x6B && e.var_a != 1}
          end
          
          bosses_in_room.each do |boss_entity|
            boss_id = boss_entity.subtype
            boss_ids_by_order_you_reach_them_for_this_region << boss_id
            
            if GAME == "por" && boss_id == 0x91 && boss_entity.var_a == 1
              # Stella with Var A = 1 is the double fight with Loretta, so rebalance Loretta for this point in the game too.
              boss_ids_by_order_you_reach_them_for_this_region << 0x92
            end
          end
        end
        
        # If multiple bosses are unlocked at the same time, use the vanilla order.
        boss_ids_by_order_you_reach_them_for_this_region.sort_by! do |boss_id|
          ORIGINAL_BOSS_IDS_ORDER.index(boss_id)
        end
        
        boss_ids_by_order_you_reach_them += boss_ids_by_order_you_reach_them_for_this_region
      end
      boss_ids_by_order_you_reach_them.uniq!
      
      boss_ids_by_order_you_reach_them.each_with_index do |boss_id, i|
        orig_boss_id = ORIGINAL_BOSS_IDS_ORDER[i]
        orig_boss = @original_enemy_dnas[orig_boss_id]
        boss = game.enemy_dnas[boss_id]
        
        #puts "#{orig_boss.name} -> #{boss.name}"
        
        boss["HP"]               = orig_boss["HP"]
        boss["MP"]               = orig_boss["MP"]
        boss["SP"]               = orig_boss["SP"]
        boss["AP"]               = orig_boss["AP"]
        boss["EXP"]              = orig_boss["EXP"]
        boss["Attack"]           = orig_boss["Attack"]
        boss["Defense"]          = orig_boss["Defense"]
        boss["Physical Defense"] = orig_boss["Physical Defense"]
        boss["Magical Defense"]  = orig_boss["Magical Defense"]
        boss.write_to_rom()
      end
    end
    
    if room_rando? && options[:rebalance_enemies_in_room_rando]
      # Generate new difficulty values for every room in the game based on the order you progress in room rando.
      # These values are then used in place of the normal ones by the enemy randomizer.
      # (If the enemy randomizer is off, common enemies don't get rebalanced.)
      
      original_room_difficulties = []
      
      all_rooms_in_order_accessed = @rooms_by_progression_order_accessed.flatten.uniq
      all_rooms_in_order_accessed.each do |room_str|
        room = game.room_by_str(room_str)
        
        # Skip Nest of Evil/Large Cavern, they will be given unlimited enemy difficulty.
        next if ["Nest of Evil", "Large Cavern"].include?(room.area.name)
        
        enemies_in_room = get_common_enemies_in_room(room)
        next if enemies_in_room.empty?
        
        average_attack = enemies_in_room.reduce(0) do |difficulty, enemy|
          enemy_dna = @original_enemy_dnas[enemy.subtype]
          difficulty + enemy_dna["Attack"]
        end
        average_attack = average_attack.to_f / enemies_in_room.size
        
        max_enemy_attack = enemies_in_room.map do |enemy|
          enemy_dna = @original_enemy_dnas[enemy.subtype]
          enemy_dna["Attack"]
        end.max
        
        average_enemy_id = enemies_in_room.reduce(0) do |id_sum, enemy|
          id_sum + enemy.subtype
        end
        average_enemy_id = average_enemy_id.to_f / enemies_in_room.size
        
        original_room_difficulties << {
          average_attack: average_attack,
          max_enemy_attack: max_enemy_attack,
          average_enemy_id: average_enemy_id,
        }
      end
      
      original_room_difficulties_in_order = original_room_difficulties.sort_by{|hash| hash[:average_attack]}
      
      @room_rando_enemy_difficulty_for_room = {}
      room_strs_by_order_you_reach_them = @rooms_by_progression_order_accessed.flatten.uniq
      i = 0
      room_strs_by_order_you_reach_them.each do |room_str|
        room = game.room_by_str(room_str)
        enemies_in_room = get_common_enemies_in_room(room)
        next if enemies_in_room.empty?
        
        @room_rando_enemy_difficulty_for_room[room_str] = original_room_difficulties_in_order[i]
        
        i += 1
      end
      
      game.each_room do |room|
        if ["Nest of Evil", "Large Cavern"].include?(room.area.name)
          # Give Nest of Evil and Large Cavern unlimited enemy difficulty.
          @room_rando_enemy_difficulty_for_room[room.room_str] = {
            average_attack: 9999,
            max_enemy_attack: 9999,
            average_enemy_id: 100,
          }
        end
      end
    end
    
    if options[:randomize_enemy_stats]
      yield [options_completed, "Randomizing enemy stats..."]
      reset_rng()
      randomize_enemy_stats()
      options_completed += 1
    end
    
    if options[:randomize_enemy_tolerances]
      yield [options_completed, "Randomizing enemy tolerances..."]
      reset_rng()
      randomize_enemy_tolerances()
      options_completed += 1
    end
    
    if options[:randomize_enemy_sprites] || options[:randomize_boss_sprites]
      yield [options_completed, "Randomizing enemy sprites..."]
      reset_rng()
      randomize_enemy_sprites()
      options_completed += 1
    end
    
    if options[:randomize_enemies]
      yield [options_completed, "Placing enemies..."]
      reset_rng()
      randomize_enemies() do |percent|
        yield [options_completed+percent*7, "Placing enemies..."]
      end
      options_completed += 7
    end
    
    if options[:bonus_starting_items]
      yield [options_completed, "Placing starting items..."]
      reset_rng()
      randomize_starting_items()
    end
    
    if options[:randomize_enemy_ai]
      yield [options_completed, "Shuffling enemy AI..."]
      reset_rng()
      randomize_enemy_ai()
      options_completed += 1
    end
    
    if options[:randomize_player_sprites]
      yield [options_completed, "Randomizing player sprites..."]
      reset_rng()
      randomize_player_sprites()
      options_completed += 1
    end
    
    if options[:randomize_players]
      yield [options_completed, "Randomizing players..."]
      reset_rng()
      randomize_players()
      options_completed += 1
    end
    
    if options[:randomize_equipment_stats]
      yield [options_completed, "Randomizing equipment stats..."]
      reset_rng()
      randomize_equipment_stats()
      options_completed += 1
    end
    
    if options[:randomize_weapon_behavior] || options[:randomize_weapon_and_skill_elements]
      yield [options_completed, "Randomizing weapons..."]
      reset_rng()
      randomize_weapons()
      options_completed += 1
    end
    
    if options[:randomize_consumable_behavior]
      yield [options_completed, "Randomizing consumables..."]
      reset_rng()
      randomize_consumable_behavior()
      options_completed += 1
    end
    
    if options[:randomize_skill_stats] || options[:randomize_skill_behavior] || options[:randomize_weapon_and_skill_elements]
      yield [options_completed, "Randomizing skill stats..."]
      reset_rng()
      randomize_skills()
      options_completed += 1
    end
    
    # The various item/skill randomization options probably updated the descriptions, so save the whole database now instead of multiple times for each option.
    game.text_database.write_to_rom()
    
    if options[:randomize_skill_sprites]
      yield [options_completed, "Shuffling skill sprites..."]
      reset_rng()
      randomize_skill_sprites()
      options_completed += 1
    end
    
    if options[:randomize_weapon_synths]
      yield [options_completed, "Randomizing weapon synths..."]
      reset_rng()
      randomize_weapon_synths()
      options_completed += 1
    else
      reset_rng()
      randomize_vanilla_weapon_synths_that_use_progression_souls()
    end
    
    if options[:randomize_shop]
      yield [options_completed, "Randomizing shop..."]
      reset_rng()
      randomize_shop()
      options_completed += 1
    end
    
    if options[:randomize_wooden_chests]
      yield [options_completed, "Randomizing wooden chests..."]
      reset_rng()
      randomize_wooden_chests()
      options_completed += 1
    end
    
    if options[:randomize_enemy_anim_speed]
      yield [options_completed, "Randomizing enemy speed..."]
      reset_rng()
      randomize_enemy_anim_speeds()
      options_completed += 1
    end
    
    if options[:randomize_bgm]
      yield [options_completed, "Randomizing BGM..."]
      reset_rng()
      randomize_bgm()
      options_completed += 1
    end
    
    if options[:randomize_dialogue]
      yield [options_completed, "Randomizing dialogue..."]
      reset_rng()
      randomize_dialogue()
      options_completed += 1
    end
    
    yield [options_completed, "Applying tweaks..."]
    apply_tweaks()
  rescue StandardError => e
    if spoiler_log
      @logs.each do |log|
        log.puts "ERROR! Randomization failed with error:\n  #{e.message}\n  #{e.backtrace.join("\n  ")}"
      end
    end
    raise e
  end
  
  def inspect; to_s; end
end
