
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x42] + # unequip dummy weapon (bare knuckles)
  [0xCD] # chaos ring (placed separately by the randomizer logic)

ITEMS_WITH_OP_HARDCODED_EFFECT = []

MAGICAL_TICKET_GLOBAL_ID = 0x2B # Actually Castle Map 0, this is repurposed as a magical ticket.

SPAWNER_ENEMY_IDS = [0x00, 0x01, 0x1A, 0x36, 0x40]

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x73, 0x74, 0x75] # Remove Menace, Soma, and Dracula.

POSSIBLE_RED_WALL_SOULS = (0..0x34).to_a -
  [0x00, 0x01, 0x02, 0x03] - # these are non-offensive souls, they have no hitbox to hit the wall with
  [0x1B, 0x26, 0x28, 0x29, 0x2B, 0x33] - # these can't hit the wall correctly: frozen shade, mollusca, killer fish, malacoda, aguni, holy water
  (0x2D..0x34).to_a # julius mode souls including hell fire, these have no enemy graphic

PATH_BLOCKING_BREAKABLE_WALLS = [] # All breakable walls are path blocking in DoS.

MAGICAL_TICKET_X_POS_OFFSET = 0x02308920+0x1C
MAGICAL_TICKET_Y_POS_OFFSET = 0x02308920+0x20

SOLID_BLOCKADE_TILE_INDEX_FOR_TILESET = {
  14 => { # The Lost Village
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F1214 => 0x0001,
    0x022F320C => 0x019C,
    0x022F5204 => 0x0007,
    0x022F71FC => 0x0001,
  },
  11 => { # Demon Guest House
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F89CC => 0x0004,
    0x022FA9C4 => 0x0007,
    0x022FC9BC => 0x0007,
    0x022FE9B4 => 0x0007,
  },
  6 => { # Wizardry Lab
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F9634 => 0x0037,
    0x022FB62C => 0x0008,
  },
  16 => { # Garden of Madness
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EECD8 => 0x0001,
    0x022F0CD0 => 0x0001,
  },
  8 => { # The Dark Chapel
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EE718 => 0x0006,
    0x022F0710 => 0x0083,
    0x022F2708 => 0x000D,
  },
  7 => { # Condemned Tower & Mine of Judgment
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F544C => 0x0001,
    0x022F7444 => 0x0001,
    0x022F943C => 0x0001,
    0x022FB434 => 0x0001,
  },
  17 => { # Subterranean Hell
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F9B8C => 0x0002,
    0x022FBB84 => 0x0002,
    0x022FDB7C => 0x0003,
  },
  15 => { # Silenced Ruins
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022E6244 => 0x0183,
  },
  9 => { # Cursed Clock Tower
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022F3240 => 0x0001,
    0x022F5238 => 0x0001,
    0x022F7230 => 0x0001,
    0x022F9228 => 0x0001,
  },
  10 => { # The Pinnacle
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EFABC => 0x0001,
    0x022F1AB4 => 0x0080,
    0x022F3AAC => 0x000A,
    0x022F5AA4 => 0x0010,
  },
  12 => { # Menace
    0x022DD044 => 0x0001,
  },
  13 => { # The Abyss
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EFB68 => 0x0001,
    0x022F1B60 => 0x0001,
  },
  18 => { # Prologue
    0x022DECE0 => 0x0005,
  },
  19 => { # Epilogue
    0x022DC5D0 => 0x0030,
  },
  20 => { # Boss Rush
    0x022E1CB4 => 0x0001,
  },
  21 => { # Enemy Set Mode
    0x022DEAE0 => 0x0001,
  },
  22 => { # Throne Room
    0x022DC5D0 => 0x000A,
  },
}
