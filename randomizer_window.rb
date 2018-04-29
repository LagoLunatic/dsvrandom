
require_relative 'ui_randomizer'
require_relative 'randomizer'

class RandomizerWindow < Qt::Dialog
  OPTIONS = %i(
    randomize_pickups
    randomize_boss_souls
    randomize_portraits
    randomize_villagers
    randomize_enemies
    randomize_enemy_drops
    randomize_enemy_stats
    randomize_enemy_anim_speed
    randomize_enemy_tolerances
    randomize_equipment_stats
    randomize_consumable_behavior
    randomize_weapon_behavior
    randomize_skill_stats
    randomize_skill_behavior
    randomize_weapon_and_skill_elements
    randomize_shop
    randomize_wooden_chests
    randomize_weapon_synths
    randomize_red_walls
    randomize_rooms_map_friendly
    randomize_starting_room
    randomize_room_connections
    randomize_area_connections
    
    experimental_options_enabled
    randomize_players
    randomize_bosses
    randomize_enemy_ai
    randomize_skill_sprites
    randomize_enemy_sprites
    
    enable_glitch_reqs
    bonus_starting_items
    rebalance_enemies_in_room_rando
    
    scavenger_mode
    name_unnamed_skills
    unlock_all_modes
    reveal_breakable_walls
    reveal_bestiary
    remove_area_names
    revise_item_descriptions
    fix_luck
    no_touch_screen
    unlock_boss_doors
    remove_slot_machines
    add_magical_tickets
    always_start_with_rare_ring
    por_short_mode
    dont_randomize_change_cube
    por_nerf_enemy_resistances
    skip_emblem_drawing
    fix_infinite_quest_rewards
    always_show_drop_percentages
    open_world_map
    always_dowsing
    gain_extra_attribute_points
    summons_gain_extra_exp
    
    randomize_bgm
    randomize_dialogue
  )
  
  DIFFICULTY_OPTION_PRETTY_NAMES = {
    :item_stat_label                => "<b>Average Item Stats</b>",
    :item_price_range               => "Item Price",
    :weapon_attack_range            => "Weapon ATK",
    :weapon_iframes_range           => "Weapon IFrames",
    :armor_defense_range            => "Armor DEF",
    :item_extra_stats_range         => "Other stats",
    :restorative_amount_range       => "Restorative Amount",
    :heart_restorative_amount_range => "Heart Repair Amount",
    :ap_increase_amount_range       => "Attribute Point Boost Amount",
    
    :skill_stat_label               => "<b>Average Skill Stats</b>",
    :skill_price_range              => "Subweapon/Spell Price",
    :skill_dmg_range                => "Skill Damage",
    :crush_or_union_dmg_range       => "Dual Crush/Glyph Union Damage",
    :skill_iframes_range            => "Skill IFrames",
    :subweapon_sp_to_master_range   => "Subweapon SP To Master",
    :spell_charge_time_range        => "Spell Charge Time",
    :skill_mana_cost_range          => "Skill Mana Cost",
    :crush_mana_cost_range          => "Dual Crush Mana Cost",
    :union_heart_cost_range         => "Glyph Union Heart Cost",
    :skill_max_at_once_range        => "Skill Max-on-screen",
    :glyph_attack_delay_range       => "Glyph Attack Delay",
    
    :drop_chances_label             => "<b>Average Enemy Drop Chances</b>",
    :item_drop_chance_range         => "Item Drop Chance",
    :skill_drop_chance_range        => "Soul/Glyph Drop Chance",
    
    :pickup_placement_weight_label  => "<b>Proportions of Pickup Types</b>",
    :item_placement_weight          => "Item Placement Weight",
    :soul_candle_placement_weight   => "Soul Candle Placement Weight (DoS)",
    :por_skill_placement_weight     => "Skill Placement Weight (PoR)",
    :glyph_placement_weight         => "Glyph Placement Weight (OoE)",
    :max_up_placement_weight        => "Max Up Placement Weight",
    :money_placement_weight         => "Money Placement Weight",
    
    :enemy_difficulty_label         => "<b>Enemy Placement Difficulty</b>",
    :max_room_difficulty_mult       => "Max Room Total Attack Multiplier",
    :max_enemy_difficulty_mult      => "Max Enemy Attack Difference Multiplier",
    :enemy_id_preservation_exponent => "Enemy ID Number Difference Weighting",
    
    :enemy_stat_label               => "<b>Average Enemy Stats</b>",
    :enemy_stat_mult_range          => "Common Enemy Stat Multiplier",
    :enemy_num_weaknesses_range     => "Common Enemy # of Weaknesses",
    :enemy_num_resistances_range    => "Common Enemy # of Resistances",
    :boss_stat_mult_range           => "Boss Stat Multiplier",
    :enemy_anim_speed_mult_range    => "Enemy Anim Speed Multiplier",
    
    :starting_room_label            => "<b>Starting Room Difficulty</b>",
    :starting_room_max_difficulty   => "Max Average Attack of Starting Area",
  }
  
  slots "update_settings()"
  slots "browse_for_clean_rom()"
  slots "browse_for_output_folder()"
  slots "difficulty_level_changed(int)"
  slots "difficulty_slider_value_changed(int)"
  slots "difficulty_line_edit_value_changed()"
  slots "generate_seed()"
  slots "randomize()"
  slots "open_about()"
  slots "read_seed_info()"
  slots "experimental_enabled_changed(bool)"
  
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
      connect(@ui.send(option_name), SIGNAL("clicked(bool)"), self, SLOT("update_settings()"))
    end
    
    connect(@ui.experimental_options_enabled, SIGNAL("clicked(bool)"), self, SLOT("experimental_enabled_changed(bool)"))
    
    connect(@ui.randomize_button, SIGNAL("clicked()"), self, SLOT("randomize()"))
    connect(@ui.about_button, SIGNAL("clicked()"), self, SLOT("open_about()"))
    
    self.setWindowTitle("DSVania Randomizer #{DSVRANDOM_VERSION}")
    
    connect(@ui.difficulty_level, SIGNAL("activated(int)"), self, SLOT("difficulty_level_changed(int)"))
    
    update_settings()
    
    connect(@ui.read_seed_info_button, SIGNAL("clicked()"), self, SLOT("read_seed_info()"))
    
    self.resize(640, 1)
    
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
      
      Randomizer::DIFFICULTY_RANGES.keys.each do |option_name|
        slider = @slider_widgets_by_name[option_name]
        average = @settings[:difficulty_options][option_name]
        if average.nil?
          # If some options are missing default to what it is on easy.
          average = Randomizer::DIFFICULTY_LEVELS["Easy"][option_name]
        end
        slider.blockSignals(true)
        slider.value = average
        slider.blockSignals(false)
        
        line_edit = @difficulty_line_edit_widgets_by_name[option_name]
        line_edit.text = slider.true_value.to_s
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
    
    ensure_valid_combination_of_options()
    
    OPTIONS.each do |option_name|
      @settings[option_name] = @ui.send(option_name).checked
    end
    
    @settings[:difficulty_level] = @ui.difficulty_level.itemText(@ui.difficulty_level.currentIndex)
    @settings[:difficulty_options] = {}
    Randomizer::DIFFICULTY_RANGES.keys.each do |option_name|
      slider = @slider_widgets_by_name[option_name]
      average = slider.true_value
      @settings[:difficulty_options][option_name] = average
    end
    
    save_settings()
  end
  
  def ensure_valid_combination_of_options
    if !@ui.randomize_pickups.checked
      @ui.randomize_boss_souls.checked = false
      @ui.randomize_boss_souls.enabled = false
      @ui.randomize_villagers.checked = false
      @ui.randomize_villagers.enabled = false
      @ui.randomize_portraits.checked = false
      @ui.randomize_portraits.enabled = false
      @ui.randomize_red_walls.checked = false
      @ui.randomize_red_walls.enabled = false
      @ui.randomize_area_connections.checked = false
      @ui.randomize_area_connections.enabled = false
      @ui.randomize_room_connections.checked = false
      @ui.randomize_room_connections.enabled = false
      @ui.randomize_starting_room.checked = false
      @ui.randomize_starting_room.enabled = false
      @ui.randomize_rooms_map_friendly.checked = false
      @ui.randomize_rooms_map_friendly.enabled = false
    else
      @ui.randomize_boss_souls.enabled = true
      @ui.randomize_villagers.enabled = true
      @ui.randomize_portraits.enabled = true
      @ui.randomize_red_walls.enabled = true
      @ui.randomize_starting_room.enabled = true
    end
    
    if @ui.randomize_rooms_map_friendly.checked
      @ui.randomize_area_connections.checked = false
      @ui.randomize_area_connections.enabled = false
      @ui.randomize_room_connections.checked = false
      @ui.randomize_room_connections.enabled = false
    end
    
    if @ui.randomize_area_connections.checked || @ui.randomize_room_connections.checked
      @ui.randomize_rooms_map_friendly.checked = false
      @ui.randomize_rooms_map_friendly.enabled = false
    end
    
    if @ui.randomize_pickups.checked && !@ui.randomize_rooms_map_friendly.checked
      @ui.randomize_area_connections.enabled = true
      @ui.randomize_room_connections.enabled = true
      @ui.randomize_starting_room.enabled = true
    end
    
    if @ui.randomize_pickups.checked && !@ui.randomize_area_connections.checked && !@ui.randomize_room_connections.checked
      @ui.randomize_rooms_map_friendly.enabled = true
    end
    
    if !@ui.experimental_options_enabled.checked
      @ui.experimental_options_enabled.children.each do |child|
        if child.is_a?(Qt::CheckBox)
          child.checked = false
        end
      end
    end
  end
  
  def experimental_enabled_changed(enabled)
    if enabled
      msg = "Are you sure you want to enable the experimental section?\n\nThese options are mostly untested and are known to have bugs that can make seeds unwinnable."
      response = Qt::MessageBox.question(self, "Enable experimental options?", msg, Qt::MessageBox::No | Qt::MessageBox::Yes, Qt::MessageBox::No)
      
      if response == Qt::MessageBox::No
        @ui.experimental_options_enabled.checked = false
      end
    end
  end
  
  def initialize_difficulty_sliders
    # Remove the grey background color of the scroll area.
    @ui.scrollArea.setStyleSheet("QScrollArea {background-color:transparent;}");
    @ui.scrollAreaWidgetContents.setStyleSheet("background-color:transparent;");
    
    form_layout = @ui.scrollAreaWidgetContents.layout
    @slider_widgets_by_name = {}
    @difficulty_line_edit_widgets_by_name = {}
    
    DIFFICULTY_OPTION_PRETTY_NAMES.each_with_index do |(option_name, pretty_name), i|
      label = Qt::Label.new(@ui.scrollAreaWidgetContents)
      label.text = pretty_name
      form_layout.setWidget(i, Qt::FormLayout::LabelRole, label)
      
      option_value_range = Randomizer::DIFFICULTY_RANGES[option_name]
      if option_value_range.nil?
        # Not a real option, just descriptive text.
        next
      end
      
      horizontal_layout = Qt::HBoxLayout.new
      form_layout.setLayout(i, Qt::FormLayout::FieldRole, horizontal_layout)
      
      slider = FloatSlider.new(@ui.scrollAreaWidgetContents)
      slider.minimum = option_value_range.begin
      slider.maximum = option_value_range.end
      
      slider.pageStep = ((option_value_range.end - option_value_range.begin) / 100.0).ceil * 100
      slider.orientation = Qt::Horizontal
      connect(slider, SIGNAL("valueChanged(int)"), self, SLOT("difficulty_slider_value_changed(int)"))
      horizontal_layout.addWidget(slider)
      @slider_widgets_by_name[option_name] = slider
      slider.objectName = "#{option_name}_slider"
      
      line_edit = Qt::LineEdit.new
      line_edit.setMaximumSize(60, 16777215)
      connect(line_edit, SIGNAL("editingFinished()"), self, SLOT("difficulty_line_edit_value_changed()"))
      horizontal_layout.addWidget(line_edit)
      @difficulty_line_edit_widgets_by_name[option_name] = line_edit
      line_edit.objectName = "#{option_name}_line_edit"
    end
    
    @ui.difficulty_level.addItem("Custom")
    Randomizer::DIFFICULTY_LEVELS.keys.each do |name|
      @ui.difficulty_level.addItem(name)
    end
  end
  
  def difficulty_slider_value_changed(value)
    # Update text in the corresponding line edit.
    slider = sender()
    match = slider.objectName.match(/^(.+)_slider$/)
    if match
      option_name = match[1].to_sym
      line_edit = @difficulty_line_edit_widgets_by_name[option_name]
      line_edit.text = slider.true_value.to_s
      
      @ui.difficulty_level.setCurrentIndex(0)
      
      update_settings()
    end
  end
  
  def difficulty_line_edit_value_changed
    # Update text in the corresponding line edit.
    line_edit = sender()
    match = line_edit.objectName.match(/^(.+)_line_edit$/)
    if match
      new_value = line_edit.text.to_f
      
      option_name = match[1].to_sym
      slider = @slider_widgets_by_name[option_name]
      slider.blockSignals(true)
      slider.value = new_value
      slider.blockSignals(false)
      
      # Also update the text in the line edit after the slider has clamped the value in case it was too big or too small.
      line_edit.text = slider.true_value.to_s
      
      @ui.difficulty_level.setCurrentIndex(0)
      
      update_settings()
    end
  end
  
  def difficulty_level_changed(diff_index)
    @ui.difficulty_level.setCurrentIndex(diff_index)
    
    difficulty_name = @ui.difficulty_level.itemText(diff_index)
    
    difficulty_level_options = Randomizer::DIFFICULTY_LEVELS[difficulty_name]
    if difficulty_level_options
      form_layout = @ui.scrollAreaWidgetContents.layout
      
      difficulty_level_options.each do |option_name, average|
        slider = @slider_widgets_by_name[option_name]
        slider.blockSignals(true)
        slider.value = average
        slider.blockSignals(false)
        
        line_edit = @difficulty_line_edit_widgets_by_name[option_name]
        line_edit.text = slider.true_value.to_s
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
    
    @settings["last_used_#{GAME}_clean_rom_path".to_sym] = @ui.clean_rom.text
    
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
    Randomizer::DIFFICULTY_RANGES.keys.each do |option_name|
      slider = @slider_widgets_by_name[option_name]
      average = slider.true_value
      difficulty_settings_averages[option_name] = average
    end
    
    begin
      randomizer = Randomizer.new(seed, game, options_hash, @settings[:difficulty_level], difficulty_settings_averages)
    rescue StandardError => e
      Qt::MessageBox.critical(self, "Randomization Failed", "Randomization failed with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
      return
    end
    
    max_val = options_hash.select{|k,v| k.to_s.start_with?("randomize_") && v}.length
    max_val += 20 if options_hash[:randomize_pickups]
    max_val += 7 if options_hash[:randomize_enemies]
    max_val += 75 if options_hash[:randomize_rooms_map_friendly]
    max_val += 2 # Initialization
    max_val += 1 # Applying tweaks and finishing up
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
          if @progress_dialog
            @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
            @progress_dialog.reset()
            @progress_dialog = nil
          end
          
          Qt::MessageBox.critical(self, "Randomization Failed", "Randomization failed with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
        end
        return
      end
      
      Qt.execute_in_main_thread do
        if @progress_dialog
          @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
          @progress_dialog.reset()
          @progress_dialog = nil
        end
        
        write_to_rom(game, randomizer)
      end
    end
  rescue NDSFileSystem::InvalidFileError, Game::InvalidFileError => e
    Qt::MessageBox.warning(self, "Unrecognized game", "Specified ROM is not recognized.\nOnly the US versions are supported.")
    return
  end
  
  def write_to_rom(game, randomizer)
    FileUtils.mkdir_p(@ui.output_folder.text)
    game_with_caps = GAME.dup
    game_with_caps[0] = game_with_caps[0].upcase
    game_with_caps[2] = game_with_caps[2].upcase
    output_rom_filename = "#{game_with_caps} #{@sanitized_seed}.nds"
    output_rom_path = File.join(@ui.output_folder.text, output_rom_filename)
    
    max_val = game.fs.files_without_dirs.length
    @progress_dialog = ProgressDialog.new("Building", "Writing files to ROM", max_val)
    @progress_dialog.execute do
      begin
        game.fs.write_to_rom(output_rom_path) do |files_written|
          next unless files_written % 100 == 0 # Only update the UI every 100 files because updating too often is slow.
          break if @progress_dialog.nil?
          
          Qt.execute_in_main_thread do
            if @progress_dialog && !@progress_dialog.wasCanceled
              @progress_dialog.setValue(files_written)
            end
          end
        end
      rescue StandardError => e
        Qt.execute_in_main_thread do
          if @progress_dialog
            @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
            @progress_dialog.close()
            @progress_dialog = nil
          end
          
          Qt::MessageBox.critical(self, "Building ROM failed", "Failed to build ROM with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
        end
        return
      end
      
      Qt.execute_in_main_thread do
        if @progress_dialog
          @progress_dialog.setValue(max_val) unless @progress_dialog.wasCanceled
          @progress_dialog.reset()
          @progress_dialog = nil
        end
        
        msg = "Randomization complete.\n\n"
        msg << "Output ROM:\n#{output_rom_filename}\n\n"
        msg << "If you get stuck, check the FAQ in the readme,\nand the progression spoiler log here: /logs/spoiler_log.txt"
        msg << "\n\nNote that you have an infinitely usable magical ticket in your inventory, so if you get trapped in a pit use that to return to your starting room." if randomizer.needs_infinite_magical_tickets?
        
        Qt::MessageBox.information(self, "Done", msg)
      end
    end
  end
  
  def open_about
    @about_dialog = Qt::MessageBox.new
    @about_dialog.setTextFormat(Qt::RichText)
    @about_dialog.setWindowTitle("DSVania Randomizer")
    text = "DSVania Randomizer Version #{DSVRANDOM_VERSION}<br><br>" + 
      "Created by LagoLunatic<br><br>" + 
      "Report issues here:<br><a href=\"https://github.com/LagoLunatic/dsvrandom/issues\">https://github.com/LagoLunatic/dsvrandom/issues</a><br><br>" +
      "Source code:<br><a href=\"https://github.com/LagoLunatic/dsvrandom\">https://github.com/LagoLunatic/dsvrandom</a>"
    @about_dialog.setText(text)
    @about_dialog.windowIcon = self.windowIcon
    @about_dialog.show()
  end
  
  def read_seed_info
    input_seed_info(@ui.paste_seed_info_field.plainText)
  end
  
  def input_seed_info(text)
    if text.nil? || text.strip == ""
      raise "No seed info input."
    end
    
    match = text.match(/Seed: ([a-zA-Z0-9\-_']+), Game: ([^,]+), Randomizer version: (.+)\s+Selected options: (.+)\s+Difficulty level: (.+)/)
    if match.nil?
      raise "Seed info is not in the proper format."
    end
    
    seed = $1
    game = $2
    version = $3
    options = $4.split(", ").map(&:to_sym)
    difficulty = $5
    
    if version != DSVRANDOM_VERSION
      raise "Wrong version! This is #{DSVRANDOM_VERSION}, need #{version}"
    end
    
    short_game_name = case game
    when "Dawn of Sorrow"
      "dos"
    when "Portrait of Ruin"
      "por"
    when "Order of Ecclesia"
      "ooe"
    else
      raise "Invalid game name: #{game}"
    end
    last_used_rom_path_for_this_game = @settings["last_used_#{short_game_name}_clean_rom_path".to_sym]
    if last_used_rom_path_for_this_game
      @ui.clean_rom.text = last_used_rom_path_for_this_game
      successfully_changed_clean_rom_path = true
    else
      @ui.clean_rom.text = ""
      successfully_changed_clean_rom_path = false
    end
    
    @ui.seed.text = seed
    options.each do |option_name|
      @ui.send(option_name).checked = true
    end
    (OPTIONS-options).each do |option_name|
      @ui.send(option_name).checked = false
    end
    
    difficulty_level_options = Randomizer::DIFFICULTY_LEVELS[difficulty]
    if difficulty_level_options
      # Preset difficulty level.
      @ui.difficulty_level.count.times do |i|
        if @ui.difficulty_level.itemText(i) == difficulty
          difficulty_level_changed(i)
          break
        end
      end
    elsif difficulty =~ /Custom/
      # Custom difficulty.
      difficulty_level_changed(0)
      
      custom_difficulty_options = {}
      on_difficulty_options = false
      text.each_line do |line|
        line = line.strip
        if line == "Difficulty level: Custom, settings:"
          on_difficulty_options = true
        elsif on_difficulty_options && line =~ /([^\s:]+): (.+)/
          name = $1.to_sym
          val = $2
          if val.include?(".")
            val = val.to_f
          else
            val = val.to_i
          end
          custom_difficulty_options[name] = val
        elsif on_difficulty_options
          break
        end
      end
      
      form_layout = @ui.scrollAreaWidgetContents.layout
      
      Randomizer::DIFFICULTY_RANGES.keys.each do |option_name|
        slider = @slider_widgets_by_name[option_name]
        average = custom_difficulty_options[option_name]
        if average.nil?
          # If some options are missing default to what it is on easy.
          average = Randomizer::DIFFICULTY_LEVELS["Easy"][option_name]
        end
        slider.blockSignals(true)
        slider.value = average
        slider.blockSignals(false)
        
        line_edit = @difficulty_line_edit_widgets_by_name[option_name]
        line_edit.text = slider.true_value.to_s
      end
    else
      raise "No difficulty found"
    end
    
    @ui.tabWidget.currentIndex = 0
    
    msg = "Successfully read seed info."
    unless successfully_changed_clean_rom_path
      msg << "\n\nPlease manually change the Clean ROM field to point to a clean #{game} ROM."
    end
    Qt::MessageBox.information(self, "Read seed info", msg)
  rescue StandardError => e
    Qt::MessageBox.warning(self, "Seed info input failed", e.message)
  end
end

class ProgressDialog < Qt::ProgressDialog
  slots "cancel_thread()"
  
  def initialize(title, description, max_val)
    super()
    self.windowTitle = title
    self.labelText = description
    self.maximum = max_val
    self.windowModality = Qt::ApplicationModal
    self.windowFlags = Qt::CustomizeWindowHint | Qt::WindowTitleHint
    self.setFixedSize(self.size);
    self.autoReset = false
    connect(self, SIGNAL("canceled()"), self, SLOT("cancel_thread()"))
    self.show
  end
  
  def execute(&block)
    @thread = Thread.new do
      yield
    end
  end
  
  def cancel_thread
    @thread.kill
    self.close()
  end
end

class FloatSlider < Qt::Slider
  def minimum=(min)
    super(min*100)
  end
  
  def maximum=(max)
    super(max*100)
  end
  
  def value=(val)
    # Very large ints can cause a crash here, so we need to manually clamp the user-entered value before letting the Qt code clamp it to prevent this.
    val = val*100
    if val > maximum
      val = maximum
    end
    if val < minimum
      val = minimum
    end
    super(val)
  end
  
  def true_value
    value/100.0
  end
end
