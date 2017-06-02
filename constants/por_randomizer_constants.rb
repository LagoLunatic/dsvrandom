
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x60, 0xA9, 0xE3, 0x109, 0x126, 0x150, 0x1A1] + # unequip dummy items (---)
  [0x08, 0x09] + # max ups (placed separately by the randomizer logic)
  [0x12C] # magus ring (placed separately by the randomizer logic)

SPAWNER_ENEMY_IDS = [0x00, 0x01, 0x09, 0x18, 0x24, 0x38, 0x49, 0x68]

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x99, 0x9A] - # Remove Dracula and True Dracula.
  [0x88, 0x89] # Also remove Fake Grant and Sypha as they're placed together with Trevor.
