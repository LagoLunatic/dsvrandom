
require 'digest/md5'

require_relative 'completability_checker'
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
  
  attr_reader :options,
              :seed,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker
  
  DIFFICULTY_RANGES = {
    :max_room_difficulty_mult       => 1.0..5.0,
    :max_enemy_difficulty_mult      => 1.0..5.0,
    :enemy_id_preservation_exponent => 0.0..5.0,
    
    :item_drop_chance_range         => 1..25,
    :skill_drop_chance_range        => 1..15,
    
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
    
    :enemy_stat_mult_range          => 0.5..2.5,
    :enemy_num_weaknesses_range     => 0..8,
    :enemy_num_resistances_range    => 0..8,
    :boss_stat_mult_range           => 0.75..1.25,
  }
  DIFFICULTY_LEVELS = {
    "Easy" => {
      :max_room_difficulty_mult       => 2.0,
      :max_enemy_difficulty_mult      => 1.3,
      :enemy_id_preservation_exponent => 3.0,
      
      :item_drop_chance_range         => 13,
      :skill_drop_chance_range        => 8,
      
      :item_price_range               => 5000,
      :weapon_attack_range            => 30,
      :weapon_iframes_range           => 30,
      :armor_defense_range            => 10,
      :item_extra_stats_range         => 7,
      :restorative_amount_range       => 200,
      :heart_restorative_amount_range => 75,
      :ap_increase_amount_range       => 2000,
      
      :skill_price_range              => 10000,
      :skill_dmg_range                => 11,
      :crush_or_union_dmg_range       => 38,
      :subweapon_sp_to_master_range   => 1500,
      :spell_charge_time_range        => 32,
      :skill_mana_cost_range          => 25,
      :crush_mana_cost_range          => 150,
      :union_heart_cost_range         => 20,
      :skill_max_at_once_range        => 2,
      :glyph_attack_delay_range       => 7,
    
      :enemy_stat_mult_range          => 1.0,
      :enemy_num_weaknesses_range     => 2,
      :enemy_num_resistances_range    => 2,
      :boss_stat_mult_range           => 1.0,
    },
    "Normal" => {
      :max_room_difficulty_mult       => 2.75,
      :max_enemy_difficulty_mult      => 1.8,
      :enemy_id_preservation_exponent => 3.5,
      
      :item_drop_chance_range         => 11,
      :skill_drop_chance_range        => 6,
      
      :item_price_range               => 8000,
      :weapon_attack_range            => 14,
      :weapon_iframes_range           => 39,
      :armor_defense_range            => 4,
      :item_extra_stats_range         => -5,
      :restorative_amount_range       => 150,
      :heart_restorative_amount_range => 50,
      :ap_increase_amount_range       => 1600,
      
      :skill_price_range              => 12000,
      :skill_dmg_range                => 8.5,
      :crush_or_union_dmg_range       => 33,
      :subweapon_sp_to_master_range   => 1700,
      :spell_charge_time_range        => 45,
      :skill_mana_cost_range          => 30,
      :crush_mana_cost_range          => 175,
      :union_heart_cost_range         => 30,
      :skill_max_at_once_range        => 1.5,
      :glyph_attack_delay_range       => 8.5,
      
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
    
    if seed.nil? || seed.empty?
      raise "No seed given"
    end
    
    @checker = CompletabilityChecker.new(game, options[:enable_glitch_reqs], options[:open_world_map], options[:randomize_villagers])
    
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
    
    if options[:randomize_starting_room]
      yield [options_completed, "Selecting starting room..."]
      reset_rng()
      randomize_starting_room()
      options_completed += 1
    else
      @starting_room = case GAME
      when "dos"
        game.areas[0].sectors[0].rooms[4]
      when "por"
        game.areas[0].sectors[0].rooms[0]
      when "ooe"
        game.areas[2].sectors[0].rooms[4]
      end
    end
    
    @max_up_items = []
    if options[:randomize_item_stats]
      reset_rng()
      case GAME
      when "por"
        possible_max_up_ids = (0..0x5F).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x00, 0x04] # Don't let starting items (potion and high tonic) be max ups.
        2.times do
          max_up_id = possible_max_up_ids.sample(random: rng)
          possible_max_up_ids.delete(max_up_id)
          @max_up_items << max_up_id
        end
      when "ooe"
        possible_max_up_ids = (0x75..0xE4).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        possible_max_up_ids -= [0x75, 0x79] # Don't let starting items (potion and high tonic) be max ups.
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
    
    # Specifies which pickup flags weren't used in the original game in case we need new ones for something.
    case GAME
    when "dos"
      # For DoS we sometimes need pickup flags for when a soul candle gets randomized into something that's not a soul candle.
      # Flags 7A-7F are unused in the base game but still work, so use those.
      @unused_picked_up_flags = (0x7A..0x7F).to_a
    when "por"
      # We don't need spare pickup flags for the pickup randomizer in PoR, but we do need it for the starting item randomizer.
      @unused_picked_up_flags = (0x16D..0x174).to_a + (0x177..0x17F).to_a
    when "ooe"
      # For OoE we sometimes need pickup flags for when a glyph statue gets randomized into something that's not a glyph statue.
      # Flags 12F-149 are unused in the base game but still work, so use those.
      @unused_picked_up_flags = (0x12F..0x149).to_a
    end
    @used_picked_up_flags = []
    
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
      enemy_dna = EnemyDNA.new(enemy_id, game.fs)
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
    
    if options[:randomize_bosses]
      yield [options_completed, "Shuffling bosses..."]
      reset_rng()
      randomize_bosses()
      options_completed += 1
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
    
    if options[:randomize_item_stats]
      yield [options_completed, "Randomizing item stats..."]
      reset_rng()
      randomize_item_stats()
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
    
    room_rando = options[:randomize_room_connections] || options[:randomize_area_connections] || options[:randomize_starting_room]
    
    if GAME == "dos" && options[:unlock_boss_doors] || GAME == "dos" && room_rando
      game.apply_armips_patch("dos_skip_boss_door_seals")
    end
    
    if GAME == "dos" && room_rando
      # Remove the special code for the slide puzzle.
      game.fs.write(0x0202738C, [0xE3A00000, 0xE8BD41F0, 0xE12FFF1E].pack("V*"))
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && entity.subtype == 0x0D
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
    end
    
    if GAME == "por" && options[:fix_infinite_quest_rewards]
      game.apply_armips_patch("por_fix_infinite_quest_rewards")
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
    
    if options[:remove_area_names]
      area_name_subtype = case GAME
      when "dos"
        0x06
      when "por"
        0x79
      when "ooe"
        0x55
      end
      
      game.each_room do |room|
        room.entities.each do |entity|
          if entity.is_special_object? && entity.subtype == area_name_subtype
            entity.type = 0
            entity.write_to_rom()
          end
        end
      end
    end
  end
  
  def inspect; to_s; end
end
