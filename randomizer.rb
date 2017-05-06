
require 'digest/md5'

require_relative 'completability_checker'
require_relative 'randomizers/pickup_randomizer'
require_relative 'randomizers/enemy_randomizer'
require_relative 'randomizers/drop_randomizer'
require_relative 'randomizers/player_randomizer'
require_relative 'randomizers/boss_randomizer'
require_relative 'randomizers/door_randomizer'
require_relative 'randomizers/extra_randomizers'

class Randomizer
  include PickupRandomizer
  include EnemyRandomizer
  include DropRandomizer
  include PlayerRandomizer
  include BossRandomizer
  include DoorRandomizer
  include ExtraRandomizers
  
  attr_reader :options,
              :rng,
              :seed_log,
              :spoiler_log,
              :game,
              :checker
  
  def initialize(seed, game, options={})
    @game = game
    @checker = CompletabilityChecker.new(game, options[:enable_glitch_reqs], options[:open_world_map])
    
    @options = options
    
    @next_available_item_id = 1
    @used_skills = []
    @used_items = []
    
    if seed.nil? || seed.empty?
      raise "No seed given"
    end
    
    FileUtils.mkdir_p("./logs")
    @seed_log = File.open("./logs/seed_log_no_spoilers.txt", "a")
    seed_log.puts "Using seed: #{seed}, Game: #{LONG_GAME_NAME}"
    seed_log.close()
    
    @seed = seed
    int_seed = Digest::MD5.hexdigest(seed).to_i(16)
    @rng = Random.new(int_seed)
    
    # TODO: Make the below variables customizable in an advanced settings tab.
    @enemy_difficulty_preservation_weight_exponent = 3
    @weak_enemy_attack_threshold = 28
    @max_enemy_attack_room_multiplier = 1.3
    @max_spawners_per_room = 1
  end
  
  def rand_range_weighted_low(range)
    random_float = (1 - Math.sqrt(1 - rng.rand()))
    return (random_float * (range.max + 1 - range.min) + range.min).floor
  end
  
  def rand_range_weighted_very_low(range)
    random_float = (1 - Math.sqrt(Math.sqrt(1 - rng.rand())))
    return (random_float * (range.max + 1 - range.min) + range.min).floor
  end
  
  def randomize
    @spoiler_log = File.open("./logs/spoiler_log.txt", "a")
    spoiler_log.puts "Seed: #{@seed}, Game: #{LONG_GAME_NAME}"
    
    if options[:randomize_pickups]
      randomize_pickups_completably()
    end
    
    @unplaced_non_progression_pickups = all_non_progression_pickups.dup
    @unplaced_non_progression_pickups -= checker.current_items
    
    if options[:randomize_enemy_drops]
      randomize_enemy_drops()
    end
    
    if options[:randomize_pickups]
      place_non_progression_pickups()
    end
    
    if options[:randomize_boss_souls] && GAME == "dos"
      # If the player beats Balore but doesn't own Balore's soul they will appear stuck. (Though they could always escape with suspend.)
      # So get rid of the line of code Balore runs when he dies that recreates the Balore blocks in the room.
      
      game.fs.load_overlay(23)
      game.fs.write(0x02300808, [0xE1A00000].pack("V"))
    end
    
    if options[:randomize_enemies]
      randomize_enemies()
    end
    
    if options[:randomize_bosses]
      randomize_bosses()
    end
    
    if options[:randomize_area_connections]
      randomize_transition_doors()
    end
    
    if options[:randomize_room_connections]
      randomize_non_transition_doors()
    end
    
    if options[:randomize_starting_room]
      game.fix_top_screen_on_new_game()
      randomize_starting_room()
    end
    
    if options[:randomize_enemy_ai]
      randomize_enemy_ai()
    end
    
    if options[:randomize_players]
      randomize_players()
    end
    
    if options[:randomize_item_stats]
      randomize_item_stats()
    end
    
    if options[:randomize_skill_stats]
      randomize_skill_stats()
    end
    
    if options[:randomize_enemy_stats]
      randomize_enemy_stats()
    end
    
    if options[:randomize_weapon_synths]
      randomize_weapon_synths()
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
