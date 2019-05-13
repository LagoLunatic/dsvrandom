
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x0, 0x37, 0x50, 0xE5, 0x100, 0x124, 0x139, 0x160] + # unequip dummy items (---)
  [0x161] + # unused vampire killer weapon
  (0x51..0x6E).to_a + # glyph unions
  (0xD7..0xE4).to_a + # no-damage medals
  [0xAE, 0xB6, 0xD6] # usable items with a hardcoded effect for quests

ITEMS_WITH_OP_HARDCODED_EFFECT = [0x123, 0x149] # queen of hearts, death ring

NONOFFENSIVE_SKILL_NAMES = [
  "Magnes",
  "Paries",
  "Volaticus",
  "Vis Fio",
  "Fortis Fio",
  "Sapiens Fio",
  "Fides Fio",
  "Felicem Fio",
  "Inire Pecunia",
  "Arma Felix",
  "Arma Chiroptera",
  "Arma Machina",
  "Refectio",
  "Arma Custos",
  "Dominus Agony",
]

MAX_WARP_ROOMS_PER_AREA = 8

WEAPON_SWING_ANIM_NAMES = {
  0x00 => "Fast",
  0x01 => "Fast stab",
  0x02 => "Fast",
  0x03 => "Slow",
  0x04 => "Stab",
  0x05 => "Normal",
  0x06 => "Normal",
}

WEAPON_SUPER_ANIM_NAMES = {
  0x00 => "Generic",
  0x01 => "Generic",
  0x02 => "Sword",
  0x03 => "Rapier",
  0x04 => "Lance",
  0x05 => "Hammer",
  0x06 => "Bow",
  0x07 => "Axe",
  0x08 => "Sickle",
  0x09 => "Knife",
  0x0A => "Shield",
  0x0B => "Lapiste",
  0x0C => "Pneuma",
  0x0D => "Fire",
  0x0E => "Ice",
  0x0F => "Lightning",
  0x10 => "Holy",
  0x11 => "Dark",
  0x12 => "Nitesco",
  0x13 => "Dominus",
}

MAGICAL_TICKET_GLOBAL_ID = 0x7C

SPAWNER_ENEMY_IDS = [
  0x00, # Bat
  0x01, # Zombie
  0x03, # Ghost
  0x06, # Sea Stinger
  0x0B, # Necromancer
  0x0F, # Gelso
  0x1B, # Winged Guard
  0x2B, # Saint Elmo
  0x3E, # Altair
  0x48, # Ghoul
  0x60, # Medusa Head
  0x61, # Gorgon Head
  0x65, # Winged Skeleton
]

STOLAS_UNFRIENDLY_ENEMY_IDS = []

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x78] - # Remove the final boss, Dracula.
  [0x6D, 0x76] - # Also remove Brachyura and Eligor since they need their own huge rooms.
  [0x71] - # Remove Gravedorcus because he relies on code and objects specific to Oblivion Ridge.
  [0x74] - # Remove Wallman because his instant kill attack can be undodgeable in some boss rooms, and because he's the only boss who can drop a progress glyph.
  [0x67] # Remove Jiang Shi because it doesn't die permanently, which would break things in certain rooms, and just be annoying in others.

ORIGINAL_BOSS_IDS_ORDER = [
  0x6C, # Arthroverta
  0x6B, # Giant Skeleton
  0x6D, # Brachyura
  0x6E, # Maneater
  0x6F, # Rusalka
  0x70, # Goliath
  0x71, # Gravedorcus
  0x72, # Albus
  0x73, # Barlowe
  0x75, # Blackmore
  0x76, # Eligor
  0x77, # Death
]

PATH_BLOCKING_BREAKABLE_WALLS = [
  {var_a: 2, var_b: 0},
  {var_a: 0, var_b: 0},
  {var_a: 3, var_b: 3},
  {var_a: 3, var_b: 4},
  {var_a: 8, var_b: 0},
  {var_a: 7, var_b: 4},
  {var_a: 3, var_b: 0},
  {var_a: 3, var_b: 1},
  {var_a: 3, var_b: 2},
  {var_a: 1, var_b: 0},
  {var_a: 1, var_b: 1},
  {var_a: 0, var_b: 1},
]

MAGICAL_TICKET_X_POS_OFFSET = 0x02037B10
MAGICAL_TICKET_Y_POS_OFFSET = 0x02037B04

INTRO_TEXT_ID = 0x660

BGM_RANDO_AVAILABLE_SONG_INDEXES = [
  0x0E, # An Empty Tome
  0x0E, # An Empty Tome
  0x10, # Malak's Labyrinth
  0x0E, # An Empty Tome
  0x0E, # An Empty Tome
  0x0F, # Ebony Wings
  0x12, # Tower of Dolls
  0x12, # Tower of Dolls
  0x0F, # Ebony Wings
  #0x0D, # Ambience
  0x13, # The Colossus
  0x13, # The Colossus
  0x0E, # An Empty Tome
  0x03, # Serenade of the Hearth
  0x01, # A Prologue
  0x2E, # Riddle
  0x04, # Emerald Mist
  0x04, # Emerald Mist
  0x05, # A Clashing of Waves
  0x0A, # Wandering the Crystal Blue
  0x06, # Rhapsody of the Forsaken
  0x06, # Rhapsody of the Forsaken
  0x07, # Jaws of a Scorched Earth
  0x0B, # Edge of the Sky
  0x2E, # Riddle
  0x0C, # Hard Won Nobility
  0x0C, # Hard Won Nobility
  0x08, # Tragedy's Pulse
  0x08, # Tragedy's Pulse
  0x09, # Unholy Vespers
  0x02, # Chapel Hidden in Smoke
  0x2D, # Lone Challenger
  0x35, # Vampire Killer
  0x36, # Stalker
  0x37, # Wicked Child
  0x38, # Walking on the Edge
  0x39, # Heart of Fire
  0x3A, # Out of Time
  0x3B, # Nothing to Lose
  0x3C, # Black Night
]

LOAD_SPRITE_SINGLE_GFX_FUNC_PTR = 0x0203B5D0
LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x0203B6D0
CUSTOM_LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x022EB1CC

BAD_NEW_SAVE_WARP_ROOMS = [
  "0A-01-09", # pneuma puzzle
]

ALLOWABLE_NONCONTIGUOUS_SECTORS = [
  [6, 1], # Kalidus Channel
]



HARDCODED_SKILL_IFRAMES_LOCATIONS = {
  0x19 => [0x0207943C], # Scutum, iframes are useless
  0x1A => [0x0207943C], # Vol Scutum, iframes are useless
  0x1B => [0x0207943C], # Melio Scutum, iframes are useless
  0x1C => [0x020767B4], # Redire
  0x1D => [0x02078AC4], # Cubus
  0x1E => [0x02079068], # Torpor
  0x1F => [0x0207142C], # Lapiste
  0x20 => [0x02071EC4], # Pneuma
  0x21 => [0x02072318], # Ignis
  0x22 => [0x02072788], # Vol Ignis
  0x23 => [0x02072B70], # Grando
  0x24 => [0x0207342C], # Vol Grando
  0x25 => [0x020742E8], # Fulgur
  0x26 => [0x02073F30], # Vol Fulgur
  0x27 => [0x0207483C], # Luminatio
  0x28 => [0x02074CD4], # Vol Luminatio
  0x29 => [0x02075978], # Umbra
  0x2A => [0x02075248], # Vol Umbra
  0x2B => [0x020762DC], # Morbus
  0x2C => [0x02076DB8], # Nitesco
  0x2D => [0x020796E4], # Acerbatus
  0x2E => [0x0207A088], # Globus
  0x2F => [0x02077328], # Dextro Custos
  0x30 => [0x02077328], # Sinestro Custos
  0x31 => [ # Dominus Hatred
    0x02077A08, # The first projectile you shoot up.
    0x02077910, # The rain of projectiles that comes down.
  ],
  0x32 => [0x02077F34], # Dominus Anger
  0x33 => [0x02070AB0], # Cat Tackle
  0x34 => [0x02070E68], # Cat Tail
  0x3B => [0x0207DCB0], # Rapidus Fio
  0x47 => [0x020834A4], # Fidelis Caries
  0x48 => [0x02082630], # Fidelis Alate
  0x49 => [0x0207EAC0], # Fidelis Polkir
  0x4A => [0x02082A9C], # Fidelis Noctua
  0x4B => [0x0207D554], # Fidelis Medusa
  0x4C => [0x0207D744], # Fidelis Aranea
  0x4D => [0x0207FE0C], # Fidelis Mortus
  0x4F => [0x02083918], # Agartha
  0x55 => [0x020A0014], # Pneuma union
  0x56 => [0x020A081C], # Lapiste union
  0x57 => [0x020A0E54], # Ignis union
  0x58 => [0x020A18B8], # Grando union
  0x59 => [ # Fulgur union
    0x02073F30, # ???
    0x02073FFC, # ???
  ],
  0x5A => [ # Fire+ice union
    0x020A243C, # Circling ice and fire parts
    0x020A25E4, # Center
  ],
  0x5B => [0x020A2AF4], # Light union
  0x5C => [0x020A372C], # Dark union
  0x5D => [0x020A3DC8], # Light+dark union
  0x66 => [0x020A5DF0], # Nitesco union
  0x68 => [0x020A7170], # Dominus union
  0x6A => [0x020A7E60], # Albus's optical shot
  0x6C => [0x020A8748], # Knife union
  0x6D => [0x020A8F08], # Confodere union, the blade uses the iframes from the item data, but the petals have hardcoded iframes.
  0x6E => [ # Arcus union
    0x020A9458, # Single upwards arrow
    0x020A9268, # Rain of arrows
  ],
}



SOLID_BLOCKADE_TILE_INDEX_FOR_TILESET = {
  65 => { # Castle Entrance
    0x022CBF74 => 0x0010,
    0x022CDF6C => 0x00DB,
  },
  66 => { # Castle Entrance
    0x022C9A10 => 0x00E0,
    0x022CBA08 => 0x00DB,
  },
  68 => { # Underground Labyrinth
    0x022E1608 => 0x01C6,
    0x022E3600 => 0x01C6,
    0x022E55F8 => 0x01C6,
    0x022E75F0 => 0x0078,
  },
  69 => { # Library
    0x022D2F80 => 0x0001,
    0x022D4F78 => 0x0001,
    0x022D6F70 => 0x0010,
  },
  70 => { # Library (Kitchen)
    0x022C89CC => 0x00A9,
    0x022CA9C4 => 0x00E0,
  },
  71 => { # Barracks
    0x022D3AA0 => 0x01CC,
  },
  72 => { # Mechanical Tower
    0x022D9A70 => 0x0008,
  },
  73 => { # Mechanical Tower
    0x022C72D0 => 0x0002,
  },
  76 => { # Arms Depot
    0x022D09B8 => 0x000D,
    0x022D29B0 => 0x007A,
  },
  77 => { # Forsaken Cloister
    0x022C9EEC => 0x0275,
  },
  74 => { # Final Approach
    0x022D0FBC => 0x0030,
    0x022D2FB4 => 0x03E7,
  },
  75 => { # Final Approach
    0x022C8248 => 0x00D0,
    0x022CA240 => 0x0001,
    0x022CC238 => 0x0011,
  },
  67 => { # Castle Entrance
    0x022C3738 => 0x0001,
    0x022C5730 => 0x0001,
  },
  40 => { # Wygol Village
    0x022C5CB8 => 0x0001,
    0x022C7CB0 => 0x0001,
    0x022C9CA8 => 0x0001,
  },
  41 => { # Wygol Village
    0x022C3CF4 => 0x0001,
  },
  42 => { # Ecclesia
    0x022CC4EC => 0x0006,
    0x022CE4E4 => 0x0010,
    0x022D04DC => 0x0001,
  },
  43 => { # Training Hall
    0x022C2894 => 0x0020,
  },
  44 => { # Ruvas Forest
    0x022C2FE0 => 0x00E0,
  },
  45 => { # Argila Swamp
    0x022C2FE0 => 0x0106,
  },
  46 => { # Kalidus Channel
    0x022C5208 => 0x00C1,
    0x022C7200 => 0x00D1,
  },
  47 => { # Kalidus Channel
    0x022C2FDC => 0x0001,
  },
  48 => { # Somnus Reef
    0x022C2FDC => 0x00C1,
    0x022C4FD4 => 0x00D1,
  },
  49 => { # Somnus Reef
    0x022C2FDC => 0x018C,
  },
  50 => { # Minera Prison Island
    0x022CD220 => 0x0270,
  },
  51 => { # Minera Prison Island
    0x022CD830 => 0x0113,
  },
  52 => { # Minera Prison Island
    0x022CB888 => 0x0270,
  },
  53 => { # Lighthouse
    0x022C58D4 => 0x000E,
  },
  54 => { # Tymeo Mountains
    0x022C37E0 => 0x0001,
  },
  55 => { # Tymeo Mountains
    0x022C3920 => 0x00D0,
  },
  56 => { # Tristis Pass
    0x022C37E0 => 0x0001,
  },
  57 => { # Tristis Pass
    0x022C4CD0 => 0x0050,
  },
  58 => { # Large Cavern
    0x022C265C => 0x0001,
  },
  59 => { # Giant's Dwelling
    0x022CEE6C => 0x0030,
    0x022D0E64 => 0x00E4,
  },
  60 => { # Mystery Manor
    0x022CBDB8 => 0x0030,
    0x022CDDB0 => 0x00B0,
    0x022CFDA8 => 0x0105,
  },
  61 => { # Misty Forest Road
    0x022CCF9C => 0x0002,
    0x022CEF94 => 0x0001,
  },
  62 => { # Oblivion Ridge
    0x022C46F8 => 0x0010,
  },
  63 => { # Oblivion Ridge
    0x022CCABC => 0x00C0,
    0x022CEAB4 => 0x00C0,
  },
  64 => { # Skeleton Cave
    0x022C9474 => 0x00D8,
    0x022CB46C => 0x0160,
  },
  78 => { # Monastery
    0x022D0568 => 0x0001,
    0x022D2560 => 0x0300,
    0x022D4558 => 0x0001,
  },
  79 => { # Monastery
    0x022C37E0 => 0x0001,
  },
  80 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C2FDC => 0x000F,
  },
  81 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C37E0 => 0x0001,
  },
  82 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C2CE0 => 0x0010,
  },
  83 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C37E0 => 0x0001,
  },
  84 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C3D40 => 0x0018,
  },
  85 => { # Epilogue & Boss Rush Mode & Practice Mode
    0x022C37E0 => 0x0028,
  },
}
