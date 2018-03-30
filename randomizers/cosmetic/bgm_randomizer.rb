
module BgmRandomizer
  def randomize_bgm
    remaining_song_indexes = BGM_RANDO_AVAILABLE_SONG_INDEXES.dup
    remaining_song_indexes.shuffle!(random: rng)
    
    if GAME == "por"
      (0..15).each do |bgm_index|
        new_song_index = remaining_song_indexes.pop()
        game.write_song_index_by_bgm_index(new_song_index, bgm_index)
      end
    else
      SECTOR_INDEX_TO_SECTOR_NAME[0].keys.each do |sector_index|
        if GAME == "dos" && [0x0A, 0x0C, 0x0D, 0x0E, 0x0F].include?(sector_index)
          # Skip the sectors that don't use the BGM we set (Menace, Prologue, Epilogue, Boss Rush, Enemy Set Mode).
          next
        end
        if GAME == "por" && [0x0C].include?(sector_index)
          # Skip the room with Dracula dying in the sunlight since it doesn't use the BGM we set.
          next
        end
        
        new_song_index = remaining_song_indexes.pop()
        game.write_song_index_by_area_and_sector(new_song_index, 0, sector_index)
      end
      AREA_INDEX_TO_AREA_NAME.keys.each do |area_index|
        next if area_index == 0
        new_song_index = remaining_song_indexes.pop()
        game.write_song_index_by_area_and_sector(new_song_index, area_index, 0)
      end
    end
  end
end
