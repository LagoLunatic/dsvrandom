
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
  
  attr_reader :options,
              :seed,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker,
              :renderer
  
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
    :subweapon_sp_to_master_range   => 100..3000,
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
  }
  DIFFICULTY_LEVELS = {
    "Easy" => {
      :item_price_range               => 2500,
      :weapon_attack_range            => 30,
      :weapon_iframes_range           => 30,
      :armor_defense_range            => 10,
      :item_extra_stats_range         => 7,
      :restorative_amount_range       => 200,
      :heart_restorative_amount_range => 75,
      :ap_increase_amount_range       => 2000,
      
      :skill_price_range              => 5000,
      :skill_dmg_range                => 11,
      :crush_or_union_dmg_range       => 38,
      :subweapon_sp_to_master_range   => 100,
      :spell_charge_time_range        => 32,
      :skill_mana_cost_range          => 25,
      :crush_mana_cost_range          => 150,
      :union_heart_cost_range         => 20,
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
    },
    "Normal" => {
      :item_price_range               => 5000,
      :weapon_attack_range            => 14,
      :weapon_iframes_range           => 39,
      :armor_defense_range            => 4,
      :item_extra_stats_range         => -5,
      :restorative_amount_range       => 150,
      :heart_restorative_amount_range => 50,
      :ap_increase_amount_range       => 1600,
      
      :skill_price_range              => 10000,
      :skill_dmg_range                => 8.5,
      :crush_or_union_dmg_range       => 33,
      :subweapon_sp_to_master_range   => 500,
      :spell_charge_time_range        => 37,
      :skill_mana_cost_range          => 30,
      :crush_mana_cost_range          => 175,
      :union_heart_cost_range         => 30,
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
      
      :max_room_difficulty_mult       => 2.75,
      :max_enemy_difficulty_mult      => 1.8,
      :enemy_id_preservation_exponent => 3.5,
      
      :enemy_stat_mult_range          => 1.75,
      :enemy_num_weaknesses_range     => 0.75,
      :enemy_num_resistances_range    => 3.25,
      :boss_stat_mult_range           => 1.12,
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
    
    if room_rando? || (GAME == "por" && options[:randomize_portraits])
      @needs_infinite_magical_tickets = true
    else
      @needs_infinite_magical_tickets = false
    end
    
    @int_seed = Digest::MD5.hexdigest(seed).to_i(16)
    @rng = Random.new(@int_seed)
    
    @weak_enemy_attack_threshold = 28
    @max_spawners_per_room = 1
    
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
    
    load_randomizer_constants()
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
  # Standard deviation is 1/4th the size of the range.
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
    
    if num < range.begin || num > range.end
      # Retry until we get a value within the range.
      return rand_range_weighted(range, average: average)
    else
      return num
    end
  end
  
  def named_rand_range_weighted(name)
    #p name
    #p @difficulty_settings[name]
    range, average = @difficulty_settings[name]
    rand_range_weighted(range, average: average)
  end
  
  ## Gets a random number within a range, but weighted low.
  ## The higher the low_weight argument the more strongly low weighted it is. Examples:
  ## 0 -> 50%
  ## 1 -> 33%
  ## 2 -> 21%
  ## 3 -> 11.5%
  ## 4 -> 6.5%
  ## 5 -> 3.5%
  #def rand_range_weighted_low(range, low_weight: 1)
  #  random_float = 1 - rand()
  #  low_weight.times do
  #    random_float = Math.sqrt(random_float)
  #  end
  #  random_float = 1 - random_float
  #  return (random_float * (range.max + 1 - range.min) + range.min).floor
  #end
  #
  #def rand_range_weighted_very_low(range)
  #  return rand_range_weighted_low(range, low_weight: 2)
  #end
  
  def room_rando?
    options[:randomize_rooms_map_friendly] || options[:randomize_room_connections] || options[:randomize_area_connections] || options[:randomize_starting_room]
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
    
    if room_rando?
      options[:unlock_boss_doors] = true
      options[:add_magical_tickets] = true
    end
    
    apply_pre_randomization_tweaks()
    
    @max_up_items = []
    if options[:randomize_consumable_behavior]
      reset_rng()
      case GAME
      when "por"
        possible_max_up_ids = (0..0x5F).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x00, 0x04] # Don't let starting items (potion and high tonic) be max ups.
        possible_max_up_ids -= [0x3F] # Don't let ground meat by a max up since you can farm it infinitely.
        possible_max_up_ids -= [0x45, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F] # Don't let magical tickets and records be max ups since other types of items can't be made magical tickets or max ups.
        2.times do
          max_up_id = possible_max_up_ids.sample(random: rng)
          possible_max_up_ids.delete(max_up_id)
          @max_up_items << max_up_id
        end
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
    
    @red_wall_souls = []
    if GAME == "dos"
      if options[:randomize_red_walls]
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
    end
    if room_rando?
      checker.set_starting_room(@starting_room, @starting_room_door_index)
    end
    
    if room_rando?
      # Remove breakable walls and similar things that prevent you from going in certain doors.
      remove_door_blockers()
    end
    
    if options[:randomize_rooms_map_friendly]
      yield [options_completed, "Generating map..."]
      reset_rng()
      randomize_doors_no_overlap() do |percent|
        yield [options_completed+percent*30, "Generating map..."]
      end
      regenerate_all_maps()
      options_completed += 30
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
    
    options_completed += 2
    
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
    
    if options[:randomize_enemy_drops]
      yield [options_completed, "Randomizing enemy drops..."]
      reset_rng()
      randomize_enemy_drops()
      options_completed += 1
    end
    
    if options[:randomize_pickups]
      yield [options_completed, "Randomizing other pickups..."]
      reset_rng()
      place_non_progression_pickups()
      options_completed += 1
    end
    
    @original_enemy_dnas = []
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = EnemyDNA.new(enemy_id, game)
      @original_enemy_dnas << enemy_dna
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
      options_completed += 1
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
    spoiler_log.puts "ERROR! Randomization failed with error:\n  #{e.message}\n  #{e.backtrace.join("\n  ")}"
    raise e
  ensure
    spoiler_log.puts
    spoiler_log.puts
    spoiler_log.close()
  end
  
  def apply_pre_randomization_tweaks
    tiled = TMXInterface.new
    
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
      
      # Remove the darkness seal in Condemned Tower along with the related events.
      # TODO: Should actually keep this in and just keep track of it in the logic somehow.
      [
        "00-05-0C_00",
        "00-05-0C_01",
        "00-05-0C_03",
      ].each do |entity_str|
        entity = game.entity_by_str(entity_str)
        entity.type = 0
        entity.write_to_rom()
      end
    end
    
    if options[:add_magical_tickets] && GAME == "dos"
      dos_implement_magical_tickets()
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
      
      # The right entrance to the Lighthouse has a wall that blocks it at first.
      # If the player enters the Lighthouse from the right they'll get softlocked there.
      # So we remove the line of code where the elevator creates that wall.
      game.fs.load_overlay(53)
      game.fs.write(0x022C331C, [0xE3A00000].pack("V"))
      
      # Modify the level design of three Tymeo rooms where they have a platform at the bottom door, but only on either the left or right edge of the screen.
      # If the upwards door connected to one of these downwards doors doesn't have a platform on the same side of the screen, the player won't be able to get up.
      # So we place a large platform across the center of the bottom of these three rooms so the player can walk across it.
      [0x8, 0xD, 0x12].each do |room_index|
        room = game.areas[0xA].sectors[0].rooms[room_index]
        filename = "./dsvrandom/roomedits/ooe_room_rando_0A-00-%02X.tmx" % room_index
        tiled.read(filename, room)
      end
    end
    
    # Add a free space overlay so we can add entities as much as we want.
    if !game.fs.has_free_space_overlay?
      game.add_new_overlay()
    end
    # Then tell the free space manager that the entire file is available for free use, except for the parts we've already used (e.g. for the DoS magic ticket patch).
    new_overlay_path = "/ftc/overlay9_#{NEW_OVERLAY_ID}"
    new_overlay_file = game.fs.files_by_path[new_overlay_path]
    new_overlay_size = new_overlay_file[:size]
    game.fs.mark_space_unused(new_overlay_path, new_overlay_size, NEW_OVERLAY_FREE_SPACE_SIZE-new_overlay_size)
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
    
    if GAME == "por" && options[:fix_infinite_quest_rewards]
      game.apply_armips_patch("por_fix_infinite_quest_rewards")
    end
    
    if GAME == "por" && options[:skip_emblem_drawing]
      game.apply_armips_patch("por_skip_emblem_drawing")
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
    
    if GAME == "por" && options[:randomize_portraits]
      game.areas.each do |area|
        map = game.get_map(area.area_index, 0)
        map.tiles.each do |tile|
          room = game.areas[area.area_index].sectors[tile.sector_index].rooms[tile.room_index]
          tile_x_off = (tile.x_pos - room.room_xpos_on_map) * SCREEN_WIDTH_IN_PIXELS
          tile_y_off = (tile.y_pos - room.room_ypos_on_map) * SCREEN_HEIGHT_IN_PIXELS
          tile.is_entrance = room.entities.find do |e|
            e.is_special_object? && [0x1A, 0x76, 0x86, 0x87].include?(e.subtype) &&
              (tile_x_off..tile_x_off+SCREEN_WIDTH_IN_PIXELS-1).include?(e.x_pos) &&
              (tile_y_off..tile_y_off+SCREEN_HEIGHT_IN_PIXELS-1).include?(e.y_pos)
          end
        end
        map.write_to_rom()
      end
    end
    
    if GAME == "por"
      # Fix a bug in the base game where you have a couple seconds after picking up the cog where you can use a magical ticket to skip fighting Legion.
      # To do this we make Legion's horizontal boss doors turn on global flag 2 (in the middle of a boss fight, prevents magical ticket use) as soon as you enter the room, in the same line that it was turning on global flag 1.
      game.fs.load_overlay(98)
      game.fs.write(0x022E88E4, [3].pack("C"))
    end
    
    if GAME == "ooe" && options[:always_dowsing]
      game.apply_armips_patch("ooe_always_dowsing")
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
    
    if GAME == "dos"
      # When you walk over an item you already have 9 of, the game plays a sound effect every 0.5 seconds.
      # We change it to play once a second so it's less annoying.
      game.fs.write(0x021E8B30, [0x3C].pack("C"))
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
    
    if @needs_infinite_magical_tickets
      room_rando_give_infinite_magical_tickets()
    end
  end
  
  def dos_implement_magical_tickets
    # Codes magical tickets in DoS, replacing Castle Map 0.
    
    if !game.fs.has_free_space_overlay?
      game.add_new_overlay()
    end
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
      game.fs.write(0x023E0114, [sector_index].pack("C"))
      game.fs.write(0x023E0118, [room_index].pack("C"))
      # 0x023E011C is x pos
      # 0x023E0120 is x pos
    when "por"
      game.fs.write(0x0203A280, [0xE3A00000].pack("V")) # Change mov to constant mov instead of register mov
      game.fs.write(0x0203A280, [area_index].pack("C"))
      game.fs.write(0x0203A290, [sector_index].pack("C"))
      game.fs.write(0x0203A294, [room_index].pack("C"))
      # 0x0203A298 is x pos
      # 0x0203A284 is y pos
    when "ooe"
      game.fs.write(0x02037B08, [0xE3A01001].pack("V")) # Change mov to constant mov instead of register mov
      game.fs.write(0x02037B00, [area_index].pack("C"))
      game.fs.write(0x02037B08, [sector_index].pack("C"))
      game.fs.write(0x02037B0C, [room_index].pack("C"))
      x_pos = 0x80
      y_pos = 0x60
      game.fs.replace_arm_shifted_immediate_integer(0x02037B10, x_pos)
      game.fs.replace_arm_shifted_immediate_integer(0x02037B04, y_pos)
      
      if area_index != 1
        # Starting room is not in Wygol, so make the magical ticket change to the normal map screen, instead of the Wygol map screen.
        game.fs.write(0x02037B38, [0x05].pack("C"))
        game.fs.write(0x02037B4C, [0x05].pack("C"))
      end
    end
    
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
