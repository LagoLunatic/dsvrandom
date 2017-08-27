
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x42] + # unequip dummy weapon (bare knuckles)
  [0xCD] # chaos ring (placed separately by the randomizer logic)

SPAWNER_ENEMY_IDS = [0x00, 0x01, 0x1A, 0x36, 0x40]

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x73, 0x74, 0x75] # Remove Menace, Soma, and Dracula.

POSSIBLE_RED_WALL_SOULS = (0..0x34).to_a -
  [0x00, 0x01, 0x02, 0x03] - # these are non-offensive souls, they have no hitbox to hit the wall with
  [0x1B, 0x26, 0x28, 0x29, 0x2B, 0x33] - # these can't hit the wall correctly: frozen shade, mollusca, killer fish, malacoda, aguni, holy water
  (0x2D..0x34).to_a # julius mode souls including hell fire, these have no enemy graphic

PATH_BLOCKING_BREAKABLE_WALLS = [] # All breakable walls are path blocking in DoS.
