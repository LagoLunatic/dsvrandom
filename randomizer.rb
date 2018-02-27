
require 'digest/md5'

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

class Randomizer
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
  
  attr_reader :options,
              :seed,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker,
              :renderer,
              :tiled
  
  DIFFICULTY_RANGES = {
    :item_price_range               => 100..25000,
    :weapon_attack_range            => 0..150,
    :weapon_iframes_range           => 4..55,
    :armor_defense_range            => 0..55,
    :item_extra_stats_range         => -25..50,
    :restorative_amount_range       => 1..1000,
    :heart_restorative_amount_range => 1..350,
    :ap_increase_amount_range       => 1..65535,
    
    :skill_price_range              => 1000..30000,
    :skill_dmg_range                => 5..55,
    :crush_or_union_dmg_range       => 15..85,
    :skill_iframes_range            => 4..55,
    :subweapon_sp_to_master_range   => 100..2000,
    :spell_charge_time_range        => 8..120,
    :skill_mana_cost_range          => 1..60,
    :crush_mana_cost_range          => 50..250,
    :union_heart_cost_range         => 5..50,
    :skill_max_at_once_range        => 1..8,
    :glyph_attack_delay_range       => 1..20,
    
    :item_drop_chance_range         => 1..25,
    :skill_drop_chance_range        => 1..15,
    
    :item_placement_weight          => 0.1..100,
    :soul_candle_placement_weight   => 0.1..100,
    :por_skill_placement_weight     => 0.1..100,
    :glyph_placement_weight         => 0.1..100,
    :max_up_placement_weight        => 0.1..100,
    :money_placement_weight         => 0.1..100,
    
    :max_room_difficulty_mult       => 1.0..5.0,
    :max_enemy_difficulty_mult      => 1.0..5.0,
    :enemy_id_preservation_exponent => 0.0..5.0,
    
    :enemy_stat_mult_range          => 0.5..2.5,
    :enemy_num_weaknesses_range     => 0..8,
    :enemy_num_resistances_range    => 0..8,
    :boss_stat_mult_range           => 0.75..1.25,
    :enemy_anim_speed_mult_range    => 0.33..3.0,
    
    :starting_room_max_difficulty   => 15..75,
  }
  DIFFICULTY_LEVELS = {
    "Easy" => {
      :item_price_range               => 500,
      :weapon_attack_range            => 30,
      :weapon_iframes_range           => 26,
      :armor_defense_range            => 10,
      :item_extra_stats_range         => 7,
      :restorative_amount_range       => 200,
      :heart_restorative_amount_range => 75,
      :ap_increase_amount_range       => 2000,
      
      :skill_price_range              => 5000,
      :skill_dmg_range                => 11,
      :crush_or_union_dmg_range       => 38,
      :skill_iframes_range            => 26,
      :subweapon_sp_to_master_range   => 100,
      :spell_charge_time_range        => 32,
      :skill_mana_cost_range          => 25,
      :crush_mana_cost_range          => 150,
      :union_heart_cost_range         => 10,
      :skill_max_at_once_range        => 2,
      :glyph_attack_delay_range       => 7,
    
      :item_drop_chance_range         => 13,
      :skill_drop_chance_range        => 8,
      
      :item_placement_weight          => 55,
      :soul_candle_placement_weight   => 8,
      :por_skill_placement_weight     => 25,
      :glyph_placement_weight         => 25,
      :max_up_placement_weight        => 18,
      :money_placement_weight         => 2,
      
      :max_room_difficulty_mult       => 2.0,
      :max_enemy_difficulty_mult      => 1.3,
      :enemy_id_preservation_exponent => 3.0,
    
      :enemy_stat_mult_range          => 1.0,
      :enemy_num_weaknesses_range     => 2,
      :enemy_num_resistances_range    => 2,
      :boss_stat_mult_range           => 1.0,
      :enemy_anim_speed_mult_range    => 0.9,
      
      :starting_room_max_difficulty   => 22,
    },
    "Normal" => {
      :item_price_range               => 1500,
      :weapon_attack_range            => 20,
      :weapon_iframes_range           => 33,
      :armor_defense_range            => 6,
      :item_extra_stats_range         => 0,
      :restorative_amount_range       => 150,
      :heart_restorative_amount_range => 50,
      :ap_increase_amount_range       => 1600,
      
      :skill_price_range              => 10000,
      :skill_dmg_range                => 9,
      :crush_or_union_dmg_range       => 33,
      :skill_iframes_range            => 33,
      :subweapon_sp_to_master_range   => 300,
      :spell_charge_time_range        => 37,
      :skill_mana_cost_range          => 30,
      :crush_mana_cost_range          => 175,
      :union_heart_cost_range         => 15,
      :skill_max_at_once_range        => 1.5,
      :glyph_attack_delay_range       => 8.5,
      
      :item_drop_chance_range         => 11,
      :skill_drop_chance_range        => 6,
      
      :item_placement_weight          => 55,
      :soul_candle_placement_weight   => 8,
      :por_skill_placement_weight     => 25,
      :glyph_placement_weight         => 25,
      :max_up_placement_weight        => 18,
      :money_placement_weight         => 2,
      
      :max_room_difficulty_mult       => 2.5,
      :max_enemy_difficulty_mult      => 1.7,
      :enemy_id_preservation_exponent => 3.5,
      
      :enemy_stat_mult_range          => 1.4,
      :enemy_num_weaknesses_range     => 1,
      :enemy_num_resistances_range    => 2.5,
      :boss_stat_mult_range           => 1.12,
      :enemy_anim_speed_mult_range    => 1.3,
      
      :starting_room_max_difficulty   => 35,
    },
  }
  
  def initialize(seed, game, options, difficulty_level, difficulty_settings_averages)
    @seed = seed
    @game = game
    @options = options
    @renderer = Renderer.new(game.fs)
    
    if seed.nil? || seed.empty?
      raise "No seed given"
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
        options[:randomize_portraits]
      )
    else
      @checker = CompletabilityChecker.new(
        game,
        options[:enable_glitch_reqs],
        options[:open_world_map],
        options[:randomize_villagers],
        options[:randomize_portraits]
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
        new_range = (new_range.begin.to_i..new_range.end.to_i) unless float_mode
      end
      return rand_range_weighted(new_range, average: average)
    elsif num > range.end
      # Retry until we get a value within the range.
      # Since this failed attempt at a number was too high, limit the next one to the upper half of the available range.
      new_range_begin = (range.end-range.begin)/2 + range.begin
      new_range = (new_range_begin..range.end)
      if !new_range.include?(average)
        new_range = (average..range.end)
        new_range = (new_range.begin.to_i..new_range.end.to_i) unless float_mode
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
    options[:randomize_rooms_map_friendly] || options[:randomize_room_connections] || options[:randomize_area_connections] || options[:randomize_starting_room]
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
    
    FileUtils.mkdir_p("./logs")
    @seed_log = File.open("./logs/seed_log_no_spoilers.txt", "a")
    seed_log.puts "Seed: #{seed}, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
    seed_log.puts "  Selected options: #{options_string}"
    seed_log.puts "  Difficulty level: #{difficulty_settings_string}"
    seed_log.close()
    
    @spoiler_log = File.open("./logs/spoiler_log.txt", "a")
    spoiler_log.puts "Seed: #{@seed}, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
    spoiler_log.puts "Selected options: #{options_string}"
    spoiler_log.puts "Difficulty level: #{difficulty_settings_string}"
    
    apply_pre_randomization_tweaks()
    
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
    
    @max_up_items = []
    if options[:randomize_consumable_behavior]
      reset_rng()
      
      case GAME
      when "por"
        possible_max_up_ids = (0..0x5F).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x00, 0x04] # Don't let starting items (potion and high tonic) be max ups.
        possible_max_up_ids -= [0x3F] # Don't let ground meat be a max up since you can farm it infinitely.
        possible_max_up_ids -= [0x4B] # Don't let castle map 1 be a max up since it will get put in the shop.
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
      regenerate_all_maps()
      options_completed += 75
    else
      @rooms_unused_by_map_rando = [] # Initialize this so some other options that use it don't get an error.
      
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
      @starting_x_pos = 0x80
      @starting_y_pos = 0x60
      if GAME == "por"
        # The cutscene teleports the player off to the right.
        # Need to put the items over there so the player picks them up right at the start, as opposed to during the actual cutscene which will crash the game.
        @starting_x_pos = 0x1F0
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
    when "por"
      # We don't need spare pickup flags for the pickup randomizer in PoR, but we do need it for the starting item randomizer.
      @unused_pickup_flags = (1..0x17F).to_a
      use_pickup_flag(2) # Call Cube isn't randomized
      use_pickup_flag(0x10) # Cog's pickup flag, Legion specifically checks this flag, not whether you own the cog.
    when "ooe"
      # For OoE we sometimes need pickup flags for when a glyph statue gets randomized into something that's not a glyph statue.
      @unused_pickup_flags = (0x71..0x15F).to_a
      # Pickup flags 160-16D and 170-17D exist but are used by no-damage blue chests so we don't use those. 16E, 16F, 17E, and 17F could probably be used by the randomizer safely but currently are not.
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
        # If the player can't access Wind or Vincent give them Lizard Tail.
        accessible_doors = checker.get_accessible_doors()
        if !accessible_doors.include?("00-01-06_000") || !accessible_doors.include?("00-01-09_000")
          add_bonus_item_to_starting_room(0x1B2) # Lizard Tail
        end
        
        # If the player can't access the drawbridge room, give them the Call Cube and either the Change Cube or Skill cube.
        if !accessible_doors.include?("00-00-01_000")
          add_bonus_item_to_starting_room(0x1AD) # Call Cube
          if options[:dont_randomize_change_cube]
            add_bonus_item_to_starting_room(0x1AC) # Change Cube
          else
            add_bonus_item_to_starting_room(0x1AE) # Skill Cube
          end
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
    
    if options[:randomize_enemy_stats]
      yield [options_completed, "Randomizing enemy stats..."]
      reset_rng()
      randomize_enemy_stats()
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
    
    if options[:randomize_weapon_behavior]
      yield [options_completed, "Randomizing weapons..."]
      reset_rng()
      randomize_weapon_behavior()
      options_completed += 1
    end
    
    if options[:randomize_consumable_behavior]
      yield [options_completed, "Randomizing consumables..."]
      reset_rng()
      randomize_consumable_behavior()
      options_completed += 1
    end
    
    if options[:randomize_skill_stats]
      yield [options_completed, "Randomizing skill stats..."]
      reset_rng()
      randomize_skill_stats()
      options_completed += 1
    end
    
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
    
    yield [options_completed, "Applying tweaks..."]
    apply_tweaks()
  rescue StandardError => e
    if spoiler_log
      spoiler_log.puts "ERROR! Randomization failed with error:\n  #{e.message}\n  #{e.backtrace.join("\n  ")}"
    end
    raise e
  ensure
    if spoiler_log
      spoiler_log.puts
      spoiler_log.puts
      spoiler_log.close()
    end
  end
  
  def apply_pre_randomization_tweaks
    @tiled = TMXInterface.new
    
    if GAME == "ooe" && options[:open_world_map]
      game.apply_armips_patch("ooe_nonlinear")
      
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
      
      # Modify the level design of the drawbridge room so you can go up and down even when the drawbridge is closed.
      filename = "./dsvrandom/roomedits/dos_room_rando_00-00-15.tmx"
      room = game.areas[0].sectors[0].rooms[0x15]
      tiled.read(filename, room)
      
      # Change regular Gergoth's code to act like boss rush Gergoth and not break the floor.
      # (We can't just use boss rush Gergoth himself because he wakes up whenever you're in the room, even if you're in a lower part of the tower.)
      game.fs.load_overlay(36)
      game.fs.write(0x02303AB4, [0xE3A01000].pack("V")) # mov r1, 0h
      game.fs.write(0x02306D70, [0xE3A00000].pack("V")) # mov r0, 0h
      # And modify the code of the floors to not care if Gergoth's boss death flag is set, and just always be in place.
      game.fs.write(0x0219EF40, [0xE3A00000].pack("V")) # mov r0, 0h
      
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
            else
              # Otherwise, there's no easy way to fix this problem like in PoR/OoE, since in DoS entity hiders always hide all remaining entities.
              # So just do nothing and hope this isn't an issue. It probably won't be since it's only a few event rooms and boss rooms that use these anyway.
              # TODO?
            end
          end
        end
      end
    end
    
    if GAME == "ooe" && options[:gain_extra_attribute_points]
      # Make every enemy give 100x more AP than normal.
      game.enemy_dnas.each do |enemy|
        enemy["AP"] = 1 if enemy["AP"] < 1
        enemy["AP"] *= 100
        enemy["AP"] = 0xFF if enemy["AP"] > 0xFF
        enemy.write_to_rom()
      end
      
      # Make absorbing a glyph give 100 AP instead of 1.
      game.fs.write(0x0206D994, [100].pack("C"))
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
    
    if options[:randomize_boss_souls] && GAME == "dos"
      # If the player beats Balore but doesn't own Balore's soul they will appear stuck. (Though they could always escape with suspend.)
      # So get rid of the line of code Balore runs when he dies that recreates the Balore blocks in the room.
      
      game.fs.load_overlay(23)
      game.fs.write(0x02300808, [0xE1A00000].pack("V"))
    end
    
    if options[:randomize_enemies] && GAME == "por"
      # Remove the line of code that spawns the sand to go along with Sand Worm/Poison Worm.
      # This sand can cause various bugs depending on the room, such as teleporting the player out of bounds, preventing the player from picking up items, and turning the background into an animated rainbow.
      
      game.fs.load_overlay(69)
      game.fs.write(0x022DA394, [0xE3A00000].pack("V"))
    end
    
    if GAME == "dos" && options[:fix_first_ability_soul]
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
    
    if GAME == "por" && options[:por_short_mode]
      portraits_needed_to_open_studio_portrait = PORTRAIT_NAMES - [:portraitnestofevil] - @portraits_to_remove
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
    
    if GAME == "por" && room_rando?
      # In room rando, unlock the bottom passage in the second room of the game by default to simplify the logic. (The one that usually needs you to complete the Nest of Evil quest.)
      game.fs.load_overlay(78)
      game.fs.write(0x022E8988, [0xE3E00000].pack("V")) # mvn r0, 0h
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
  
  def inspect; to_s; end
end
