
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
  
  attr_reader :options,
              :seed,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker
  
  def initialize(seed, game, options)
    @seed = seed
    @game = game
    @options = options
    
    if seed.nil? || seed.empty?
      raise "No seed given"
    end
    
    @checker = CompletabilityChecker.new(game, options[:enable_glitch_reqs], options[:open_world_map], options[:randomize_villagers])
    
    @int_seed = Digest::MD5.hexdigest(seed).to_i(16)
    @rng = Random.new(@int_seed)
    
    # TODO: Make the below variables customizable in an advanced settings tab.
    @enemy_difficulty_preservation_weight_exponent = 3
    @weak_enemy_attack_threshold = 28
    @max_enemy_attack_room_multiplier = 1.3
    @max_spawners_per_room = 1
    
    @item_price_range               = [100..25000, low_weight: 2]
    @weapon_attack_range            = [0..150    , low_weight: 2]
    @weapon_iframes_range           =  4..55
    @armor_defense_range            = [0..45     , low_weight: 2]
    @item_extra_stats_range         = [1..100    , low_weight: 4]
    @restorative_amount_range       = [1..1000   , low_weight: 2]
    @heart_restorative_amount_range = [1..350    , low_weight: 2]
    
    @skill_price_1000g_range        = [1..30     , low_weight: 1]
    @skill_dmg_range                = [5..55     , low_weight: 3]
    @crush_or_union_dmg_range       = [15..85    , low_weight: 1]
    @subweapon_sp_to_master_range   =  100..3000
    @spell_charge_time_range        = [8..120    , low_weight: 2]
    @skill_mana_cost_range          =  1..60
    @crush_mana_cost_range          =  50..250
    @union_heart_cost_range         = [5..50     , low_weight: 1]
    @skill_max_at_once_range        = [1..8      , low_weight: 1]
    @glyph_attack_delay_range       = [1..20     , low_weight: 1]
    
    @enemy_stat_mult_range = 0.5..2.5
    
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
  
  # Gets a random number within a range, but weighted low.
  # The higher the low_weight argument the more strongly low weighted it is. Examples:
  # 0 -> 50%
  # 1 -> 33%
  # 2 -> 21%
  # 3 -> 11.5%
  # 4 -> 6.5%
  # 5 -> 3.5%
  def rand_range_weighted_low(range, low_weight: 1)
    random_float = 1 - rand()
    low_weight.times do
      random_float = Math.sqrt(random_float)
    end
    random_float = 1 - random_float
    return (random_float * (range.max + 1 - range.min) + range.min).floor
  end
  
  def rand_range_weighted_very_low(range)
    return rand_range_weighted_low(range, low_weight: 2)
  end
  
  def randomize
    options_string = options.select{|k,v| v == true}.keys.join(", ")
    
    FileUtils.mkdir_p("./logs")
    @seed_log = File.open("./logs/seed_log_no_spoilers.txt", "a")
    seed_log.puts "Seed: #{seed}, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
    seed_log.puts "  Selected options: #{options_string}"
    seed_log.close()
    
    @spoiler_log = File.open("./logs/spoiler_log.txt", "a")
    spoiler_log.puts "Seed: #{@seed}, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
    spoiler_log.puts "Selected options: #{options_string}"
    
    @max_up_items = []
    if options[:randomize_item_stats]
      reset_rng()
      case GAME
      when "por"
        possible_max_up_ids = (0..0x5F).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
        2.times do
          max_up_id = possible_max_up_ids.sample(random: rng)
          possible_max_up_ids.delete(max_up_id)
          @max_up_items << max_up_id
        end
      when "ooe"
        possible_max_up_ids = (0x75..0xE4).to_a - checker.all_progression_pickups - NONRANDOMIZABLE_PICKUP_GLOBAL_IDS
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
    
    if options[:randomize_pickups]
      reset_rng()
      randomize_pickups_completably()
    end
    
    @unplaced_non_progression_pickups = all_non_progression_pickups.dup
    @unplaced_non_progression_pickups -= checker.current_items
    
    if options[:randomize_enemy_drops]
      reset_rng()
      randomize_enemy_drops()
    end
    
    if options[:randomize_pickups]
      reset_rng()
      place_non_progression_pickups()
    end
    
    if options[:randomize_boss_souls] && GAME == "dos"
      # If the player beats Balore but doesn't own Balore's soul they will appear stuck. (Though they could always escape with suspend.)
      # So get rid of the line of code Balore runs when he dies that recreates the Balore blocks in the room.
      
      game.fs.load_overlay(23)
      game.fs.write(0x02300808, [0xE1A00000].pack("V"))
    end
    
    @original_enemy_dnas = []
    ENEMY_IDS.each do |enemy_id|
      enemy_dna = EnemyDNA.new(enemy_id, game.fs)
      @original_enemy_dnas << enemy_dna
    end
    
    if options[:randomize_enemy_stats]
      reset_rng()
      randomize_enemy_stats()
    end
    
    if options[:randomize_enemies]
      reset_rng()
      randomize_enemies()
    end
    
    if options[:randomize_bosses]
      reset_rng()
      randomize_bosses()
    end
    
    if options[:randomize_area_connections]
      reset_rng()
      randomize_transition_doors()
    end
    
    if options[:randomize_room_connections]
      reset_rng()
      randomize_non_transition_doors()
    end
    
    if options[:randomize_starting_room]
      reset_rng()
      game.fix_top_screen_on_new_game()
      randomize_starting_room()
    end
    
    if options[:randomize_enemy_ai]
      reset_rng()
      randomize_enemy_ai()
    end
    
    if options[:randomize_players]
      reset_rng()
      randomize_players()
    end
    
    if options[:randomize_item_stats]
      reset_rng()
      randomize_item_stats()
    end
    
    if options[:randomize_skill_stats]
      reset_rng()
      randomize_skill_stats()
    end
    
    if options[:randomize_weapon_synths]
      reset_rng()
      randomize_weapon_synths()
    end
    
    if options[:randomize_shop]
      reset_rng()
      randomize_shop()
    end
    
    if options[:randomize_wooden_chests]
      reset_rng()
      randomize_wooden_chests()
    end
    
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
  rescue StandardError => e
    spoiler_log.puts "ERROR!"
    raise e
  ensure
    spoiler_log.puts
    spoiler_log.puts
    spoiler_log.close()
  end
  
  def inspect; to_s; end
end
