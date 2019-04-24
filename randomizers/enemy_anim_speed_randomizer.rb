
module EnemyAnimSpeedRandomizer
  def randomize_enemy_anim_speeds
    game.enemy_dnas.each do |enemy_dna|
      if enemy_dna.name == "Wallman"
        # Wallman can't be defeated if he gets sped up.
        next
      end
      if ["Whip's Memory", "Stella", "Loretta", "Albus"].include?(enemy_dna.name)
        # Don't randomize the enemies that share a sprite with a player or it will randomize the player's animation speed too.
        next
      end
      
      speed_mult = named_rand_range_weighted(:enemy_anim_speed_mult_range)
      
      if GAME == "ooe" && ["Brachyura", "Eligor"].include?(enemy_dna.name)
        # Prevent Brachyura and Eligor from being too fast or too slow.
        # If they get too fast they can be undodgeable, and too slow can be annoying to wait for them.
        speed_mult = [speed_mult, 1.5].min
        speed_mult = [speed_mult, 0.75].max
      end
      
      if GAME == "ooe" && enemy_dna.name == "Blackmore"
        # If Blackmore's speed is reduced, he backs the player closer towards the wall than normal, making it impossible to dodge him.
        speed_mult = [speed_mult, 1.0].max
        # He's also too hard to dodge is his speed is increased too much.
        speed_mult = [speed_mult, 1.5].min
      end
      
      if GAME == "ooe" && enemy_dna.name == "Arthroverta"
        # If Arthroverta's speed is reduced too much, his roll attack will clip into the floor and he can't move.
        speed_mult = [speed_mult, 0.85].max
      end
      
      delay_mult = 1.0 / speed_mult
      
      begin
        sprite_info = enemy_dna.extract_gfx_and_palette_and_sprite_from_init_ai
      rescue SpriteInfo::CreateCodeReadError
        next
      end
      sprite = sprite_info.sprite
      
      sprite.frame_delays.each do |frame_delay|
        frame_delay.delay *= delay_mult
        frame_delay.delay = 1 if frame_delay.delay < 1
        frame_delay.delay = frame_delay.delay.round
      end
      sprite.write_to_rom()
      
      if sprite_info.skeleton_file
        # In OoE, also randomize the speed of skeletal animations.
        skeleton = SpriteSkeleton.new(sprite_info.skeleton_file, game.fs)
        
        skeleton.animations.each do |anim|
          anim.keyframes.each do |keyframe|
            keyframe.length_in_frames *= delay_mult
            keyframe.length_in_frames = 1 if keyframe.length_in_frames < 1
            keyframe.length_in_frames = keyframe.length_in_frames.round
          end
        end
        
        skeleton.write_to_rom_by_skeleton_file()
      end
    end
  end
end
