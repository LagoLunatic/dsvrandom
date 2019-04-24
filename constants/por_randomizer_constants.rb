
NONRANDOMIZABLE_PICKUP_GLOBAL_IDS =
  [0x60, 0xA9, 0xE3, 0x109, 0x126, 0x150, 0x1A1] + # unequip dummy items (---)
  [0x12C] + # magus ring (placed separately by the randomizer logic)
  [0x4F, 0x50, 0x51] # the hard mode clear rewards that give +50 to certain stats. these make the game too easy

ITEMS_WITH_OP_HARDCODED_EFFECT = []

NONOFFENSIVE_SKILL_NAMES = [
  "Puppet Master",
  "Gnebu",
  "Stonewall",
  "Offensive Form",
  "Defensive Form",
  "Taunt",
  "Toad Morph",
  "Owl Morph",
  "Berserker",
  "Clear Skies",
  "Time Stop",
  "Heal",
  "Cure Poison",
  "Cure Curse",
  "STR Boost",
  "CON Boost",
  "INT Boost",
  "MIND Boost",
  "LUCK Boost",
  "ALL Boost",
]

SKILLS_THAT_CANT_GAIN_SP = NONOFFENSIVE_SKILL_NAMES + [
  "Knee Strike",
]

MAX_WARP_ROOMS_PER_AREA = 12

WEAPON_SWING_ANIM_NAMES = {
  0x00 => "Fast stab",
  0x01 => "Slash",
  0x02 => "Slash",
  0x03 => "Greatsword",
  0x04 => "Spear",
  0x05 => "Axe",
  0x06 => "Mace",
  0x07 => "Punch",
  0x08 => "Whip",
  0x09 => "Book",
}

WEAPON_SUPER_ANIM_NAMES = {
  0x00 => "None",
  0x01 => "Lunge",
  0x02 => "Fast lunge",
  0x03 => "Backstab",
  0x04 => "Warp jump",
  0x05 => "Triple",
  0x06 => "???",
  0x07 => "Ice breath",
  0x08 => "Fire breath",
  0x09 => "Nebula",
  0x0A => "Flaming",
  0x0B => "Fast 5x",
  0x0C => "Warp jump",
  0x0D => "Warp all over",
  0x0E => "Tackle",
  0x0F => "Spin Kick",
  0x10 => "Combo",
  0x11 => "Martial Art",
  0x12 => "Spinning Art",
  0x13 => "Running Axe",
}

MAGICAL_TICKET_GLOBAL_ID = 0x45

SPAWNER_ENEMY_IDS = [
  0x00, # Zombie
  0x01, # Bat
  0x09, # Mud Man
  0x18, # Larva
  0x24, # Mummy
  0x38, # Medusa Head
  0x49, # Razor Bat
  0x68, # Wakwak Tree
]

STOLAS_UNFRIENDLY_ENEMY_IDS = []

RANDOMIZABLE_BOSS_IDS = BOSS_IDS -
  [0x99, 0x9A] - # Remove Dracula and True Dracula.
  [0x98] - # Remove Whip's Memory since he overwrites and disables Charlotte, and spawns in a bunch of walls and room graphics.
  [0x92] - # Remove Loretta, since the sisters fight can't be randomized and Loretta doesn't work when placed herself anyway.
  [0x81, 0x82, 0x83, 0x84, 0x85, 0x87, 0x88, 0x89, 0x86] # Remove all Nest of Evil bosses since they don't set a boss death flag.

ORIGINAL_BOSS_IDS_ORDER = [
  0x8A, # Dullahan
  0x8B, # Behemoth
  0x8C, # Keremet
  0x8D, # Astarte
  0x8E, # Legion
  0x91, # Stella
  0x8F, # Dagon
  0x90, # Death
  0x92, # Loretta
  0x94, # The Creature
  0x95, # Werewolf
  0x96, # Medusa
  0x97, # Mummy Man
  0x93, # Brauner
]

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

INTRO_TEXT_ID = 0x6BD

BGM_RANDO_AVAILABLE_SONG_INDEXES = [
  0x01, # Invitation of a Crazed Moon
  0x02, # Silent Prison
  0x03, # Jail of Jewels
  0x04, # The Gears Go Awry
  0x05, # Gaze Up at the Darkness
  0x10, # Overture
  0x0F, # Troubled Times
  0x07, # Victorian Fear
  0x0C, # Iron Blue Intention
  0x06, # Hail from the Past
  0x0A, # Sandfall
  0x0B, # In Search of the Secret Spell
  0x09, # The Hidden Curse
  0x0E, # Crucifix Held Close
  0x08, # Chaotic Playground
  0x0D, # Behind the Gaze
  0x18, # Bloodlines Bequeathed
  0x24, # Simon's Theme
]

LOAD_SPRITE_SINGLE_GFX_FUNC_PTR = 0x020217C8
LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x020216B0
CUSTOM_LOAD_SPRITE_MULTI_GFX_FUNC_PTR = 0x02309040

BAD_NEW_SAVE_WARP_ROOMS = []



HARDCODED_SKILL_IFRAMES_LOCATIONS = {
  0x152 => [0x02212AE0], # Axe (Richter)
  0x153 => [0x02212518], # Cross (Richter)
  0x154 => [0x02211E68], # Holy Water (Richter)
  0x155 => [ # Grand Cross
    0x02211404, # Big cross
    0x022119EC, # Tiny rotating crosses
  ],
  0x156 => [], # Seiryu, not hardcoded
  0x157 => [0x0220B220], # Suzaku
  0x158 => [0x0220AFDC], # Byakko
  0x159 => [0x0220D714], # Genbu # doesn't matter?
  0x15A => [], # Knife, not hardcoded
  0x15B => [0x022110A8], # Axe
  0x15C => [0x02210CB4], # Cross
  0x15D => [0x02211E68], # Holy Water # same as richter's
  0x15E => [0x02210784], # Bible
  0x15F => [0x02210490], # Javelin
  0x160 => [0x0220FF68], # Ricochet Rock
  0x161 => [0x0220F7E4], # Boomerang
  0x162 => [0x0220F4F0], # Bwaka Knife
  0x163 => [], # Shuriken, not hardcoded
  0x164 => [], # Yagyu Shuriken, not hardcoded
  0x165 => [0x0220B5AC], # Discus
  0x166 => [0x0220EE38], # Kunimitsu
  0x167 => [], # Kunai, not hardcoded
  0x168 => [0x0220E8A0], # Paper Airplane
  0x169 => [0x0220EB8C], # Cream Pie
  0x16A => [0x0220BAC0], # Crossbow
  0x16B => [0x0220E444], # Dart
  0x16C => [0x0220DF10], # Grenade
  0x16D => [0x0220DAB4], # Steel Ball
  0x16E => [0x0220D714], # Stonewall # doesn't matter? same as genbu
  0x172 => [0x0220C9D0], # Wrecking Ball
  0x173 => [0x0220C6A0], # Rampage
  0x174 => [], # Knee Strike, uses the player's iframes
  0x175 => [0x0220C014], # Aura Blast
  0x176 => [0x0220C31C], # Rocket Slash
  0x177 => [0x021EEA88], # Toad Morph # doesn't matter
  0x179 => [0x021ED630], # Sanctuary
  0x17A => [0x021EDE74], # Speed Up
  0x17C => [0x021EBA20], # Eye for an Eye
  0x17D => [0x021F1280], # Clear Skies
  0x188 => [0x021EC2CC], # Gale Force
  0x189 => [0x021EBE00], # Rock Riot
  0x18A => [0x021EF984], # Raging Fire
  0x18B => [0x021E9748], # Ice Fang
  0x18C => [0x021ED364], # Thunderbolt
  0x18D => [0x021F019C], # Spirit of Light
  0x18E => [0x021EAE1C], # Dark Rift
  0x18F => [0x021EA6CC], # Tempest
  0x190 => [0x021ECEBC], # Stone Circle
  0x191 => [0x021EC870], # Ice Needle
  0x192 => [0x021F08F4], # Explosion
  0x193 => [0x021EFB2C], # Chain Lightning
  0x194 => [0x021EA060], # Piercing Beam
  0x195 => [0x021E9148], # Nightmare
  0x196 => [0x021E8B9C], # Summon Medusa
  0x197 => [0x021E876C], # Acidic Bubbles
  0x198 => [0x021E82B0], # Hex
  0x199 => [ # Salamander
    0x021E79D0, # ???
    0x021E7DA8, # ???
  ],
  0x19A => [0x021E9C00], # Cocytus
  0x19B => [0x021EB310], # Thor's Bellow
  0x19C => [0x021E73D0], # Summon Crow
  0x19D => [ # Summon Ghost
    0x021E73D0, # ???
    0x021E6F4C, # ???
  ],
  0x19E => [0x021E6C70], # Summon Skeleton
  0x19F => [0x021E68FC], # Summon Gunman
  0x1A0 => [0x021E640C], # Summon Frog
  0x1A2 => [], # Rush, uses the player's iframes. (0x021E26CC seems to hardcode some kind of iframes specific to rush, but this is never used?)
  0x1A3 => [0x021E1FB0], # Holy Lightning
  0x1A4 => [0x021E1668], # Axe Bomber
  0x1A5 => [0x021E0FE0], # 1,000 Blades
  0x1A6 => [0x021E0B98], # Volcano
  0x1A7 => [0x021E027C], # Meteor
  0x1A8 => [0x021DFF90], # Grand Cruz
  0x1A9 => [0x021DF5F8], # Divine Storm
  0x1AA => [0x021DEC24], # Dark Gate
  0x1AB => [0x021DE91C], # Greatest Five
}



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
    0x022EAD44 => 0x013A,
    0x022ECD3C => 0x0001,
  },
  82 => { # Great Stairway
    0x022EA020 => 0x0001,
    0x022EC018 => 0x0159,
    0x022EE010 => 0x0001,
  },
  83 => { # Great Stairway
    0x022EA020 => 0x0045,
    0x022EC018 => 0x0001,
  },
  84 => { # Great Stairway
    0x022EA020 => 0x01FE,
    0x022EC018 => 0x0001,
  },
  85 => { # Tower of Death
    0x022EDBE4 => 0x0023,
    0x022EFBDC => 0x0330,
    0x022F1BD4 => 0x0001,
  },
  86 => { # Tower of Death
    0x022EE958 => 0x00D6,
    0x022F0950 => 0x0001,
  },
  87 => { # The Throne Room
    0x022EC5B0 => 0x0001,
    0x022EE5A8 => 0x0001,
  },
  88 => { # Master's Keep
    0x022EB014 => 0x0001,
    0x022ED00C => 0x0006,
    0x022EF004 => 0x0001,
  },
  89 => { # Master's Keep
    0x022EBCD0 => 0x0177,
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
    0x022EB10C => 0x01D1,
    0x022ED104 => 0x0001,
  },
  92 => { # Sandy Grave
    0x022EAA78 => 0x0010,
    0x022ECA70 => 0x0001,
    0x022EDE68 => 0x0005,
  },
  102 => { # Forgotten City
    0x022EA558 => 0x0188,
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
    0x022EADF0 => 0x02D9,
    0x022ECDE8 => 0x0048,
    0x022EEDE0 => 0x0001,
    0x022F0DD8 => 0x0001,
  },
  100 => { # Forest of Doom
    0x022EABC0 => 0x0098,
    0x022ECBB8 => 0x00EA,
    0x022EEBB0 => 0x000B,
  },
  101 => { # Forest of Doom
    0x022EA640 => 0x00E0,
    0x022EC638 => 0x0001,
    0x022EE630 => 0x0008,
  },
  109 => { # Dark Academy
    0x022EBEE4 => 0x0109,
    0x022EDEDC => 0x0001,
    0x022EFED4 => 0x00DF,
  },
  110 => { # Dark Academy
    0x022EAA5C => 0x0220,
    0x022ECA54 => 0x0001,
  },
  111 => { # Dark Academy
    0x022EC3E0 => 0x0237,
  },
  112 => { # Dark Academy
    0x022EB524 => 0x0267,
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
  118 => { # Co-op Boss Rush & Shop Mode
    0x022E1CA4 => 0x003F,
    0x022E289C => 0x0001,
  },
}
