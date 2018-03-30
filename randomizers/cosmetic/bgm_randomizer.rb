
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
