
require_relative 'ui_randomizer'
require_relative 'constants/options'
require_relative 'randomizer'
require_relative 'update_checker'

class RandomizerWindow < Qt::Dialog
  VALID_SEED_CHARACTERS = "a-zA-Z0-9\\-_'%"
  
  slots "update_settings()"
  slots "browse_for_clean_rom()"
  slots "browse_for_output_folder()"
  slots "difficulty_level_changed(int)"
  slots "difficulty_slider_value_changed(int)"
  slots "difficulty_line_edit_value_changed()"
  slots "generate_seed()"
  slots "randomize_n_seeds()"
  slots "open_about()"
  slots "reset_settings_to_default()"
  slots "save_options_preset_to_file()"
  slots "load_options_preset_from_file()"
  slots "load_seed_info_from_file()"
  slots "paste_seed_info_from_clipboard()"
  slots "experimental_enabled_changed(bool)"
  
  def initialize
    super(nil, Qt::WindowMinimizeButtonHint)
    @ui = Ui_Randomizer.new
    @ui.setup_ui(self)
    
    # Add three empty items to the clean ROM recent files dropdown, one for each game.
    @ui.clean_rom.addItem("")
    @ui.clean_rom.addItem("")
    @ui.clean_rom.addItem("")
    
    @currently_selected_game = nil
    
    initialize_difficulty_sliders()
    
    preserve_default_settings()
    
    load_settings()
    
    connect(@ui.clean_rom, SIGNAL("activated(int)"), self, SLOT("update_settings()"))
    connect(@ui.clean_rom, SIGNAL("editTextChanged(QString)"), self, SLOT("update_settings()"))
    connect(@ui.clean_rom_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_clean_rom()"))
    connect(@ui.output_folder, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    connect(@ui.output_folder_browse_button, SIGNAL("clicked()"), self, SLOT("browse_for_output_folder()"))
    connect(@ui.generate_seed_button, SIGNAL("clicked()"), self, SLOT("generate_seed()"))
    connect(@ui.seed, SIGNAL("editingFinished()"), self, SLOT("update_settings()"))
    
    OPTIONS.each_key do |option_name|
      connect(@ui.send(option_name), SIGNAL("clicked(bool)"), self, SLOT("update_settings()"))
      
      @ui.send(option_name).installEventFilter(self)
    end
    
    connect(@ui.experimental_options_enabled, SIGNAL("clicked(bool)"), self, SLOT("experimental_enabled_changed(bool)"))
    
    connect(@ui.randomize_button, SIGNAL("clicked()"), self, SLOT("randomize_n_seeds()"))
    connect(@ui.about_button, SIGNAL("clicked()"), self, SLOT("open_about()"))
    connect(@ui.reset_settings_to_default, SIGNAL("clicked()"), self, SLOT("reset_settings_to_default()"))
    
    self.setWindowTitle("DSVania Randomizer #{DSVRANDOM_VERSION}")
    
    connect(@ui.difficulty_level, SIGNAL("activated(int)"), self, SLOT("difficulty_level_changed(int)"))
    
    connect(@ui.num_seeds_to_create, SIGNAL("activated(int)"), self, SLOT("update_settings()"))
    
    update_settings()
    
    connect(@ui.save_options_preset_button, SIGNAL("clicked()"), self, SLOT("save_options_preset_to_file()"))
    connect(@ui.load_options_preset_button, SIGNAL("clicked()"), self, SLOT("load_options_preset_from_file()"))
    connect(@ui.load_seed_info_button, SIGNAL("clicked()"), self, SLOT("load_seed_info_from_file()"))
    connect(@ui.paste_seed_info_button, SIGNAL("clicked()"), self, SLOT("paste_seed_info_from_clipboard()"))
    
    self.resize(self.width, 1)
    
    self.show()
  end
  
  def bulk_test
    failed_times = 0
    total_tests = 100
    total_tests.times do |i|
      game = Game.new
      game.initialize_from_rom(@ui.clean_rom.currentText, extract_to_hard_drive = false)
      seed = i.to_s
      
      options_hash = get_current_options_hash()
      
      difficulty_settings_averages = get_current_difficulty_settings_averages()
      
      randomizer = Randomizer.new(seed, game, options_hash, @settings[:difficulty_level], difficulty_settings_averages)
      begin
        randomizer.randomize() {}
      rescue StandardError => e
        puts "Error on seed #{seed}:"
        puts e.message
        failed_times += 1
      end
      puts "%d/%d seeds failed" % [failed_times, i+1]
    end
  end
  
  def eventFilter(target, event)
    if event.type() == Qt::Event::Enter
      option_description = OPTIONS[target.objectName.to_sym]
      @ui.option_description.text = option_description
      return true
    elsif event.type() == Qt::Event::Leave
      @ui.option_description.text = ""
      return true
    end
    
    super(target, event)
  end
  
  def load_settings
    @settings_path = "randomizer_settings.yml"
    if File.file?(@settings_path)
      @settings = YAML::load_file(@settings_path)
    else
      @settings = {}
    end
    
    update_last_used_clean_rom_combobox_items()
    
    set_clean_rom_combobox_text(@settings[:clean_rom_path]) if @settings[:clean_rom_path]
    @ui.output_folder.setText(@settings[:output_folder]) if @settings[:output_folder]
    @ui.seed.setText(@settings[:seed]) if @settings[:seed]
    
    # Detects what the selected game is so we know what options to disable.
    detect_current_game_by_clean_rom_combobox_text()
    
    OPTIONS.each_key do |option_name|
      @ui.send(option_name).setChecked(@settings[option_name]) unless @settings[option_name].nil?
    end
    
    num_seeds_index = @ui.num_seeds_to_create.findText(@settings[:num_seeds_to_create].to_s)
    if num_seeds_index != -1
      @ui.num_seeds_to_create.setCurrentIndex(num_seeds_index)
    end
    
    if @settings[:difficulty_level].nil?
      @settings[:difficulty_level] = "Normal"
    end
    difficulty_level_options = DIFFICULTY_LEVELS[@settings[:difficulty_level]]
    if difficulty_level_options
      # Preset difficulty level.
      difficulty_level_changed_by_name(@settings[:difficulty_level])
    else
      # Custom difficulty.
      
      form_layout = @ui.scrollAreaWidgetContents.layout
      
      DIFFICULTY_RANGES.keys.each do |option_name|
        slider = @slider_widgets_by_name[option_name]
        average = @settings[:difficulty_options][option_name]
        if average.nil?
          # If some options are missing default to what it is on easy.
          average = DIFFICULTY_LEVELS.values.first[option_name]
        end
        slider.blockSignals(true)
        slider.value = average
        slider.blockSignals(false)
        
        line_edit = @difficulty_line_edit_widgets_by_name[option_name]
        line_edit.text = slider.true_value.to_s
      end
      
      difficulty_level_changed_by_name("Custom")
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
    
    set_clean_rom_combobox_text(clean_rom_path)
    
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
    if @ui.clean_rom.currentText != @settings[:clean_rom_path]
      # Clean ROM text changed, so update the record of what the last used ROM path is, if it's a valid DSVania ROM file.
      detect_current_game_by_clean_rom_combobox_text()
    end
    
    @settings[:clean_rom_path] = @ui.clean_rom.currentText
    @settings[:output_folder] = @ui.output_folder.text
    @settings[:seed] = @ui.seed.text
    
    ensure_valid_combination_of_options()
    
    OPTIONS.each_key do |option_name|
      @settings[option_name] = @ui.send(option_name).checked
    end
    
    @settings[:difficulty_level] = @ui.difficulty_level.itemText(@ui.difficulty_level.currentIndex)
    @settings[:difficulty_options] = {}
    DIFFICULTY_RANGES.keys.each do |option_name|
      slider = @slider_widgets_by_name[option_name]
      average = slider.true_value
      @settings[:difficulty_options][option_name] = average
    end
    
    @settings[:num_seeds_to_create] = @ui.num_seeds_to_create.itemText(@ui.num_seeds_to_create.currentIndex)
    
    save_settings()
  end
  
  def ensure_valid_combination_of_options
    should_enable_options = {}
    OPTIONS.each_key do |option_name|
      should_enable_options[option_name] = true
    end
    
    if !@ui.experimental_options_enabled.checked
      @ui.experimental_options_enabled.children.each do |child|
        if child.is_a?(Qt::CheckBox)
          should_enable_options[child.object_name.to_sym] &&= false
        end
      end
    end
    
    pickup_randomizer_dependant_options = [
      :randomize_boss_souls,
      :randomize_villagers,
      :randomize_portraits,
      :randomize_red_walls,
      :randomize_starting_room,
      :randomize_maps,
      :randomize_world_map_exits,
      :por_short_mode,
    ]
    if !@ui.randomize_pickups.checked
      pickup_randomizer_dependant_options.each do |option_name|
        should_enable_options[option_name] &&= false
      end
    end
    
    room_rando = @ui.randomize_maps.checked || @ui.randomize_starting_room.checked || @ui.randomize_world_map_exits.checked
    #room_rando ||= @ui.randomize_room_connections.checked || @ui.randomize_area_connections.checked
    
    if !room_rando
      should_enable_options[:rebalance_enemies_in_room_rando] &&= false
    end
    
    if @ui.open_world_map.checked
      should_enable_options[:randomize_world_map_exits] &&= false
    end
    
    OPTIONS.each_key do |option_name|
      if should_enable_options[option_name]
        @ui.send(option_name).enabled = true
      else
        @ui.send(option_name).enabled = false
      end
    end
    
    if @ui.randomize_maps.checked
      @ui.randomize_boss_souls.checked = true
      @ui.randomize_boss_souls.enabled = false
    end
    
    if @ui.randomize_world_map_exits.checked && @ui.randomize_world_map_exits.enabled
      @ui.randomize_starting_room.checked = false
      @ui.randomize_starting_room.enabled = false
    end
    
    disable_options_not_for_current_game()
    
    if @ui.num_seeds_to_create.currentIndex == 0 # 1 seed
      @ui.seed.enabled = true
    else
      # The seed text input is not used when generating multiple seeds.
      @ui.seed.enabled = false
    end
  end
  
  def disable_options_not_for_current_game
    all_game_specific_options = []
    GAME_SPECIFIC_OPTIONS.each do |game, options_for_game|
      all_game_specific_options += options_for_game
    end
    all_game_specific_options.uniq!
    
    all_game_specific_options.each do |option_name|
      if !@ui.send(option_name).enabled
        # This option was already disabled by ensure_valid_combination_of_options, so don't enable it regardless of the game it's for.
        next
      end
      
      if @currently_selected_game.nil?
        # If no game is selected, enable all options.
        @ui.send(option_name).enabled = true
      elsif GAME_SPECIFIC_OPTIONS[@currently_selected_game].include?(option_name)
        # Enable all options for the selected game.
        @ui.send(option_name).enabled = true
      else
        # Disable all options specific to the other games that the selected game does not also support.
        @ui.send(option_name).enabled = false
      end
    end
  end
  
  def experimental_enabled_changed(enabled)
    if enabled
      msg = "Are you sure you want to enable the experimental section?\n\nThese options are mostly untested and are known to have bugs that can cause crashes or make seeds unwinnable."
      response = Qt::MessageBox.question(self, "Enable experimental options?", msg, Qt::MessageBox::No | Qt::MessageBox::Yes, Qt::MessageBox::No)
      
      if response == Qt::MessageBox::No
        @ui.experimental_options_enabled.checked = false
      end
    end
  end
  
  def update_last_used_clean_rom_combobox_items
    [
      :last_used_dos_clean_rom_path,
      :last_used_por_clean_rom_path,
      :last_used_ooe_clean_rom_path,
    ].each_with_index do |last_used_path_key, i|
      if @settings[last_used_path_key] && File.file?(@settings[last_used_path_key])
        @ui.clean_rom.setItemText(i, @settings[last_used_path_key])
      else
        @settings[last_used_path_key] = nil
        @ui.clean_rom.setItemText(i, "")
      end
    end
  end
  
  def detect_current_game_by_clean_rom_combobox_text
    @currently_selected_game = nil
    
    clean_rom_path = @ui.clean_rom.currentText
    if File.file?(clean_rom_path)
      title = File.read(clean_rom_path, 16)
      case title
      when "CASTLEVANIA1ACVE"
        @currently_selected_game = "dos"
        @settings[:last_used_dos_clean_rom_path] = clean_rom_path
        update_last_used_clean_rom_combobox_items()
      when "CASTLEVANIA2ACBE"
        @currently_selected_game = "por"
        @settings[:last_used_por_clean_rom_path] = clean_rom_path
        update_last_used_clean_rom_combobox_items()
      when "CASTLEVANIA3YR9E"
        @currently_selected_game = "ooe"
        @settings[:last_used_ooe_clean_rom_path] = clean_rom_path
        update_last_used_clean_rom_combobox_items()
      end
    end
  end
  
  def set_clean_rom_combobox_text(text)
    # If this text is one of the items in the dropdown, set that item as the selected one.
    # Otherwise just set the text itself.
    index = @ui.clean_rom.findText(text)
    if index == -1
      @ui.clean_rom.setEditText(text)
    else
      @ui.clean_rom.setCurrentIndex(index)
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
      
      option_value_range = DIFFICULTY_RANGES[option_name]
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
    DIFFICULTY_LEVELS.keys.each do |name|
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
  
  def difficulty_level_changed_by_name(diff_name)
    @ui.difficulty_level.count.times do |i|
      if @ui.difficulty_level.itemText(i) == diff_name
        difficulty_level_changed(i)
        break
      end
    end
  end
  
  def difficulty_level_changed(diff_index)
    @ui.difficulty_level.setCurrentIndex(diff_index)
    
    difficulty_name = @ui.difficulty_level.itemText(diff_index)
    
    difficulty_level_options = DIFFICULTY_LEVELS[difficulty_name]
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
  
  def get_current_options_hash
    options_hash = {}
    
    OPTIONS.each_key do |option_name|
      # Options that are disabled don't count as being checked, even though they visually remain checked when disabled.
      options_hash[option_name] = @ui.send(option_name).checked && @ui.send(option_name).enabled
    end
    
    return options_hash
  end
  
  def get_current_difficulty_settings_averages
    difficulty_settings_averages = {}
    
    DIFFICULTY_RANGES.keys.each do |option_name|
      slider = @slider_widgets_by_name[option_name]
      average = slider.true_value
      difficulty_settings_averages[option_name] = average
    end
    
    return difficulty_settings_averages
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
  
  def randomize_n_seeds
    num_seeds_to_create = @settings[:num_seeds_to_create]
    num_seeds_to_create = num_seeds_to_create.to_i
    num_seeds_to_create = 1 if num_seeds_to_create < 1
    @remaining_seeds_to_create = num_seeds_to_create
    @output_filenames_written_so_far = []
    generate_seed() if num_seeds_to_create > 1
    randomize()
  end
  
  def load_game_and_verify_supported
    unless File.file?(@ui.clean_rom.currentText)
      Qt::MessageBox.warning(self, "No ROM specified", "Must specify clean ROM path.")
      return nil
    end
    unless File.directory?(@ui.output_folder.text)
      Qt::MessageBox.warning(self, "No output folder specified", "Must specify a valid output folder for the randomized ROM.")
      return nil
    end
    
    game = Game.new
    game.initialize_from_rom(@ui.clean_rom.currentText, extract_to_hard_drive = false)
    
    if !["dos", "por", "ooe"].include?(GAME)
      Qt::MessageBox.warning(self, "Unsupported game", "ROM is not a supported game.")
      return nil
    end
    if REGION != :usa
      Qt::MessageBox.warning(self, "Unsupported region", "Only the US versions are supported.")
      return nil
    end
    
    return game
  end
  
  def randomize
    game = load_game_and_verify_supported()
    return if game.nil?
    
    seed = @settings[:seed].to_s.strip.gsub(/\s/, "")
    
    if seed.empty?
      generate_seed()
      seed = @settings[:seed]
    end
    
    if seed =~ /[^#{VALID_SEED_CHARACTERS}]/
      Qt::MessageBox.critical(self, "Invalid seed", "Invalid seed. Seed can only have letters, numbers, dashes, underscores, and apostrophes in it.")
      return
    end
    
    @settings[:seed] = seed
    @ui.seed.text = @settings[:seed]
    save_settings()
    
    @sanitized_seed = seed
    
    options_hash = get_current_options_hash()
    
    difficulty_settings_averages = get_current_difficulty_settings_averages()
    
    begin
      randomizer = Randomizer.new(seed, game, options_hash, @settings[:difficulty_level], difficulty_settings_averages)
    rescue StandardError => e
      Qt::MessageBox.critical(self, "Randomization Failed", "Randomization failed with error:\n#{e.message}\n\n#{e.backtrace.join("\n")}")
      return
    end
    
    max_val = options_hash.select{|k,v| k.to_s.start_with?("randomize_") && v}.length
    max_val += 20 if options_hash[:randomize_pickups]
    max_val += 7 if options_hash[:randomize_enemies]
    max_val += 75 if options_hash[:randomize_maps]
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
          
          write_logs(randomizer, is_error: true)
          
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
          
          write_logs(randomizer, is_error: true)
          
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
        
        write_logs(randomizer)
        
        @remaining_seeds_to_create -= 1
        @output_filenames_written_so_far << output_rom_filename
        if @remaining_seeds_to_create > 0
          generate_seed()
          randomize()
        else
          msg = "Randomization complete.\n\n"
          if @output_filenames_written_so_far.length == 1
            msg << "Output ROM:\n#{output_rom_filename}\n\n"
          else
            msg << "Output ROMs:\n#{@output_filenames_written_so_far.join(", ")}\n\n"
          end
          msg << "If you get stuck, check the FAQ in the readme,\nand the progression spoiler log in the output folder."
          msg << "\n\nNote that you have an infinitely usable magical ticket in your inventory, so if you get trapped in a pit use that to return to your starting room." if randomizer.needs_infinite_magical_tickets?
          
          Qt::MessageBox.information(self, "Done", msg)
        end
      end
    end
  end
  
  def write_logs(randomizer, is_error: false)
    if is_error
      logs = [randomizer.spoiler_log]
    else
      logs = [randomizer.spoiler_log, randomizer.non_spoiler_log]
    end
    logs.compact!
    
    logs.each do |log|
      log.seek(0)
      spoiler_str = log.read()
      
      game_with_caps = GAME.dup
      game_with_caps[0] = game_with_caps[0].upcase
      game_with_caps[2] = game_with_caps[2].upcase
      if is_error
        output_log_filename = "#{game_with_caps} #{@sanitized_seed} - Error Log.txt"
      elsif log == randomizer.non_spoiler_log
        output_log_filename = "#{game_with_caps} #{@sanitized_seed} - Non-Spoiler Log.txt"
      else
        output_log_filename = "#{game_with_caps} #{@sanitized_seed} - Spoiler Log.txt"
      end
      output_log_path = File.join(@ui.output_folder.text, output_log_filename)
      
      File.open(output_log_path, "w") do |f|
        f.write(spoiler_str)
      end
    end
  end
  
  def open_about
    @about_dialog = Qt::MessageBox.new
    @about_dialog.setTextFormat(Qt::RichText)
    @about_dialog.setWindowTitle("DSVania Randomizer")
    base_text = "DSVania Randomizer Version #{DSVRANDOM_VERSION}<br><br>" + 
      "Created by LagoLunatic<br><br>" + 
      "Report issues here:<br><a href=\"https://github.com/LagoLunatic/dsvrandom/issues\">https://github.com/LagoLunatic/dsvrandom/issues</a><br><br>" +
      "Source code:<br><a href=\"https://github.com/LagoLunatic/dsvrandom\">https://github.com/LagoLunatic/dsvrandom</a><br><br>"
    text = base_text + "Checking for updates..."
    @about_dialog.setText(text)
    @about_dialog.windowIcon = self.windowIcon
    @about_dialog.show()
    
    
    new_version = check_for_updates()
    if new_version.nil?
      update_text = "No new updates to the randomizer are available."
    elsif new_version == :error
      update_text = "There was an error checking for updates."
    else
      update_text = "<b>Version %s of the randomizer is available!</b><br>" % new_version
      update_text += "<a href=\"%s\">Click here</a> to go to the download page." % LATEST_RELEASE_DOWNLOAD_PAGE_URL
    end
    text = base_text + update_text
    @about_dialog.setText(text)
  end
  
  def preserve_default_settings
    @default_settings = {}
    OPTIONS.each_key do |option_name|
      @default_settings[option_name] = @ui.send(option_name).checked
    end
    
    @default_difficulty_level = "Normal"
  end
  
  def reset_settings_to_default
    any_setting_changed = false
    OPTIONS.each_key do |option_name|
      if @default_settings.key?(option_name)
        default_value = @default_settings[option_name]
        current_value = @ui.send(option_name).checked
        if default_value != current_value
          any_setting_changed = true
        end
        @ui.send(option_name).checked = default_value
      end
    end
    
    if @ui.difficulty_level.currentText != @default_difficulty_level
      difficulty_level_changed_by_name(@default_difficulty_level)
      any_setting_changed = true
    end
    
    if any_setting_changed
      update_settings()
    else
      Qt::MessageBox.information(self,
        "Settings already default",
        "You already have all the default randomization settings."
      )
    end
  end

  def keyPressEvent(event)
    if event.key() == Qt::Key_Return
      self.randomize_n_seeds()
    else
      super(event)
    end
  end
  
  def save_options_preset_to_file
    if @settings[:options_presets_folder] && File.directory?(@settings[:options_presets_folder])
      default_dir = @settings[:options_presets_folder]
    else
      FileUtils.mkdir_p("./DSVRandom Presets")
      default_dir = "./DSVRandom Presets"
    end
    
    preset_path, selected_filter = Qt::FileDialog.getSaveFileName(self, "Save options preset", default_dir, "DSVRandom Preset Files (*.dsvrpreset)")
    return if preset_path.nil?
    
    text = create_options_preset_from_current_settings()
    return if text.nil?
    
    File.open(preset_path, "wb") do |f|
      f.write(text)
    end
    
    basename = File.basename(preset_path)
    dirname = File.dirname(preset_path)
    
    @settings[:options_presets_folder] = dirname
    
    Qt::MessageBox.information(self, "Saved options preset", "Successfully saved options preset \"%s\"." % basename)
  end
  
  def load_options_preset_from_file
    if @settings[:options_presets_folder] && File.directory?(@settings[:options_presets_folder])
      default_dir = @settings[:options_presets_folder]
    end
    
    preset_path = Qt::FileDialog.getOpenFileName(self, "Select options preset", default_dir, "DSVRandom Preset Files (*.dsvrpreset)")
    return if preset_path.nil?
    
    text = File.read(preset_path)
    read_seed_info(text, is_preset=true)
    
    dirname = File.dirname(preset_path)
    
    @settings[:options_presets_folder] = dirname
  end
  
  def load_seed_info_from_file
    if @settings[:output_folder] && File.directory?(@settings[:output_folder])
      default_dir = @settings[:output_folder]
    end
    
    log_path = Qt::FileDialog.getOpenFileName(self, "Select spoiler/non-spoiler log", default_dir, "Text files (*.txt)")
    return if log_path.nil?
    
    text = File.read(log_path)
    read_seed_info(text)
  end
  
  def paste_seed_info_from_clipboard
    text = $qApp.clipboard.text()
    read_seed_info(text)
  end
  
  def create_options_preset_from_current_settings
    text = StringIO.new
    
    game = load_game_and_verify_supported
    return nil if game.nil?
    
    options = get_current_options_hash()
    difficulty_level = @settings[:difficulty_level]
    user_given_difficulty_settings = get_current_difficulty_settings_averages()
    
    options_string = options.select{|k,v| v == true}.keys.join(", ")
    if DIFFICULTY_LEVELS.keys.include?(difficulty_level)
      difficulty_settings_string = difficulty_level
    else
      difficulty_settings_string = "Custom, settings:\n  " + user_given_difficulty_settings.map{|k,v| "#{k}: #{v}"}.join("\n  ")
    end
    
    text.puts "DSVRandom Options Preset, Game: #{LONG_GAME_NAME}, Randomizer version: #{DSVRANDOM_VERSION}"
    text.puts "Selected options: #{options_string}"
    text.puts "Difficulty level: #{difficulty_settings_string}"
    
    return text.string
  end
  
  def read_seed_info(text, is_preset=false)
    if is_preset
      format_type = "options preset"
    else
      format_type = "seed info"
    end
    
    if text.nil? || text.strip == ""
      if is_preset
        raise "#{format_type.capitalize} is blank."
      else
        raise "No #{format_type} input."
      end
    end
    
    if is_preset
      match = text.match(/DSVRandom Options Preset, Game: ([^,]+), Randomizer version: (.+)\s+Selected options: (.+)\s+Difficulty level: (.+)/)
      if match.nil?
        raise "#{format_type.capitalize} is not in the proper format."
      end
      
      seed = ""
      game = $1
      version = $2
      options = $3.split(", ").map(&:to_sym)
      difficulty = $4
    else
      match = text.match(/Seed: ([#{VALID_SEED_CHARACTERS}]+), Game: ([^,]+), Randomizer version: (.+)\s+Selected options: (.+)\s+Difficulty level: (.+)/)
      if match.nil?
        raise "#{format_type.capitalize} is not in the proper format."
      end
      
      seed = $1
      game = $2
      version = $3
      options = $4.split(", ").map(&:to_sym)
      difficulty = $5
    end
    
    if version != DSVRANDOM_VERSION
      raise "Wrong version! This is for #{version}, but you are on #{DSVRANDOM_VERSION}"
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
    if last_used_rom_path_for_this_game && File.file?(last_used_rom_path_for_this_game)
      set_clean_rom_combobox_text(last_used_rom_path_for_this_game)
      successfully_changed_clean_rom_path = true
    else
      set_clean_rom_combobox_text("")
      successfully_changed_clean_rom_path = false
    end
    
    @ui.seed.text = seed
    options.each do |option_name|
      if !@ui.respond_to?(option_name)
        raise "Invalid options name found in #{format_type}: \"#{option_name}\""
      end
      @ui.send(option_name).checked = true
    end
    (OPTIONS.keys-options).each do |option_name|
      @ui.send(option_name).checked = false
    end
    
    difficulty_level_options = DIFFICULTY_LEVELS[difficulty]
    if difficulty_level_options
      # Preset difficulty level.
      difficulty_level_changed_by_name(difficulty)
    elsif difficulty =~ /Custom/
      # Custom difficulty.
      
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
      
      DIFFICULTY_RANGES.keys.each do |option_name|
        slider = @slider_widgets_by_name[option_name]
        average = custom_difficulty_options[option_name]
        if average.nil?
          # If some options are missing default to what it is on easy.
          if !DIFFICULTY_LEVELS.values.first.include?(option_name)
            raise "Invalid difficulty setting name found in #{format_type}: \"#{option_name}\""
          end
          average = DIFFICULTY_LEVELS.values.first[option_name]
        end
        slider.blockSignals(true)
        slider.value = average
        slider.blockSignals(false)
        
        line_edit = @difficulty_line_edit_widgets_by_name[option_name]
        line_edit.text = slider.true_value.to_s
      end
      
      difficulty_level_changed_by_name("Custom")
    else
      raise "No difficulty found"
    end
    
    @ui.tabWidget.currentIndex = 0
    
    msg = "Successfully read #{format_type}."
    unless successfully_changed_clean_rom_path
      msg << "\n\nPlease manually change the Clean ROM field to point to a clean #{game} ROM since one could not be detected automatically."
    end
    Qt::MessageBox.information(self, "Read #{format_type}", msg)
  rescue StandardError => e
    puts e.message
    puts e.backtrace.join("\n")
    Qt::MessageBox.warning(self, "#{format_type.capitalize} input failed", e.message)
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
