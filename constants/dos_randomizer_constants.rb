
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x42] + # unequip dummy weapon (bare knuckles)
  [0xCD] # chaos ring (placed separately by the randomizer logic)

ITEMS_WITH_OP_HARDCODED_EFFECT = []

NONOFFENSIVE_SKILL_NAMES = [
  "Puppet Master",
  "Zephyr",
  "Paranoia",
  "Imp",
  "Bat Form", # TODO: this one doesn't work since it's unnamed in vanilla
  "Flying Armor",
  "Bat Company",
  "Ghost",
  "Flying Humanoid",
  "Devil",
  "Medusa Head",
  "Final Guard",
  "Werewolf",
  "Bone Ark",
]

MAX_WARP_ROOMS_PER_AREA = nil

WEAPON_SWING_ANIM_NAMES = {
  0x00 => "Fast stab",
  0x01 => "Stab",
  0x02 => "Slash",
  0x03 => "Greatsword",
  0x04 => "Spear",
  0x05 => "Axe",
  0x06 => "Mace",
  0x07 => "Katana",
  0x08 => "Punch",
  0x09 => "Gun",
  0x0A => "Throw",
  0x0B => "RPG",
  0x0C => "Whip",
}

WEAPON_SUPER_ANIM_NAMES = {
  0x00 => "None",
  0x01 => "Lunge",
  0x02 => "Fast lunge",
  0x03 => "Backstab",
  0x04 => "Warp jump",
  0x05 => "Triple",
  0x06 => "Katana",
  0x07 => "Fast triple",
  0x08 => "Uppercut",
  0x09 => "Stationary",
  0x0A => "Death Scythe",
  0x0B => "Throw",
  0x0C => "Ice breath",
  0x0D => "Fire breath",
  0x0E => "Claimh Solais",
}

MAGICAL_TICKET_GLOBAL_ID = 0x2B # Actually Castle Map 0, this is repurposed as a magical ticket.

SPAWNER_ENEMY_IDS = [
  0x00, # Zombie
  0x01, # Bat
  0x1A, # Ghoul
  0x36, # Wakwak Tree
  0x40, # Medusa Head
]

STOLAS_UNFRIENDLY_ENEMY_IDS = [0x30] # Guillotiner bugs out and constantly teleports on top of the player before Stolas even summons him.

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x73, 0x74, 0x75] # Remove Menace, Soma, and Dracula.

ORIGINAL_BOSS_IDS_ORDER = [
  0x65, # Flying Armor
  0x66, # Balore
  0x68, # Dmitrii
  0x67, # Malphas
  0x69, # Dario
  0x6A, # Puppet Master
  0x6B, # Rahab
  0x6C, # Gergoth
  0x6D, # Zephyr
  0x6E, # Bat Company
  0x6F, # Paranoia
  0x70, # Aguni
]

POSSIBLE_RED_WALL_SOULS = (0..0x34).to_a -
  [0x00, 0x01, 0x02, 0x03] - # these are non-offensive souls, they have no hitbox to hit the wall with
  [0x1B, 0x26, 0x28, 0x29, 0x2B, 0x33] - # these can't hit the wall correctly: frozen shade, mollusca, killer fish, malacoda, aguni, holy water
  (0x2D..0x34).to_a # julius mode souls including hell fire, these have no enemy graphic

PATH_BLOCKING_BREAKABLE_WALLS = [] # All breakable walls are path blocking in DoS.

MAGICAL_TICKET_X_POS_OFFSET = 0x02308920+0x2C
MAGICAL_TICKET_Y_POS_OFFSET = 0x02308920+0x30

INTRO_TEXT_ID = 0x4A6

BGM_RANDO_AVAILABLE_SONG_INDEXES = [
  0x0D, # Pitch Black Intrusion
  0x11, # Demon Guest House
  0x0E, # Dracula's Tears
  0x0F, # Platinum Moonlight
  0x10, # After Confession
  0x12, # Condemned Tower
  0x14, # Subterranean Hell
  0x15, # Vampire Killer
  0x13, # Cursed Clock Tower
  0x16, # The Pinnacle
  0x17, # Underground Melodies
  0x18, # The Abyss
  0x00, # The Beginning
  0x01, # Bloody Tears
]

LOAD_SPRITE_SINGLE_GFX_FUNC_PTR = 0x0201C2B8
LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x0201C1B8
CUSTOM_LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x02308A0C

BAD_NEW_SAVE_WARP_ROOMS = []



HARDCODED_SKILL_IFRAMES_LOCATIONS = {
  0xD2 => [0x02207744], # Skeleton
  0xD3 => [0x02207F64], # Zombie
  0xD4 => [0x0220C5D4], # Axe Armor
  0xD5 => [0x0220DF4C], # Student Witch
  0xD6 => [0x0220A214], # Warg
  0xD7 => [0x0220BD40], # Bomber Armor
  0xD8 => [0x0220E3CC], # Amalaric Sniper
  0xD9 => [0x0220CDA4], # Cave Troll
  0xDA => [0x0220BB0C], # Waiter Skeleton
  0xDB => [0x0220B628], # Slime
  0xDC => [0x022074F0], # Yorick
  0xDD => [0x02206838], # Une
  0xDE => [0x0220ABE8], # Mandragora
  0xDF => [0x02204750], # Rycuda
  0xE0 => [0x0220A974], # Fleaman
  0xE1 => [ # Ripper
    0x0220A704, # ???
    0x0220A72C, # ???
  ],
  0xE2 => [ # Guillotiner
    0x02203CAC, # Head?
    0x02203B9C, # Body?
  ],
  0xE3 => [0x02206020], # Killer Clown
  0xE4 => [0x02209C64], # Malachi
  0xE5 => [0x0220B198], # Disc Armor
  0xE6 => [0x0220A37C], # Great Axe Armor
  0xE7 => [0x0220913C], # Slaughterer
  0xE8 => [0x0220913C], # Hell Boar # same as slaughterer
  0xE9 => [0x02208BAC], # Frozen Shade
  0xEA => [0x022087E8], # Merman
  0xEB => [0x02203FD4], # Larva
  0xEC => [0x02207120], # Ukoback
  0xED => [0x02206B00], # Decarabia
  0xEE => [0x0220C924], # Succubus
  0xEF => [0x0220652C], # Slogra
  0xF0 => [0x02205CC0], # Erinys
  0xF1 => [0x02205998], # Homunculus
  0xF2 => [0x02205604], # Witch
  0xF3 => [0x0220546C], # Fish Head
  0xF4 => [0x02204AA0], # Mollusca
  0xF5 => [0x02204418], # Dead Mate
  0xF6 => [0x022037DC], # Killer Fish
  0xF7 => [0x02207AF4], # Malacoda
  0xF8 => [0x02209388], # Flame Demon
  0xF9 => [0x02208244], # Aguni
  0xFA => [0x022097BC], # Abaddon
  0xFB => [0x022035CC], # Hell Fire (note: this line originally copied r4 into r1, but the rando changes it to a constant mov)
  0xFD => [0x02203138], # Holy Flame
  0xFE => [0x02202C64], # Blue Splash
  0xFF => [0x02202738], # Holy Lightning
  0x100 => [0x022021DC], # Cross
  0x101 => [0x02201B38], # Holy Water
  0x102 => [0x02201438], # Grand Cross
  0x105 => [0x021E6980], # Black Panther
  0x106 => [0x021E492C], # Armor Knight
  0x107 => [0x021DB510], # Spin Devil
  0x108 => [0x021DEFB0], # Skull Archer
  0x10A => [0x021E50B8], # Yeti
  0x10B => [0x021DC2B0], # Buer
  0x10C => [0x021DFC4C], # Manticore
  0x10D => [0x021DFC4C], # Mushussu # Same as Manticore
  0x10E => [0x021DCE44], # White Dragon
  0x10F => [0x021DCE44], # Catoblepas # Same as White Dragon
  0x110 => [0x021DCE44], # Gorgon # Same as White Dragon
  0x111 => [0x021DB8A4], # Persephone
  0x117 => [0x021E111C], # Alura Une
  0x118 => [0x021E5EC8], # Iron Golem
  0x119 => [0x021DE7D8], # Bone Ark
  0x11A => [0x021E067C], # Barbariccia
  0x11B => [0x021E067C], # Valkyrie # Same as Barbariccia
  0x11C => [0x021DC868], # Bat
  0x11D => [0x021E4448], # Great Armor
  0x11E => [0x021E4024], # Mini Devil
  0x11F => [0x021E387C], # Harpy
  0x120 => [0x021E3124], # Corpseweed
  0x121 => [ # Quetzalcoatl
    0x021E1BAC, # Head
    0x021E1EF4, # Body
  ],
  0x122 => [0x021DD354], # Needles
  0x123 => [0x021DAE0C], # Alastor
  0x124 => [0x021DD868], # Gaibon
  0x125 => [0x021DDE24], # Gergoth
  0x126 => [0x021DBB10], # Death
}



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
    0x022EECD8 => 0x0004,
    0x022F0CD0 => 0x0004,
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
    0x022F544C => 0x00C8,
    0x022F7444 => 0x0001,
    0x022F943C => 0x0001,
    0x022FB434 => 0x0070,
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
    0x022F3240 => 0x0154,
    0x022F5238 => 0x0108,
    0x022F7230 => 0x0005,
    0x022F9228 => 0x0090,
  },
  10 => { # The Pinnacle
    0x0207DAD8 => 0x0010,
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EFABC => 0x0001,
    0x022F1AB4 => 0x0080,
    0x022F3AAC => 0x000A,
    0x022F5AA4 => 0x0022,
  },
  12 => { # Menace
    0x022DD044 => 0x0001,
  },
  13 => { # The Abyss
    0x0207FAD0 => 0x0001,
    0x02081AC8 => 0x0001,
    0x022EFB68 => 0x0110,
    0x022F1B60 => 0x0236,
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
