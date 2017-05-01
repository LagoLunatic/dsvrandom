
require_relative 'ui_randomizer'
require_relative 'randomizer'

class RandomizerWindow < Qt::Dialog
  slots "update_settings()"
  slots "browse_for_clean_rom()"
  slots "browse_for_output_folder()"
  slots "randomize()"
  slots "cancel_write_to_rom_thread()"
  slots "open_about()"
  
  def initialize
    super(nil, Qt::WindowMinimizeButtonHint)
    @ui = Ui_Randomizer.new
    @ui.setup_ui(self)
    
    load_settings()
    
    connect(@ui.clean_rom, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    connect(@ui.clean_rom_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_clean_rom()"))
    connect(@ui.output_folder, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    connect(@ui.output_folder_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_output_folder()"))
    connect(@ui.seed, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    
    connect(@ui.randomize_pickups, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_enemies, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_bosses, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_enemy_drops, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_boss_souls, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_area_connections, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_room_connections, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_starting_room, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_enemy_ai, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_players, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_item_stats, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_skill_stats, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_enemy_stats, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.randomize_weapon_synths, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    
    connect(@ui.enable_glitch_reqs, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    
    connect(@ui.fix_first_ability_soul, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.no_touch_screen, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.fix_luck, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    connect(@ui.open_world_map, SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    
    connect(@ui.randomize_button, SIGNAL("clicked()"), self, SLOT("randomize()"))
    connect(@ui.about_button, SIGNAL("clicked()"), self, SLOT("open_about()"))
    
    self.setWindowTitle("DSVania Randomizer #{DSVRANDOM_VERSION}")
    
    self.show()
  end
  
  def load_settings
    @settings_path = "randomizer_settings.yml"
    if File.exist?(@settings_path)
      @settings = YAML::load_file(@settings_path)
    else
      @settings = {}
    end
    
    @ui.clean_rom.setText(@settings[:clean_rom_path]) if @settings[:clean_rom_path]
    @ui.output_folder.setText(@settings[:output_folder]) if @settings[:output_folder]
    @ui.seed.setText(@settings[:seed]) if @settings[:seed]
    
    @ui.randomize_pickups.setChecked(@settings[:randomize_pickups]) unless @settings[:randomize_pickups].nil?
    @ui.randomize_enemies.setChecked(@settings[:randomize_enemies]) unless @settings[:randomize_enemies].nil?
    @ui.randomize_bosses.setChecked(@settings[:randomize_bosses]) unless @settings[:randomize_bosses].nil?
    @ui.randomize_enemy_drops.setChecked(@settings[:randomize_enemy_drops]) unless @settings[:randomize_enemy_drops].nil?
    @ui.randomize_boss_souls.setChecked(@settings[:randomize_boss_souls]) unless @settings[:randomize_boss_souls].nil?
    @ui.randomize_area_connections.setChecked(@settings[:randomize_area_connections]) unless @settings[:randomize_area_connections].nil?
    @ui.randomize_room_connections.setChecked(@settings[:randomize_room_connections]) unless @settings[:randomize_room_connections].nil?
    @ui.randomize_starting_room.setChecked(@settings[:randomize_starting_room]) unless @settings[:randomize_starting_room].nil?
    @ui.randomize_enemy_ai.setChecked(@settings[:randomize_enemy_ai]) unless @settings[:randomize_enemy_ai].nil?
    @ui.randomize_players.setChecked(@settings[:randomize_players]) unless @settings[:randomize_players].nil?
    @ui.randomize_item_stats.setChecked(@settings[:randomize_item_stats]) unless @settings[:randomize_item_stats].nil?
    @ui.randomize_skill_stats.setChecked(@settings[:randomize_skill_stats]) unless @settings[:randomize_skill_stats].nil?
    @ui.randomize_enemy_stats.setChecked(@settings[:randomize_enemy_stats]) unless @settings[:randomize_enemy_stats].nil?
    @ui.randomize_weapon_synths.setChecked(@settings[:randomize_weapon_synths]) unless @settings[:randomize_weapon_synths].nil?
    
    @ui.enable_glitch_reqs.setChecked(@settings[:enable_glitch_reqs]) unless @settings[:enable_glitch_reqs].nil?
    
    @ui.fix_first_ability_soul.setChecked(@settings[:fix_first_ability_soul]) unless @settings[:fix_first_ability_soul].nil?
    @ui.no_touch_screen.setChecked(@settings[:no_touch_screen]) unless @settings[:no_touch_screen].nil?
    @ui.fix_luck.setChecked(@settings[:fix_luck]) unless @settings[:fix_luck].nil?
    @ui.open_world_map.setChecked(@settings[:open_world_map]) unless @settings[:open_world_map].nil?
  end
  
  def closeEvent(event)
    File.open(@settings_path, "w") do |f|
      f.write(@settings.to_yaml)
    end
  end
  
  def browse_for_clean_rom
    clean_rom_path = Qt::FileDialog.getOpenFileName(self, "Select ROM", nil, "NDS ROM Files (*.nds)")
    return if clean_rom_path.nil?
    @ui.clean_rom.text = clean_rom_path
  end
  
  def browse_for_output_folder
    output_folder_path = Qt::FileDialog.getExistingDirectory(self, "Select output folder", nil)
    return if output_folder_path.nil?
    @ui.output_folder.text = output_folder_path
  end
  
  def update_settings
    @settings[:clean_rom_path] = @ui.clean_rom.text
    @settings[:output_folder] = @ui.output_folder.text
    @settings[:seed] = @ui.seed.text
    
    @settings[:randomize_pickups] = @ui.randomize_pickups.checked
    @settings[:randomize_enemies] = @ui.randomize_enemies.checked
    @settings[:randomize_bosses] = @ui.randomize_bosses.checked
    @settings[:randomize_enemy_drops] = @ui.randomize_enemy_drops.checked
    @settings[:randomize_boss_souls] = @ui.randomize_boss_souls.checked
    @settings[:randomize_area_connections] = @ui.randomize_area_connections.checked
    @settings[:randomize_room_connections] = @ui.randomize_room_connections.checked
    @settings[:randomize_starting_room] = @ui.randomize_starting_room.checked
    @settings[:randomize_enemy_ai] = @ui.randomize_enemy_ai.checked
    @settings[:randomize_players] = @ui.randomize_players.checked
    @settings[:randomize_item_stats] = @ui.randomize_item_stats.checked
    @settings[:randomize_skill_stats] = @ui.randomize_skill_stats.checked
    @settings[:randomize_enemy_stats] = @ui.randomize_enemy_stats.checked
    @settings[:randomize_weapon_synths] = @ui.randomize_weapon_synths.checked
    
    @settings[:enable_glitch_reqs] = @ui.enable_glitch_reqs.checked
    
    @settings[:fix_first_ability_soul] = @ui.fix_first_ability_soul.checked
    @settings[:no_touch_screen] = @ui.no_touch_screen.checked
    @settings[:fix_luck] = @ui.fix_luck.checked
    @settings[:open_world_map] = @ui.open_world_map.checked
  end
  
  def randomize
    seed = @settings[:seed].strip.gsub(/\s/, "")
    
    if seed.empty?
      # Generate a new seed
      available_seed_chars = ["0".."9", "A".."Z", "a".."z"].map(&:to_a).flatten
      seed = ""
      9.times do
        seed << available_seed_chars.sample
      end
    end
    
    if seed =~ /[^a-zA-Z0-9\-_]/
      raise "Invalid seed. Seed can only have letters, numbers, dashes, and underscores in it."
    end
    
    @settings[:seed] = seed
    @ui.seed.text = @settings[:seed]
    
    @sanitized_seed = seed
    
    game = Game.new
    game.initialize_from_rom(@ui.clean_rom.text, extract_to_hard_drive = false)
    
    randomizer = Randomizer.new(seed, game,
      :randomize_pickups => @ui.randomize_pickups.checked(),
      :randomize_enemies => @ui.randomize_enemies.checked(),
      :randomize_bosses => @ui.randomize_bosses.checked(),
      :randomize_enemy_drops => @ui.randomize_enemy_drops.checked(),
      :randomize_boss_souls => @ui.randomize_boss_souls.checked(),
      :randomize_area_connections => @ui.randomize_area_connections.checked(),
      :randomize_room_connections => @ui.randomize_room_connections.checked(),
      :randomize_starting_room => @ui.randomize_starting_room.checked(),
      :randomize_enemy_ai => @ui.randomize_enemy_ai.checked(),
      :randomize_players => @ui.randomize_players.checked(),
      :randomize_item_stats => @ui.randomize_item_stats.checked(),
      :randomize_skill_stats => @ui.randomize_skill_stats.checked(),
      :randomize_enemy_stats => @ui.randomize_enemy_stats.checked(),
      :randomize_weapon_synths => @ui.randomize_weapon_synths.checked(),
      :enable_glitch_reqs => @ui.enable_glitch_reqs.checked()
    )
    randomizer.randomize()
    
    if @ui.fix_first_ability_soul.checked()
      game.apply_armips_patch("dos_fix_first_ability_soul")
    end
    
    if @ui.no_touch_screen.checked()
      game.apply_armips_patch("dos_skip_drawing_seals")
      game.apply_armips_patch("dos_melee_balore_blocks")
      game.apply_armips_patch("dos_skip_name_signing")
    end
    
    if @ui.fix_luck.checked()
      game.apply_armips_patch("dos_fix_luck")
    end
    
    if @ui.open_world_map.checked()
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
    
    if @ui.name_unnamed_skills.checked()
      game.fix_unnamed_skills()
    end
    
    #game.apply_armips_patch("ooe_enter_any_wall")
    #game.apply_armips_patch("dos_use_what_you_see_souls")
    
    write_to_rom(game)
  rescue StandardError => e
    Qt::MessageBox.critical(self, "Randomization Failed", "Randomization failed with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
  end
  
  def write_to_rom(game)
    @progress_dialog = Qt::ProgressDialog.new
    @progress_dialog.windowTitle = "Building"
    @progress_dialog.labelText = "Writing files to ROM"
    @progress_dialog.maximum = game.fs.files_without_dirs.length
    @progress_dialog.windowModality = Qt::ApplicationModal
    @progress_dialog.windowFlags = Qt::CustomizeWindowHint | Qt::WindowTitleHint
    @progress_dialog.setFixedSize(@progress_dialog.size);
    connect(@progress_dialog, SIGNAL("canceled()"), self, SLOT("cancel_write_to_rom_thread()"))
    @progress_dialog.show
    
    FileUtils.mkdir_p(@ui.output_folder.text)
    output_rom_path = File.join(@ui.output_folder.text, "#{GAME} Random #{@sanitized_seed}.nds")
    
    @write_to_rom_thread = Thread.new do
      game.fs.write_to_rom(output_rom_path) do |files_written|
        next unless files_written % 100 == 0 # Only update the UI every 100 files because updating too often is slow.
        
        Qt.execute_in_main_thread do
          @progress_dialog.setValue(files_written) unless @progress_dialog.wasCanceled
        end
      end
      
      Qt.execute_in_main_thread do
        @progress_dialog.setValue(game.fs.files_without_dirs.length) unless @progress_dialog.wasCanceled
        @progress_dialog = nil
        Qt::MessageBox.information(self, "Done", "Randomization complete.")
      end
    end
  end
  
  def cancel_write_to_rom_thread
    puts "Cancelled."
    @write_to_rom_thread.kill
    @progress_dialog = nil
  end
  
  def open_about
    @about_dialog = Qt::MessageBox::about(self, "DSVania Randomizer", "DSVania Randomizer Version #{DSVRANDOM_VERSION}\n\nCreated by LagoLunatic\n\nSource code:\nhttps://github.com/LagoLunatic/dsvrandom\n\nReport issues here:\nhttps://github.com/LagoLunatic/dsvrandom/issues")
  end
end
