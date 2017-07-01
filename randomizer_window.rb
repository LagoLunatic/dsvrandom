
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
    randomize_starting_items
    
    enable_glitch_reqs

    name_unnamed_skills
    unlock_all_modes
    reveal_breakable_walls
    fix_first_ability_soul
    no_touch_screen
    fix_luck
    unlock_boss_doors
    fix_infinite_quest_rewards
    dont_randomize_change_cube
    open_world_map
    always_dowsing
  )
  
  DIFFICULTY_OPTION_PRETTY_NAMES = {
    :item_price_range               => "Item Price",
    :weapon_attack_range            => "Weapon ATK",
    :weapon_iframes_range           => "Weapon IFrames",
    :armor_defense_range            => "Armor DEF",
    :item_extra_stats_range         => "Other stats",
    :restorative_amount_range       => "Restorative Amount",
    :heart_restorative_amount_range => "Heart Repair Amount",
    :ap_increase_amount_range       => "Attribute Point Boost Amount",
    
    :skill_price_range              => "Skill Price (PoR)",
    :skill_dmg_range                => "Skill Damage",
    :crush_or_union_dmg_range       => "Dual Crush/Glyph Union Damage",
    :subweapon_sp_to_master_range   => "Subweapon SP To Master",
    :spell_charge_time_range        => "Spell Charge Time",
    :skill_mana_cost_range          => "Skill Mana Cost",
    :crush_mana_cost_range          => "Dual Crush Mana Cost",
    :union_heart_cost_range         => "Glyph Union Heart Cost",
    :skill_max_at_once_range        => "Skill Max-on-screen",
    :glyph_attack_delay_range       => "Glyph Attack Delay"
  }
  
  slots "update_settings()"
  slots "browse_for_clean_rom()"
  slots "browse_for_output_folder()"
  slots "difficulty_level_changed(int)"
  slots "difficulty_slider_moved()"
  slots "difficulty_slider_moved(int)"
  slots "generate_seed()"
  slots "randomize()"
  slots "open_about()"
  
  def initialize
    super(nil, Qt::WindowMinimizeButtonHint)
    @ui = Ui_Randomizer.new
    @ui.setup_ui(self)
    
    initialize_difficulty_sliders()
    
    load_settings()
    
    connect(@ui.clean_rom, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    connect(@ui.clean_rom_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_clean_rom()"))
    connect(@ui.output_folder, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    connect(@ui.output_folder_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_output_folder()"))
    connect(@ui.generate_seed_button, SIGNAL("clicked()"), self, SLOT("generate_seed()"))
    connect(@ui.seed, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    
    OPTIONS.each do |option_name|
      connect(@ui.send(option_name), SIGNAL("stateChanged(int)"), self, SLOT("update_settings()"))
    end
    
    connect(@ui.randomize_button, SIGNAL("clicked()"), self, SLOT("randomize()"))
    connect(@ui.about_button, SIGNAL("clicked()"), self, SLOT("open_about()"))
    
    self.setWindowTitle("DSVania Randomizer #{DSVRANDOM_VERSION}")
    
    connect(@ui.difficulty_level, SIGNAL("activated(int)"), self, SLOT("difficulty_level_changed(int)"))
    
    update_settings()
    
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
    
    difficulty_level_options = Randomizer::DIFFICULTY_LEVELS[@settings[:difficulty_level]]
    if difficulty_level_options
      # Preset difficulty level.
      @ui.difficulty_level.count.times do |i|
        if @ui.difficulty_level.itemText(i) == @settings[:difficulty_level]
          difficulty_level_changed(i)
          break
        end
      end
    elsif @settings[:difficulty_options]
      # Custom difficulty.
      form_layout = @ui.scrollAreaWidgetContents.layout
      
      @settings[:difficulty_options].each_with_index do |(option_name, average), i|
        slider = form_layout.itemAt(i, Qt::FormLayout::FieldRole).widget
        slider.value = average
        slider.setToolTip(slider.value.to_s)
      end
    else
      # First boot, default to easy difficulty.
      difficulty_level_changed(1)
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
    
    if !@settings[:randomize_pickups]
      @ui.randomize_boss_souls.checked = false
      @ui.randomize_boss_souls.enabled = false
      @ui.randomize_villagers.checked = false
      @ui.randomize_villagers.enabled = false
    else
      @ui.randomize_boss_souls.enabled = true
      @ui.randomize_villagers.enabled = true
    end
    
    @settings[:difficulty_level] = @ui.difficulty_level.itemText(@ui.difficulty_level.currentIndex)
    @settings[:difficulty_options] = {}
    Randomizer::DIFFICULTY_RANGES.keys.each_with_index do |name, i|
      slider = @ui.scrollAreaWidgetContents.layout.itemAt(i, Qt::FormLayout::FieldRole).widget
      average = slider.value
      @settings[:difficulty_options][name] = average
    end
    
    save_settings()
  end
  
  def initialize_difficulty_sliders
    # Remove the grey background color of the scroll area.
    @ui.scrollArea.setStyleSheet("QScrollArea {background-color:transparent;}");
    @ui.scrollAreaWidgetContents.setStyleSheet("background-color:transparent;");
    
    form_layout = @ui.scrollAreaWidgetContents.layout
    
    Randomizer::DIFFICULTY_RANGES.each_with_index do |(option_name, option_value_range), i|
      option_value_range = Randomizer::DIFFICULTY_RANGES[option_name]
      pretty_name = DIFFICULTY_OPTION_PRETTY_NAMES[option_name]
      
      label = Qt::Label.new(@ui.scrollAreaWidgetContents)
      label.text = pretty_name# + " (#{option_value_range})"
      form_layout.setWidget(i, Qt::FormLayout::LabelRole, label)
      
      slider = Qt::Slider.new(@ui.scrollAreaWidgetContents)
      slider.pageStep = 1
      slider.orientation = Qt::Horizontal
      slider.minimum = option_value_range.begin
      slider.maximum = option_value_range.end
      connect(slider, SIGNAL("sliderPressed()"), self, SLOT("difficulty_slider_moved()"))
      connect(slider, SIGNAL("sliderMoved(int)"), self, SLOT("difficulty_slider_moved(int)"))
      form_layout.setWidget(i, Qt::FormLayout::FieldRole, slider)
    end
    
    @ui.difficulty_level.addItem("Custom")
    Randomizer::DIFFICULTY_LEVELS.keys.each do |name|
      @ui.difficulty_level.addItem(name)
    end
  end
  
  def difficulty_slider_moved(value = nil)
    # Shows the tooltip containing the current value of the slider.
    slider = sender()
    slider.setToolTip(slider.value.to_s)
    global_pos = slider.rect.topLeft
    global_pos.x += Qt::Style.sliderPositionFromValue(slider.minimum, slider.maximum, slider.value, slider.width())
    global_pos.y += slider.height / 2
    toolTipEvent = Qt::HelpEvent.new(Qt::Event::ToolTip, Qt::Point.new(0, 0), slider.mapToGlobal(global_pos))
    $qApp.sendEvent(slider, toolTipEvent)
    
    @ui.difficulty_level.setCurrentIndex(0)
    
    update_settings()
  end
  
  def difficulty_level_changed(diff_index)
    @ui.difficulty_level.setCurrentIndex(diff_index)
    
    difficulty_name = @ui.difficulty_level.itemText(diff_index)
    
    diff_averages = Randomizer::DIFFICULTY_LEVELS[difficulty_name]
    if diff_averages
      form_layout = @ui.scrollAreaWidgetContents.layout
      
      diff_averages.each_with_index do |(option_name, average), i|
        slider = form_layout.itemAt(i, Qt::FormLayout::FieldRole).widget
        slider.value = average
        slider.setToolTip(slider.value.to_s)
      end
    end
    
    update_settings()
  end
  
  def generate_seed
    # Generate a new random seed composed of 2 adjectives and a noun.
    adjectives = File.read("./dsvrandom/seedgen_adjectives.txt").split("\n").sample(2)
    noun = File.read("./dsvrandom/seedgen_nouns.txt").split("\n").sample
    words = adjectives + [noun]
    words.map!{|word| word.capitalize}
    seed = words.join("")
    
    @settings[:seed] = seed
    @ui.seed.text = @settings[:seed]
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
      generate_seed()
      seed = @settings[:seed]
    end
    
    if seed =~ /[^a-zA-Z0-9\-_']/
      raise "Invalid seed. Seed can only have letters, numbers, dashes, underscores, and apostrophes in it."
    end
    
    @settings[:seed] = seed
    @ui.seed.text = @settings[:seed]
    save_settings()
    
    @sanitized_seed = seed
    
    options_hash = {}
    OPTIONS.each do |option_name|
      options_hash[option_name] = @ui.send(option_name).checked
    end
    
    difficulty_settings_averages = {}
    Randomizer::DIFFICULTY_RANGES.keys.each_with_index do |name, i|
      slider = @ui.scrollAreaWidgetContents.layout.itemAt(i, Qt::FormLayout::FieldRole).widget
      average = slider.value
      difficulty_settings_averages[name] = average
    end
    
    randomizer = Randomizer.new(seed, game, options_hash, difficulty_settings_averages)
    
    max_val = options_hash.select{|k,v| k.to_s.start_with?("randomize_") && v}.length
    max_val += 20 if options_hash[:randomize_pickups]
    max_val += 7 if options_hash[:randomize_enemies]
    max_val += 2 # Initialization
    @progress_dialog = ProgressDialog.new("Randomizing", "Initializing...", max_val)
    @progress_dialog.execute do
      begin
        randomizer.randomize() do |options_completed, next_option_description|
          break if @progress_dialog.nil?
          
          Qt.execute_in_main_thread do
            if @progress_dialog && !@progress_dialog.wasCanceled
              @progress_dialog.setValue(options_completed)
              @progress_dialog.labelText = next_option_description
            end
          end
        end
      rescue StandardError => e
        Qt.execute_in_main_thread do
          @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
          @progress_dialog.hide()
          @progress_dialog = nil
          Qt::MessageBox.critical(self, "Randomization Failed", "Randomization failed with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
        end
        return
      end
      
      Qt.execute_in_main_thread do
        @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
        @progress_dialog.hide()
        @progress_dialog = nil
        write_to_rom(game)
      end
    end
  rescue NDSFileSystem::InvalidFileError => e
    Qt::MessageBox.warning(self, "Unrecognized game", "Specified ROM is not recognized.")
    return
  end
  
  def write_to_rom(game)
    FileUtils.mkdir_p(@ui.output_folder.text)
    game_with_caps = GAME.dup
    game_with_caps[0] = game_with_caps[0].upcase
    game_with_caps[2] = game_with_caps[2].upcase
    output_rom_filename = "#{game_with_caps} #{@sanitized_seed}.nds"
    output_rom_path = File.join(@ui.output_folder.text, output_rom_filename)
    
    max_val = game.fs.files_without_dirs.length
    @progress_dialog = ProgressDialog.new("Building", "Writing files to ROM", max_val)
    @progress_dialog.execute do
      game.fs.write_to_rom(output_rom_path) do |files_written|
        next unless files_written % 100 == 0 # Only update the UI every 100 files because updating too often is slow.
        break if @progress_dialog.nil?
        
        Qt.execute_in_main_thread do
          if @progress_dialog && !@progress_dialog.wasCanceled
            @progress_dialog.setValue(files_written)
          end
        end
      end
      
      Qt.execute_in_main_thread do
        @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
        @progress_dialog = nil
        Qt::MessageBox.information(self, "Done", "Randomization complete.\n\nOutput ROM:\n#{output_rom_filename}\n\nIf you get stuck, check the FAQ\nin the readme, and the progression\nspoiler log here: /logs/spoiler_log.txt")
      end
    end
  end
  
  def open_about
    @about_dialog = Qt::MessageBox::about(self, "DSVania Randomizer", "DSVania Randomizer Version #{DSVRANDOM_VERSION}\n\nCreated by LagoLunatic\n\nSource code:\nhttps://github.com/LagoLunatic/dsvrandom\n\nReport issues here:\nhttps://github.com/LagoLunatic/dsvrandom/issues")
  end
end

class ProgressDialog < Qt::ProgressDialog
  slots "cancel_write_to_rom_thread()"
  
  def initialize(title, description, max_val)
    super()
    self.windowTitle = title
    self.labelText = description
    self.maximum = max_val
    self.windowModality = Qt::ApplicationModal
    self.windowFlags = Qt::CustomizeWindowHint | Qt::WindowTitleHint
    self.setFixedSize(self.size);
    connect(self, SIGNAL("canceled()"), self, SLOT("cancel_write_to_rom_thread()"))
    self.show
  end
  
  def execute(&block)
    @write_to_rom_thread = Thread.new do
      yield
    end
  end
  
  def cancel_write_to_rom_thread
    puts "Cancelled."
    @write_to_rom_thread.kill
  end
end
