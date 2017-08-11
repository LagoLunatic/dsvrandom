
module RedWallRandomizer
  def randomize_red_walls
    sprite_info = SpecialObjectType.new(0x49, game.fs).extract_gfx_and_palette_and_sprite_from_create_code
    red_walls_image = ChunkyPNG::Image.from_file("./dsvrandom/assets/red wall base sprite.png")
    red_wall_palette = ChunkyPNG::Palette.from_canvas(red_walls_image)
    
    soul_indexes = POSSIBLE_RED_WALL_SOULS.sample(4, random: rng)
    soul_indexes.each_with_index do |soul_index, i|
      soul_global_id = 0xCE + soul_index
      @red_wall_souls << soul_global_id
      
      # Update which soul is actually needed to open this wall.
      game.fs.write(0x0222BD90 + i*6 + 4, [soul_index].pack("v"))
      
      # Update the wall graphic.
      enemy_image = generate_enemy_image_by_soul_index(soul_index, red_wall_palette)
      x_offset = case i
      when 0 # originally skeleton
        2
      when 1 # originally axe armor
        1
      when 2 # originally killer clown
        0
      when 3 # originally ukoback
        3
      end
      red_walls_image.compose!(enemy_image, x_offset*32, 0)
    end
    
    renderer.save_gfx_page(red_walls_image, sprite_info.gfx_pages.first, sprite_info.palette_pointer, 16, 0)
  end
  
  def generate_enemy_image_by_soul_index(soul_index, red_wall_palette)
    enemy_dna = game.enemy_dnas.find{|dna| dna["Soul"] == soul_index}
    if enemy_dna.nil?
      raise "Couldn't find enemy for soul: %02X" % soul_index
    end
    enemy_id = game.enemy_dnas.index(enemy_dna)
    
    sprite_info = EnemyDNA.new(enemy_id, game.fs).extract_gfx_and_palette_and_sprite_from_init_ai
    best_frame = BEST_SPRITE_FRAME_FOR_ENEMY[enemy_id]
    if best_frame.nil? || best_frame == -1
      best_frame = 0
    end
    if enemy_id == 0x10 # une
      best_frame = 6
    end
    if enemy_id == 0x4F # great axe armor, use axe frame instead
      best_frame = 0x1C
    end
    images, min_x, min_y = @renderer.render_sprite(sprite_info, frame_to_render: best_frame)
    trimmed_image = images.first.trim(ChunkyPNG::Color::TRANSPARENT)
    trimmed_image.flip_vertically! # actually flips horizontal despite the name
    
    offset_x = (32 - trimmed_image.width) / 2
    offset_y = (96 - trimmed_image.height) / 2
    
    case enemy_id
    when 0x08 # warg: move to head
      offset_x -= 40
    when 0x10 # une: raise brightness
      trimmed_image.pixels.map! do |pixel|
        h, s, v, a = ChunkyPNG::Color.to_hsv(pixel, include_alpha = true)
        v += 0.25 if v > 0.5
        v -= 0.25 if v < 0.5
        v = 1 if v > 1
        v = 0 if v < 0
        ChunkyPNG::Color.from_hsv(h, s, v, a)
      end
    when 0x14 # rycuda: move to head
      offset_x -= 12
    when 0x23 # amalaric sniper: move up a bit to center on body
      offset_y -= 16
    when 0x3A # malachi: move to right
      offset_x -= 16
    when 0x3C # larva: move to head
      offset_x -= 32
      trimmed_image.flip_vertically! # actually flips horizontal despite the name
    when 0x4F # great axe armor: move to blade of axe
      offset_x -= 12
      offset_y += 8
    when 0x5F # slogra: move right slightly
      offset_x -= 8
    end
    
    if offset_x < 0
      trimmed_image.crop!(offset_x.abs, 0, trimmed_image.width-offset_x.abs, trimmed_image.height)
      offset_x = 0
    end
    if offset_y < 0
      trimmed_image.crop!(0, offset_y.abs, trimmed_image.width, trimmed_image.height-offset_y.abs)
      offset_y = 0
    end
    
    width = [trimmed_image.width, 32].min
    height = [trimmed_image.height, 96].min
    trimmed_image.crop!(0, 0, width, height)
    
    converted_img = renderer.convert_image_to_palette(trimmed_image, red_wall_palette)
    
    offset_image = ChunkyPNG::Image.new(32, 96)
    offset_image.compose!(converted_img, offset_x, offset_y)
    
    return offset_image
  end
end
