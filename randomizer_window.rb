
require_relative 'ui_randomizer'
require_relative 'randomizer'

class RandomizerWindow < Qt::Dialog
  OPTIONS = %i(
    randomize_pickups
    randomize_enemies
    randomize_enemy_drops
    randomize_boss_souls
    randomize_item_stats
    randomize_skill_stats
    randomize_shop
    randomize_wooden_chests
    randomize_villagers
    randomize_weapon_synths
    
    randomize_players
    randomize_bosses
    randomize_area_connections
    randomize_room_connections
    randomize_starting_room
    randomize_enemy_ai
    randomize_enemy_stats
    
    enable_glitch_reqs

    name_unnamed_skills
    unlock_all_modes
    reveal_breakable_walls
    fix_first_ability_soul
    no_touch_screen
    fix_luck
    unlock_boss_doors
    dont_randomize_change_cube
    open_world_map
    always_dowsing
  )
  
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
    
    OPTIONS.each do |option_name|
      connect(@ui.send(option_name), SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    end
    
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
    
    OPTIONS.each do |option_name|
      @ui.send(option_name).setChecked(@settings[option_name]) unless @settings[option_name].nil?
    end
  end
  
  def save_settings
    File.open(@settings_path, "w") do |f|
      f.write(@settings.to_yaml)
    end
  end
  
  def closeEvent(event)
    save_settings()
  end
  
  def browse_for_clean_rom
    if @settings[:clean_rom_path] && File.file?(@settings[:clean_rom_path])
      default_dir = File.dirname(@settings[:clean_rom_path])
    end
    
    clean_rom_path = Qt::FileDialog.getOpenFileName(self, "Select ROM", default_dir, "NDS ROM Files (*.nds)")
    return if clean_rom_path.nil?
    @ui.clean_rom.text = clean_rom_path
    update_settings()
  end
  
  def browse_for_output_folder
    if @settings[:output_folder] && File.directory?(@settings[:output_folder])
      default_dir = @settings[:output_folder]
    end
    
    output_folder_path = Qt::FileDialog.getExistingDirectory(self, "Select output folder", default_dir)
    return if output_folder_path.nil?
    @ui.output_folder.text = output_folder_path
    update_settings()
  end
  
  def update_settings
    @settings[:clean_rom_path] = @ui.clean_rom.text
    @settings[:output_folder] = @ui.output_folder.text
    @settings[:seed] = @ui.seed.text
    
    OPTIONS.each do |option_name|
      @settings[option_name] = @ui.send(option_name).checked
    end
    
    save_settings()
  end
  
  def randomize
    unless File.file?(@ui.clean_rom.text)
      Qt::MessageBox.warning(self, "No ROM specified", "Must specify clean ROM path.")
      return
    end
    unless File.directory?(@ui.output_folder.text)
      Qt::MessageBox.warning(self, "No output folder specified", "Must specify a valid output folder for the randomized ROM.")
      return
    end
    
    game = Game.new
    game.initialize_from_rom(@ui.clean_rom.text, extract_to_hard_drive = false)
    
    if !["dos", "por", "ooe"].include?(GAME)
      Qt::MessageBox.warning(self, "Unsupported game", "ROM is not a supported game.")
      return
    end
    if REGION != :usa
      Qt::MessageBox.warning(self, "Unsupported region", "Only the US versions are supported.")
      return
    end
    
    seed = @settings[:seed].to_s.strip.gsub(/\s/, "")
    
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
    
    randomizer = Randomizer.new(seed, game,
      :randomize_pickups => @ui.randomize_pickups.checked(),
      :randomize_enemies => @ui.randomize_enemies.checked(),
      :randomize_bosses => @ui.randomize_bosses.checked(),
      :randomize_enemy_drops => @ui.randomize_enemy_drops.checked(),
      :randomize_boss_souls => @ui.randomize_boss_souls.checked(),
      :randomize_villagers => @ui.randomize_villagers.checked(),
      :randomize_area_connections => @ui.randomize_area_connections.checked(),
      :randomize_room_connections => @ui.randomize_room_connections.checked(),
      :randomize_starting_room => @ui.randomize_starting_room.checked(),
      :randomize_enemy_ai => @ui.randomize_enemy_ai.checked(),
      :randomize_players => @ui.randomize_players.checked(),
      :randomize_item_stats => @ui.randomize_item_stats.checked(),
      :randomize_skill_stats => @ui.randomize_skill_stats.checked(),
      :randomize_enemy_stats => @ui.randomize_enemy_stats.checked(),
      :randomize_weapon_synths => @ui.randomize_weapon_synths.checked(),
      :randomize_shop => @ui.randomize_shop.checked(),
      :randomize_wooden_chests => @ui.randomize_wooden_chests.checked(),
      :enable_glitch_reqs => @ui.enable_glitch_reqs.checked(),
      :unlock_boss_doors => @ui.unlock_boss_doors.checked(),
      :dont_randomize_change_cube => @ui.dont_randomize_change_cube.checked(),
      :open_world_map => @ui.open_world_map.checked(),
    )
    randomizer.randomize()
    
    if GAME == "dos" && @ui.fix_first_ability_soul.checked()
      game.apply_armips_patch("dos_fix_first_ability_soul")
    end
    
    if GAME == "dos" && @ui.no_touch_screen.checked()
      game.apply_armips_patch("dos_skip_drawing_seals")
      game.apply_armips_patch("dos_melee_balore_blocks")
      game.apply_armips_patch("dos_skip_name_signing")
    end
    
    if GAME == "dos" && @ui.fix_luck.checked()
      game.apply_armips_patch("dos_fix_luck")
    end
    
    if GAME == "dos" && @ui.unlock_boss_doors.checked()
      game.apply_armips_patch("dos_skip_boss_door_seals")
    end
    
    if GAME == "ooe" && @ui.always_dowsing.checked()
      game.apply_armips_patch("ooe_always_dowsing")
    end
    
    if @ui.name_unnamed_skills.checked()
      game.fix_unnamed_skills()
    end
    
    if @ui.unlock_all_modes.checked()
      game.apply_armips_patch("#{GAME}_unlock_everything")
    end
    
    if @ui.reveal_breakable_walls.checked()
      game.apply_armips_patch("#{GAME}_reveal_breakable_walls")
    end
    
    write_to_rom(game)
  rescue NDSFileSystem::InvalidFileError => e
    Qt::MessageBox.warning(self, "Unrecognized game", "Specified ROM is not recognized.")
    return
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
