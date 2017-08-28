
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x60, 0xA9, 0xE3, 0x109, 0x126, 0x150, 0x1A1] + # unequip dummy items (---)
  [0x12C] + # magus ring (placed separately by the randomizer logic)
  [0x4F, 0x50, 0x51] # the hard mode clear rewards that give +50 to certain stats. these make the game too easy

MAGICAL_TICKET_GLOBAL_ID = 0x45

SPAWNER_ENEMY_IDS = [0x00, 0x01, 0x09, 0x18, 0x24, 0x38, 0x49, 0x68]

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x99, 0x9A] - # Remove Dracula and True Dracula.
  [0x88, 0x89] # Also remove Fake Grant and Sypha as they're placed together with Trevor.

PATH_BLOCKING_BREAKABLE_WALLS = [
  {area_index: 0, sector_index: 0, var_a: 1},
  {area_index: 0, sector_index: 1, var_a: 0},
  {area_index: 0, sector_index: 2, var_a: 0xA},
  {area_index: 0, sector_index: 2, var_a: 0xB},
  {area_index: 0, sector_index: 4, var_a: 8},
  {area_index: 0, sector_index: 6, var_a: 0xF},
  {area_index: 0, sector_index: 7, var_a: 3},
  {area_index: 0, sector_index: 8, var_a: 6},
  {area_index: 0, sector_index: 8, var_a: 7},
  {area_index: 0, sector_index: 9, var_a: 0xD},
  {area_index: 0, sector_index: 0xA, var_a: 0x10},
  {area_index: 1, var_a: 0},
  {area_index: 1, var_a: 1},
  {area_index: 1, var_a: 3},
  {area_index: 1, var_a: 5},
  {area_index: 1, var_a: 9},
  {area_index: 2, var_a: 4},
  {area_index: 2, var_a: 7},
  {area_index: 2, var_a: 2},
  {area_index: 2, var_a: 6},
  {area_index: 2, var_a: 8},
  {area_index: 5, var_a: 0},
  {area_index: 7, var_a: 1},
  {area_index: 8, var_a: 0},
]
