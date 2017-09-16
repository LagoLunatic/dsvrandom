
module EnemyAnimSpeedRandomizer
  def randomize_enemy_anim_speeds
    game.enemy_dnas.each do |enemy_dna|
      if enemy_dna.name == "Wallman"
        # Wallman can't be defeated if he gets sped up.
        next
      end
      
      speed_mult = rng.rand(0.33..3.0)
      
      begin
        sprite_info = enemy_dna.extract_gfx_and_palette_and_sprite_from_init_ai
      rescue SpriteInfo::CreateCodeReadError
        next
      end
      sprite = sprite_info.sprite
      
      sprite.frame_delays.each do |frame_delay|
        frame_delay.delay *= speed_mult
        frame_delay.delay = 1 if frame_delay.delay < 1
        frame_delay.delay = frame_delay.delay.round
      end
      sprite.write_to_rom()
      
      if sprite_info.skeleton_file
        skeleton = SpriteSkeleton.new(sprite_info.skeleton_file, game.fs)
        
        skeleton.animations.each do |anim|
          anim.keyframes.each do |keyframe|
            keyframe.length_in_frames *= speed_mult
            keyframe.length_in_frames = 1 if keyframe.length_in_frames < 1
            keyframe.length_in_frames = keyframe.length_in_frames.round
          end
        end
        
        skeleton.write_to_rom_by_skeleton_file()
      end
    end
  end
end
