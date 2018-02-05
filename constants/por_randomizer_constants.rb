
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x60, 0xA9, 0xE3, 0x109, 0x126, 0x150, 0x1A1] + # unequip dummy items (---)
  [0x12C] + # magus ring (placed separately by the randomizer logic)
  [0x4F, 0x50, 0x51] # the hard mode clear rewards that give +50 to certain stats. these make the game too easy

ITEMS_WITH_OP_HARDCODED_EFFECT = []

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

MAGICAL_TICKET_X_POS_OFFSET = 0x0203A298
MAGICAL_TICKET_Y_POS_OFFSET = 0x0203A284

SOLID_BLOCKADE_TILE_INDEX_FOR_TILESET = {
  78 => { # Entrance
    0x022EBFC0 => 0x0008,
    0x022EDFB8 => 0x0002,
    0x022EFFB0 => 0x0001,
  },
  79 => { # Entrance
    0x022EE8B4 => 0x0001,
    0x022F08AC => 0x0001,
    0x022F28A4 => 0x0001,
  },
  80 => { # Buried Chamber
    0x022EA020 => 0x0002,
    0x022EC018 => 0x0001,
  },
  81 => { # Great Stairway
    0x022EAD44 => 0x0001,
    0x022ECD3C => 0x0001,
  },
  82 => { # Great Stairway
    0x022EA020 => 0x0001,
    0x022EC018 => 0x0001,
    0x022EE010 => 0x0001,
  },
  83 => { # Great Stairway
    0x022EA020 => 0x0001,
    0x022EC018 => 0x0001,
  },
  84 => { # Great Stairway
    0x022EA020 => 0x0004,
    0x022EC018 => 0x0001,
  },
  85 => { # Tower of Death
    0x022EDBE4 => 0x0001,
    0x022EFBDC => 0x0001,
    0x022F1BD4 => 0x0001,
  },
  86 => { # Tower of Death
    0x022EE958 => 0x0001,
    0x022F0950 => 0x0001,
  },
  87 => { # The Throne Room
    0x022EC5B0 => 0x0001,
    0x022EE5A8 => 0x0001,
  },
  88 => { # Master's Keep
    0x022EB014 => 0x0001,
    0x022ED00C => 0x0001,
    0x022EF004 => 0x0001,
  },
  89 => { # Master's Keep
    0x022EBCD0 => 0x0004,
    0x022EDCC8 => 0x0001,
  },
  90 => { # Master's Keep
    0x022EAF8C => 0x0013,
  },
  93 => { # City of Haze
    0x022EC544 => 0x0008,
    0x022EE53C => 0x0008,
  },
  94 => { # City of Haze
    0x022EB9BC => 0x000C,
  },
  95 => { # City of Haze
    0x022EAF84 => 0x0010,
    0x022ECF7C => 0x00A8,
  },
  104 => { # 13th Street
    0x022EBCC0 => 0x000C,
  },
  105 => { # 13th Street
    0x022EA824 => 0x0008,
    0x022EC81C => 0x0008,
  },
  106 => { # 13th Street
    0x022EA824 => 0x002D,
    0x022EC81C => 0x0001,
  },
  91 => { # Sandy Grave
    0x022EB10C => 0x0010,
    0x022ED104 => 0x0001,
  },
  92 => { # Sandy Grave
    0x022EAA78 => 0x0010,
    0x022ECA70 => 0x0001,
    0x022EDE68 => 0x0005,
  },
  102 => { # Forgotten City
    0x022EA558 => 0x0010,
    0x022EC550 => 0x0001,
  },
  103 => { # Forgotten City
    0x022EA148 => 0x0010,
    0x022EC140 => 0x0001,
    0x022ED538 => 0x0005,
  },
  96 => { # Nation of Fools
    0x022EA824 => 0x0001,
    0x022EC81C => 0x0001,
    0x022EE814 => 0x0001,
  },
  97 => { # Nation of Fools
    0x022EA824 => 0x0001,
    0x022EC81C => 0x0002,
    0x022EE814 => 0x0002,
  },
  98 => { # Nation of Fools
    0x022EAF34 => 0x0002,
    0x022ECF2C => 0x0001,
  },
  107 => { # Burnt Paradise
    0x022EA824 => 0x0001,
    0x022EC81C => 0x0001,
    0x022EE814 => 0x0001,
  },
  108 => { # Burnt Paradise
    0x022EA824 => 0x0001,
    0x022EC81C => 0x0002,
    0x022EE814 => 0x0002,
  },
  99 => { # Forest of Doom
    0x022EADF0 => 0x0001,
    0x022ECDE8 => 0x0048,
    0x022EEDE0 => 0x0001,
    0x022F0DD8 => 0x0001,
  },
  100 => { # Forest of Doom
    0x022EABC0 => 0x0001,
    0x022ECBB8 => 0x00EA,
    0x022EEBB0 => 0x000B,
  },
  101 => { # Forest of Doom
    0x022EA640 => 0x0001,
    0x022EC638 => 0x0001,
    0x022EE630 => 0x0008,
  },
  109 => { # Dark Academy
    0x022EBEE4 => 0x0001,
    0x022EDEDC => 0x0001,
    0x022EFED4 => 0x00DF,
  },
  110 => { # Dark Academy
    0x022EAA5C => 0x0001,
    0x022ECA54 => 0x0001,
  },
  111 => { # Dark Academy
    0x022EC3E0 => 0x0001,
  },
  112 => { # Dark Academy
    0x022EB524 => 0x0001,
    0x022ED51C => 0x0001,
  },
  113 => { # Nest of Evil
    0x022EA020 => 0x0004,
  },
  114 => { # Boss Rush
    0x022EA020 => 0x0001,
  },
  114 => { # Boss Rush
    0x022EA020 => 0x0001,
  },
  114 => { # Boss Rush
    0x022EA020 => 0x0001,
  },
  115 => { # Lost Gallery
    0x022EB838 => 0x0010,
  },
  117 => { # Epilogue
    0x022EC380 => 0x02D0,
  },
  118 => { # Unused Boss Rush
    0x022E1CA4 => 0x003F,
    0x022E289C => 0x0001,
  },
}
