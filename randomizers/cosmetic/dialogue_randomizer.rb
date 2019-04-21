
module DialogueRandomizer
  def randomize_dialogue
    markov = Markov.new(rng)
    
    events = game.text_database.text_list[TEXT_REGIONS["Events"]]
    intro_text = game.text_database.text_list[INTRO_TEXT_ID]
    events -= [intro_text]
    
    library_descriptions = []
    if GAME == "dos"
      TEXT_REGIONS["Library"].each do |text_id|
        next if text_id.even? # Exclude the names of library entries, we only want to randomize the descriptions
        
        library_descriptions << game.text_database.text_list[text_id]
      end
    end
    
    # Build the markov chain's dictionary.
    (events + [intro_text] + library_descriptions).each do |text|
      lines = text.decoded_string.gsub(/\\n/, "").split(/\{[^}]+\}/)
      lines.each do |line|
        markov.parse_string(line)
      end
    end
    
    # Randomize scrolling intro text.
    if GAME == "ooe"
      num_intro_lines = 30
    else
      num_intro_lines = 10
    end
    if GAME == "por"
      intro_max_line_length = 36
    else
      intro_max_line_length = 40
    end
    new_intro_lines = []
    num_intro_lines.times do
      sentence = markov.generate_sentence()
      wordwrapped_sentence_lines = word_wrap_string(sentence, intro_max_line_length)
      new_intro_lines += wordwrapped_sentence_lines
    end
    new_intro_text = new_intro_lines.join("\\n")
    if GAME == "ooe"
      new_intro_text += "\\n"*13
    end
    intro_text.decoded_string = new_intro_text
    
    # Randomize library entry descriptions.
    num_library_lines = 4
    library_max_line_length = 24
    library_descriptions.each do |text|
      new_library_desc_lines = []
      num_library_lines.times do
        sentence = markov.generate_sentence()
        wordwrapped_sentence_lines = word_wrap_string(sentence, library_max_line_length)
        new_library_desc_lines += wordwrapped_sentence_lines
      end
      
      new_library_desc = new_library_desc_lines.join("\\n")
      text.decoded_string = new_library_desc
    end
    
    # Randomize event dialogue.
    case GAME
    when "ooe"
      max_line_length = 39
    else
      max_line_length = 40
    end
    events.each do |text|
      new_lines = []
      
      text.decoded_string.split(/((?:\{[^}]+\})+)/).each do |line|
        next if line.length == 0
        
        if line.start_with?("{")
          # Line of commands. Keep it exactly as it was.
          new_lines << line
        else
          # Generate a new line of dialogue.
          sentence = markov.generate_sentence()
          
          wordwrapped_sentence_lines = word_wrap_string(sentence, max_line_length=max_line_length)
          
          # If the new line takes up more than 3 lines, it won't fit on screen.
          # So we need to break it up into multiple lines that the player can click through.
          groups_of_3_lines = wordwrapped_sentence_lines.each_slice(3).map{|three_lines| three_lines.join("\\n\n")}
          
          new_line = groups_of_3_lines.join("{WAITINPUT}{SAMECHAR}")
          
          new_lines << new_line + "\\n"
        end
      end
      
      text.decoded_string = new_lines.join
    end
    
    game.text_database.write_to_rom()
  end
  
  def word_wrap_string(string, max_line_length=40)
    return string.scan(/\S.{0,#{max_line_length-2}}\S(?=\s|$)|\S+/)
  end
end

class Markov
  attr_reader :dictionary,
              :capitalized_words,
              :rng
  
  def initialize(rng)
    @dictionary = {}
    @capitalized_words = []
    @rng = rng
    @depth = 2
  end
  
  def parse_string(string)
    # Adds a string to the dictionary.
    
    # Remove parentheses, square brackets, and double dashes.
    string = string.gsub(/\(|\)|\[|\]|--/, "")
    sentences = string.split(/(?<=[.!?])\s+/)
    sentences.each do |sentence|
      sentence = sentence.strip
      
      words = sentence.split(/\s+|(\.\.\.)|(\.)|([!?])/)
      if words.last !~ /[.!?]$/
        # Make sure the last word of every sentence is punctuation.
        words << "."
      end
      
      words.each_cons(@depth+1) do |words|
        prev_words = words[0..-2]
        word = words[-1]
        
        self.add_word(prev_words, word)
      end
    end
  end
  
  def add_word(prev_words, word)
    @dictionary[prev_words] ||= []
    @dictionary[prev_words] << word
    if prev_words[0][0] =~ /[A-Z]/
      capitalized_words << prev_words
    end
  end
  
  def generate_sentence
    sentence = []
    max_length = 30
    
    sentence += capitalized_words.sample(random: rng)
    while sentence.length < max_length
      if sentence.last =~ /[.!?]$/
        # Sentence is punctuated.
        break
      end
      
      prev_words = sentence.last(@depth)
      word = get_random_word(prev_words)
      
      if word =~ /[.!?]$/
        # Append punctuation to the last word of the sentence instead of making it a separate word.
        punctuated_final_word = sentence[-1].dup
        if punctuated_final_word[-1] == ","
          # Remove trailing comma before adding the punctuation.
          punctuated_final_word = punctuated_final_word[0..-2]
        end
        sentence[-1] = punctuated_final_word + word
        break
      else
        sentence << word
      end
    end
    
    return sentence.join(" ")
  end
  
  def get_random_word(prev_words)
    possible_words = @dictionary[prev_words]
    
    word = possible_words.sample(random: rng)
  end
end
