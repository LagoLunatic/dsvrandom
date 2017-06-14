
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x0, 0x37, 0x50, 0xE5, 0x100, 0x124, 0x139, 0x160] + # unequip dummy items (---)
  [0x161] + # unused vampire killer weapon
  [0xE6] + # casual clothes
  (0x51..0x6E).to_a + # glyph unions
  (0xD7..0xE4).to_a + # no-damage medals
  [0x39, 0x41, 0x61] # usable items with a hardcoded effect for quests TODO

SPAWNER_ENEMY_IDS = [0x00, 0x01, 0x03, 0x0B, 0x0F, 0x1B, 0x2B, 0x3E, 0x48, 0x60, 0x61]

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x78] - # Remove the final boss, Dracula. 
  [0x6D, 0x76] - # Also remove Brachyura and Eligor since they need their own huge rooms.
  [0x71] # Remove Gravedorcus because he relies on code and objects specific to Oblivion Ridge.
