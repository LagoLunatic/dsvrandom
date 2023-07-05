
GAME = "dos"
REGION = :usa
LONG_GAME_NAME = "Dawn of Sorrow"

AREA_LIST_RAM_START_OFFSET = 0x02006FC4 # Technically not a list, this points to code that has the the area hard coded, since DoS only has one area.

# Overlays 6 to 22.
AREA_INDEX_TO_OVERLAY_INDEX = {
   0 => {
     0 => 14, # lost village
     1 => 11, # demon guest house
     2 =>  6, # wizardry lab
     3 => 16, # garden of madness
     4 =>  8, # dark chapel
     5 =>  7, # condemned tower and mine of judgement
     6 => 17, # subterranean hell
     7 => 15, # silenced ruins
     8 =>  9, # clock tower
     9 => 10, # the pinnacle
    10 => 12, # menace's room
    11 => 13, # the abyss
    12 => 18, # prologue area (in town)
    13 => 19, # epilogue area (overlooking castle)
    14 => 20, # boss rush
    15 => 21, # enemy set mode
    16 => 22, # final room of julius mode where you fight soma
   }
}

AREA_INDEX_TO_AREA_NAME = {
   0 => "Dracula's Castle"
}

SECTOR_INDEX_TO_SECTOR_NAME = {
   0 => {
     0 => "The Lost Village",
     1 => "Demon Guest House",
     2 => "Wizardry Lab",
     3 => "Garden of Madness",
     4 => "The Dark Chapel",
     5 => "Condemned Tower & Mine of Judgment",
     6 => "Subterranean Hell",
     7 => "Silenced Ruins",
     8 => "Cursed Clock Tower",
     9 => "The Pinnacle",
    10 => "Menace",
    11 => "The Abyss",
    12 => "Prologue",
    13 => "Epilogue",
    14 => "Boss Rush",
    15 => "Enemy Set Mode",
    16 => "Throne Room",
  }
}

ENTITY_TYPE_DESCRIPTIONS = {
  0 => "Nothing",
  1 => "Enemy",
  2 => "Special object",
  3 => "Candle",
  4 => "Pickup",
  5 => "???",
  6 => "Entity hider",
  7 => "Font loader",
}

CONSTANT_OVERLAYS = [0, 1, 2, 3, 4, 5]

ROOM_OVERLAYS = (6..22)
MAX_ALLOWABLE_ROOM_OVERLAY_SIZE = 152864

AREAS_OVERLAY = nil
MAPS_OVERLAY = nil

MAP_TILE_METADATA_LIST_START_OFFSET = nil
MAP_TILE_METADATA_START_OFFSET = 0x0207708C
MAP_TILE_LINE_DATA_LIST_START_OFFSET = nil
MAP_TILE_LINE_DATA_START_OFFSET = 0x02076AAC
MAP_LENGTH_DATA_START_OFFSET = nil
MAP_NUMBER_OF_TILES = 3008
MAP_SECRET_DOOR_LIST_START_OFFSET = nil
MAP_SECRET_DOOR_DATA_START_OFFSET = 0x02076408
MAP_SECRET_ROOM_DATA_START_OFFSET = 0x02079D44
MAP_DRAW_X_OFFSET_LOCATION = 0x02024D5C
MAP_DRAW_Y_OFFSET_LOCATION = 0x02024D2C
ABYSS_MAP_TILE_METADATA_START_OFFSET = 0x020788F4
ABYSS_MAP_TILE_LINE_DATA_START_OFFSET = 0x02078810
ABYSS_MAP_NUMBER_OF_TILES = 448
ABYSS_MAP_SECRET_DOOR_DATA_START_OFFSET = 0x0207880C
ABYSS_MAP_DRAW_X_OFFSET_LOCATION = 0x02024D64
ABYSS_MAP_DRAW_Y_OFFSET_LOCATION = 0x02024D34

WARP_ROOM_LIST_START = 0x0222C478
WARP_ROOM_ICON_POS_LIST_START = 0x0209A188
WARP_ROOM_COUNT = 0xC

MAP_FILL_COLOR = [160, 120, 88, 255]
MAP_SAVE_FILL_COLOR = [248, 0, 0, 255]
MAP_WARP_FILL_COLOR = [0, 0, 248, 255]
MAP_SECRET_FILL_COLOR = [0, 128, 0, 255]
MAP_ENTRANCE_FILL_COLOR = [248, 128, 0, 255] # Area entrances don't exist in vanilla DoS, but can be added via an asm patch.
MAP_LINE_COLOR = [248, 248, 248, 255]
MAP_DOOR_COLOR = [16, 216, 32, 255]
MAP_DOOR_CENTER_PIXEL_COLOR = MAP_DOOR_COLOR
MAP_SECRET_DOOR_COLOR = [248, 248, 0, 255]

AREA_MUSIC_LIST_START_OFFSET = nil
SECTOR_MUSIC_LIST_START_OFFSET = 0x0209A634
AVAILABLE_BGM_POOL_START_OFFSET = nil
SONG_INDEX_TO_TEXT_INDEX = [
  0x3B1,
  0x3B2,
  0x3A7,
  0x3A8,
  0x3AF,
  0x3A9,
  0x3AC,
  0x396,
  0x3A5,
  0x3A6,
  0x3AD,
  0x397,
  0x398,
  0x399,
  0x39A,
  0x39B,
  0x39C,
  0x39D,
  0x39E,
  0x39F,
  0x3A0,
  0x3A1,
  0x3A2,
  0x3A3,
  0x3A4,
  0x3B0,
  0x3AA,
  0x3AB,
  "Ambience",
  0x3AE,
]

ASSET_LIST_START = 0x0208CC6C
ASSET_LIST_END = 0x0209A0C3
ASSET_LIST_ENTRY_LENGTH = 0x28

COLOR_OFFSETS_PER_256_PALETTE_INDEX = 16

ENEMY_DNA_RAM_START_OFFSET = 0x02078CAC
ENEMY_DNA_FORMAT = [
  # length: 36
  [4, "Create Code"],
  [4, "Update Code"],
  [2, "Item 1"],
  [2, "Item 2"],
  [1, "Petrified Palette"],
  [1, "Unknown 2"],
  [2, "HP"],
  [2, "MP"],
  [2, "EXP"],
  [1, "Soul Chance"],
  [1, "Attack"],
  [1, "Defense"],
  [1, "Item Chance"],
  [2, "Unknown 3"],
  [1, "Soul"],
  [1, "Enemy Set Cost"],
  [4, "Weaknesses", :bitfield],
  [4, "Resistances", :bitfield],
]
ENEMY_DNA_BITFIELD_ATTRIBUTES = {
  "Weaknesses" => [
    "Strike",
    "Stab",
    "Slash",
    "Fire",
    "Ice",
    "Lightning",
    "Dark",
    "Holy",
    "Poison",
    "Curse",
    "Stone",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Made of flesh",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Unknown 24",
    "Weapons",
    "Red souls",
    "Blue souls",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ],
  "Resistances" => [
    "Strike",
    "Stab",
    "Slash",
    "Fire",
    "Ice",
    "Lightning",
    "Dark",
    "Holy",
    "Poison",
    "Curse",
    "Stone",
    "Unknown 12",
    "Time Stop",
    "Unknown 14",
    "Backstab",
    "Unknown 16",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Unknown 24",
    "Weapons",
    "Red souls",
    "Blue souls",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ],
}

# Overlays 23 to 40 used for enemies.
OVERLAY_FILE_FOR_ENEMY_AI = {
  # Enemies not listed here use one of the constant overlays like 0.
  0x0E => 28, # golem
  0x12 => 27, # manticore
  0x19 => 32, # catoblepas
  0x22 => 28, # treant
  0x25 => 24, # great armor
  0x2F => 31, # devil
  0x4D => 32, # gorgon
  0x51 => 27, # musshusu
  0x5B => 31, # flame demon
  0x5D => 31, # arc demon
  0x61 => 24, # final guard
  0x64 => 28, # iron golem
  0x65 => 30, # flying armor
  0x66 => 23, # balore
  0x67 => 29, # malphas
  0x68 => 40, # dmitrii
  0x69 => 25, # dario
  0x6A => 25, # puppet master
  0x6B => 26, # rahab
  0x6C => 36, # gergoth
  0x6D => 33, # zephyr
  0x6E => 37, # bat company
  0x6F => 35, # paranoia
  0x71 => 34, # death
  0x72 => 39, # abaddon
  0x73 => 38, # menace
}

REUSED_ENEMY_INFO = {
  # Enemies that had parts of them reused from another enemy.
  # init_code: The init code of the original enemy. This is where to look for gfx/palette/sprite data, not the reused enemy's init code.
  # gfx_sheet_ptr_index: The reused enemy uses a different gfx sheet than the original enemy. This value is which one to use.
  # palette_offset: The reused enemy uses different palettes than the original, but they're still in the same list of palettes. This is the offset of the new palette in the list.
  # palette_list_ptr_index: The reused enemy uses a completely different palette list from the original. This value is which one to use.
  0x1A => {init_code: 0x0223266C, gfx_sheet_ptr_index: 0, palette_offset: 2, palette_list_ptr_index: 0}, # ghoul and zombie
  0x4D => {init_code:        nil, gfx_sheet_ptr_index: 0, palette_offset: 0, palette_list_ptr_index: 1}, # gorgon and catoblepas
  0x54 => {init_code: 0x02270704, gfx_sheet_ptr_index: 0, palette_offset: 0, palette_list_ptr_index: 1, sprite_ptr_index: 1}, # erinys and valkyrie
  0x5C => {init_code: 0x02288FBC, gfx_sheet_ptr_index: 0, palette_offset: 0, palette_list_ptr_index: 0}, # tanjelly and slime
  0x5B => {init_code: 0x022FF9F0, gfx_sheet_ptr_index: 1, palette_offset: 0, palette_list_ptr_index: 1, sprite_ptr_index: 1}, # flame demon and devil
  0x5D => {init_code:        nil, gfx_sheet_ptr_index: 2, palette_offset: 0, palette_list_ptr_index: 2, sprite_ptr_index: 2}, # arc demon and devil
}

BEST_SPRITE_FRAME_FOR_ENEMY = {
  # Enemies not listed here default to frame 0.
  0x00 => 0x08, # zombie
  0x05 => 0x26, # peeping eye
  0x09 => 0x11, # spin devil
  0x0E => 0x13, # golem
  0x10 => 0x07, # une
  0x12 => 0x4E, # manticore
  0x15 => 0x0E, # mandragora
  0x17 => 0x0D, # skeleton farmer
  0x19 => 0x24, # catoblepas
  0x1A => 0x08, # ghoul
  0x1B => 0x11, # corpseweed
  0x22 => 0x0F, # treant
  0x23 => 0x11, # amalaric sniper
  0x25 => 0x14, # great armor
  0x26 => 0x1B, # killer doll
  0x29 => 0x05, # witch
  0x2B => 0x08, # lilith
  0x2C => 0x03, # killer clown
  0x2E => 0x06, # fleaman
  0x30 => 0x25, # guillotiner
  0x31 => 0x11, # draghignazzo
  0x36 => 0x1B, # wakwak tree
  0x3C => 0x0A, # larva
  0x3D => 0x04, # heart eater
  0x40 => 0x02, # medusa head
  0x43 => 0x01, # mimic
  0x4A => 0x27, # bugbear
  0x4C => 0x2A, # bone ark
  0x4D => 0x24, # gorgon
  0x4E => 0x0A, # alura une
  0x4F => 0x06, # great axe armor
  0x51 => 0x4F, # mushussu
  0x53 => 0x05, # dead warrior
  0x55 => 0x09, # succubus
  0x56 => 0x10, # ripper
  0x5C => 0x0B, # tanjelly
  0x61 => 0x14, # final guard
  0x62 => 0x1F, # malacoda
  0x63 => 0x01, # alastor
  0x64 => 0x0F, # iron golem
  0x65 => 0x06, # flying armor
  0x66 => 0x05, # balore
  0x6B => 0x71, # rahab
  0x6C => 0x10, # gergoth
  0x6E => 0x05, # bat company
  0x6F => 0x17, # paranoia
  0x71 => 0x16, # death
  0x73 => 0x1F, # menace
  0x74 => 0x16, # soma
}
BEST_SPRITE_OFFSET_FOR_ENEMY = {}

ENEMY_FILES_TO_LOAD_LIST = 0x0208CA90

COMMON_SPRITE = {desc: "Common", sprite: 0x0229EAD8, gfx_wrapper: 0x02079EAC, palette: 0x022B9B04}

SPECIAL_OBJECT_IDS = (0..0x75)
SPECIAL_OBJECT_CREATE_CODE_LIST = 0x0222C714
SPECIAL_OBJECT_UPDATE_CODE_LIST = 0x0222C8F0
OVERLAY_FILE_FOR_SPECIAL_OBJECT = {
  0x2E => 25
}
REUSED_SPECIAL_OBJECT_INFO = {
  0x00 => COMMON_SPRITE, # ice block
  0x01 => {init_code: 0x0222BAB8, ignore_files_to_load: true}, # destructible
  0x02 => {init_code:         -1},
  0x03 => {init_code:         -1},
  0x04 => {init_code:         -1},
  0x05 => {init_code:         -1},
  0x06 => {sprite: 0x0229A9FC, gfx_files: [0x022CA4B8, 0x022CA4C4, 0x022CA4D0, 0x022CA4DC, 0x022CA4E8, 0x022CA4F4], palette: 0x022C141C}, # area titles
  0x09 => {init_code: 0x0222BD04}, # chair
  0x0B => {init_code:         -1},
  0x0E => {init_code:         -1},
  0x11 => {init_code:         -1},
  0x13 => {init_code:         -1},
  0x1D => COMMON_SPRITE, # wooden door
  0x22 => {init_code:         -1},
  0x25 => COMMON_SPRITE, # boss door
  0x26 => {init_code: 0x021A8FC8}, # slot machine
  0x27 => {init_code: 0x021A8434}, # condemned tower gate
  0x29 => {init_code: 0x021A7FC4}, # dark chapel gate
  0x2A => {init_code: 0x021A7B44}, # flood gate
  0x2E => {init_code: 0x02304B98}, # iron maiden
  0x2F => {init_code:         -1},
  0x33 => {init_code:         -1},
  0x34 => {init_code:         -1},
  0x35 => {init_code:         -1},
  0x36 => {init_code:         -1},
  0x38 => {init_code:         -1},
  0x41 => {init_code:         -1},
  0x4C => {init_code:         -1},
  0x47 => {init_code: 0x0222CC10}, # hammer shopkeeper
  0x48 => {init_code: 0x0222CC00}, # yoko shopkeeper
  0x4A => {init_code:         -1},
  0x4F => {init_code: 0x0222CBE0}, # mina event actor
  0x50 => {init_code: 0x0222CC10}, # hammer event actor
  0x51 => {init_code: 0x0222CBF0}, # arikado event actor
  0x52 => {init_code: 0x0222CC20}, # julius event actor
  0x53 => {init_code: 0x0222CC30}, # celia event actor
  0x54 => {init_code: 0x0222CC40}, # dario event actor
  0x55 => {init_code: 0x0222CC50}, # dmitrii event actor
  0x5B => {init_code: 0x0222CC60}, # alucard event actor
  0x5D => {init_code:         -1},
  0x5E => {init_code:         -1},
  0x5F => {init_code:         -1},
  0x60 => {init_code:         -1},
  0x61 => {init_code:         -1},
  0x62 => {init_code:         -1},
  0x63 => {init_code:         -1},
  0x64 => {init_code:         -1},
  0x65 => {init_code:         -1},
  0x66 => {init_code:         -1},
  0x67 => {init_code:         -1},
  0x68 => {init_code:         -1},
  0x69 => {init_code:         -1},
  0x6A => {init_code:         -1},
  0x6B => {init_code:         -1},
  0x6C => {init_code:         -1},
  0x6D => {init_code:         -1},
  0x6E => {init_code:         -1},
  0x6F => {init_code:         -1},
  0x70 => {init_code:         -1},
  0x71 => {init_code:         -1},
  0x72 => {init_code:         -1},
  0x73 => {init_code:         -1},
  0x74 => {init_code:         -1},
  0x75 => {init_code:         -1},
}
BEST_SPRITE_FRAME_FOR_SPECIAL_OBJECT = {
  0x01 => 0x0F,
  0x0C => 0x01,
  0x0D => 0x17,
  0x0F => 0x04,
  0x16 =>   -1,
  0x18 => 0x11,
  0x1A => 0x03,
  0x1D => 0xED,
  0x25 => 0xDF,
  0x26 => 0x06,
  0x28 => 0x01,
  0x30 => 0x06,
  0x3A => 0x08,
  0x3B => 0x06,
  0x3D => 0x01,
  0x3E => 0x01,
  0x59 => 0x0A,
  0x5B => 0x10,
  0x5C =>   -1,
}
BEST_SPRITE_OFFSET_FOR_SPECIAL_OBJECT = {
  0x00 => {x: 8, y: 8},
  0x17 => {x: 8, y: 8},
  0x1D => {x: 8},
  0x25 => {x: 8},
  0x2A => {x: 8},
}
SPECIAL_OBJECT_FILES_TO_LOAD_LIST = 0x0209B88C

WEAPON_GFX_LIST_START = 0x0222EE24
WEAPON_GFX_COUNT = 0x4A
WEAPON_SPRITES_LIST_START = nil
WEAPON_PALETTE_LIST = nil
SKILL_GFX_LIST_START = 0x0222E9D4
SKILL_GFX_COUNT = 0x34

OTHER_SPRITES = [
  COMMON_SPRITE,
  
  {pointer: 0x0222E474, desc: "Soma player"},
  {pointer: 0x0222E4CC, desc: "Julius player"},
  {pointer: 0x0222E524, desc: "Yoko player"},
  {pointer: 0x0222E57C, desc: "Alucard player"},
  
  {pointer: 0x0222BAAC, desc: "Destructibles 0"},
  {pointer: 0x0222BAB8, desc: "Destructibles 1"},
  {pointer: 0x0222BAC4, desc: "Destructibles 2"},
  {pointer: 0x0222BAD0, desc: "Destructibles 3"},
  {pointer: 0x0222BADC, desc: "Destructibles 4"},
  {pointer: 0x0222BAE8, desc: "Destructibles 5"},
  {pointer: 0x0222BAF4, desc: "Destructibles 6"},
  {pointer: 0x0222BB00, desc: "Destructibles 7"},
  {pointer: 0x0222BB0C, desc: "Destructibles 8"},
  {pointer: 0x0222BD04, desc: "Chair 1"},
  {pointer: 0x0222BD10, desc: "Chair 2"},
  {pointer: 0x0222BD1C, desc: "Chair 3"},
  {pointer: 0x0222BD28, desc: "Chair 4"},
  
  {pointer: 0x02215AC4, desc: "Magic seal"},
  
  {pointer: 0x0203D4A0, desc: "Nintendo splash screen"},
  {pointer: 0x0203D564, desc: "Konami splash screen"},
  {pointer: 0x0203D8A8, desc: "Main menu"},
  {pointer: 0x0203DAB0, desc: "Castlevania logo"},
  {pointer: 0x0203A4F8, desc: "Info screen", one_dimensional_mode: true},
  {pointer: 0x0203ED3C, desc: "Credits"},
  {pointer: 0x0203ED58, desc: "Characters used during credits"},
  {pointer: 0x0203ED70, desc: "BGs used during credits"},
  {pointer: 0x0203F410, desc: "Game over screen"},
  {pointer: 0x02046714, desc: "Name signing screen"},
  {pointer: 0x02046ACC, desc: "File select menu"},
  {pointer: 0x020489A4, desc: "Choose course - unused?"},
  {pointer: 0x02049078, desc: "Enemy set mode menu"},
  {pointer: 0x0204908C, desc: "Enemy set retry/complete"},
  {pointer: 0x020490A0, desc: "Wi-fi menu"},
  {desc: "Zephyr's clock hands", sprite: 0x0229B3F4, gfx_file_names: ["/sc/f_ctobj0.dat"], palette: 0x022C22C4},
  
  
  {desc: "Equip menu foreground", no_sprite: true, palette: 0x022C46E8, one_dimensional_mode: true, gfx_file_names: [
    "/sc/f_mainob.dat",
  ]},
  {desc: "Weapon synthesis menu foreground", no_sprite: true, palette: 0x022C490C, one_dimensional_mode: true, gfx_file_names: [
    "/sc/f_mix_e.dat",
  ]},
  {desc: "Yoko main menu and soul release menu foregrounds", no_sprite: true, palette: 0x022C490C, one_dimensional_mode: true, gfx_file_names: [
    "/sc/f_scrap.dat",
  ]},
  
  {desc: "Bestiary enemies 00-03", no_sprite: true, palette: 0x022C358C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire00.dat"]},
  {desc: "Bestiary enemies 04-07", no_sprite: true, palette: 0x022C3610, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire01.dat"]},
  {desc: "Bestiary enemies 08-0B", no_sprite: true, palette: 0x022C3694, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire02.dat"]},
  {desc: "Bestiary enemies 0C-0F", no_sprite: true, palette: 0x022C3718, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire03.dat"]},
  {desc: "Bestiary enemies 10-13", no_sprite: true, palette: 0x022C379C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire04.dat"]},
  {desc: "Bestiary enemies 14-17", no_sprite: true, palette: 0x022C3820, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire05.dat"]},
  {desc: "Bestiary enemies 18-1B", no_sprite: true, palette: 0x022C38A4, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire06.dat"]},
  {desc: "Bestiary enemies 1C-1F", no_sprite: true, palette: 0x022C3928, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire07.dat"]},
  {desc: "Bestiary enemies 20-23", no_sprite: true, palette: 0x022C39AC, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire08.dat"]},
  {desc: "Bestiary enemies 24-27", no_sprite: true, palette: 0x022C3BB0, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire09.dat"]},
  {desc: "Bestiary enemies 28-2B", no_sprite: true, palette: 0x022C3C34, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire10.dat"]},
  {desc: "Bestiary enemies 2C-2F", no_sprite: true, palette: 0x022C3CB8, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire11.dat"]},
  {desc: "Bestiary enemies 30-33", no_sprite: true, palette: 0x022C3D3C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire12.dat"]},
  {desc: "Bestiary enemies 34-37", no_sprite: true, palette: 0x022C3DC0, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire13.dat"]},
  {desc: "Bestiary enemies 38-3B", no_sprite: true, palette: 0x022C3E44, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire14.dat"]},
  {desc: "Bestiary enemies 3C-3F", no_sprite: true, palette: 0x022C3EC8, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire15.dat"]},
  {desc: "Bestiary enemies 40-43", no_sprite: true, palette: 0x022C3F4C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire16.dat"]},
  {desc: "Bestiary enemies 44-47", no_sprite: true, palette: 0x022C3FD0, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire17.dat"]},
  {desc: "Bestiary enemies 48-4B", no_sprite: true, palette: 0x022C4054, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire18.dat"]},
  {desc: "Bestiary enemies 4C-4F", no_sprite: true, palette: 0x022C40D8, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire19.dat"]},
  {desc: "Bestiary enemies 50-53", no_sprite: true, palette: 0x022C415C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire20.dat"]},
  {desc: "Bestiary enemies 54-57", no_sprite: true, palette: 0x022C41E0, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire21.dat"]},
  {desc: "Bestiary enemies 58-5B", no_sprite: true, palette: 0x022C4264, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire22.dat"]},
  {desc: "Bestiary enemies 5C-5F", no_sprite: true, palette: 0x022C42E8, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire23.dat"]},
  {desc: "Bestiary enemies 60-63", no_sprite: true, palette: 0x022C436C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire24.dat"]},
  {desc: "Bestiary enemies 64-67", no_sprite: true, palette: 0x022C43F0, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire25.dat"]},
  {desc: "Bestiary enemies 68-6B", no_sprite: true, palette: 0x022C4474, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire26.dat"]},
  {desc: "Bestiary enemies 6C-6F", no_sprite: true, palette: 0x022C44F8, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire27.dat"]},
  {desc: "Bestiary enemies 70-73", no_sprite: true, palette: 0x022C457C, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire28.dat"]},
  {desc: "Bestiary enemies 74-77", no_sprite: true, palette: 0x022C4600, one_dimensional_mode: true, gfx_file_names: ["/sc/f_rire29.dat"]},
  
  {desc: "Face portraits 00-03 (Soma)", no_sprite: true, palette: 0x022C64D8, gfx_file_names: [
    "/sc/f_fsoma0.dat",
    "/sc/f_fsoma1.dat",
    "/sc/f_fsoma2.dat",
    "/sc/f_fsoma3.dat",
  ]},
  {desc: "Face portraits 04-05 (Soma)", no_sprite: true, palette: 0x022C64FC, gfx_file_names: [
    "/sc/f_fsoma4.dat",
    "/sc/f_fsoma5.dat",
  ]},
  {desc: "Face portrait 06 (Soma)", no_sprite: true, palette: 0x022C6520, gfx_file_names: [
    "/sc/f_fsoma6.dat",
  ]},
  {desc: "Face portraits 07-09 (Mina)", no_sprite: true, palette: 0x022C6544, gfx_file_names: [
    "/sc/f_fmina0.dat",
    "/sc/f_fmina1.dat",
    "/sc/f_fmina2.dat",
  ]},
  {desc: "Face portrait 0A (Mina)", no_sprite: true, palette: 0x022C65B0, gfx_file_names: [
    "/sc/f_fmina3.dat",
  ]},
  {desc: "Face portrait 0B (Mina)", no_sprite: true, palette: 0x022C6568, gfx_file_names: [
    "/sc/f_fmina4.dat",
  ]},
  {desc: "Face portrait 0C (Mina)", no_sprite: true, palette: 0x022C658C, gfx_file_names: [
    "/sc/f_fmina5.dat",
  ]},
  {desc: "Face portrait 0D (Arikado)", no_sprite: true, palette: 0x022C65D4, gfx_file_names: [
    "/sc/f_farik0.dat",
  ]},
  {desc: "Face portrait 0E (Arikado)", no_sprite: true, palette: 0x022C661C, gfx_file_names: [
    "/sc/f_farik1.dat",
  ]},
  {desc: "Face portrait 0F (Alucard)", no_sprite: true, palette: 0x022C65F8, gfx_file_names: [
    "/sc/f_farik2.dat",
  ]},
  {desc: "Face portraits 10-14 (Yoko)", no_sprite: true, palette: 0x022C6688, gfx_file_names: [
    "/sc/f_fyoko0.dat",
    "/sc/f_fyoko1.dat",
    "/sc/f_fyoko2.dat",
    "/sc/f_fyoko3.dat",
    "/sc/f_fyoko4.dat",
  ]},
  {desc: "Face portraits 15-16 (Julius)", no_sprite: true, palette: 0x022C6640, gfx_file_names: [
    "/sc/f_fjuli0.dat",
    "/sc/f_fjuli1.dat",
  ]},
  {desc: "Face portrait 17 (Julius)", no_sprite: true, palette: 0x022C6664, gfx_file_names: [
    "/sc/f_fjuli2.dat",
  ]},
  {desc: "Face portraits 18-1A (Hammer)", no_sprite: true, palette: 0x022C66AC, gfx_file_names: [
    "/sc/f_fhume0.dat",
    "/sc/f_fhume1.dat",
    "/sc/f_fhume2.dat",
  ]},
  {desc: "Face portraits 1B-1E (Celia)", no_sprite: true, palette: 0x022C66D0, gfx_file_names: [
    "/sc/f_fseri0.dat",
    "/sc/f_fseri1.dat",
    "/sc/f_fseri2.dat",
    "/sc/f_fseri3.dat",
  ]},
  {desc: "Face portraits 1F-22 (Dario)", no_sprite: true, palette: 0x022C66F4, gfx_file_names: [
    "/sc/f_fdari0.dat",
    "/sc/f_fdari1.dat",
    "/sc/f_fdari2.dat",
    "/sc/f_fdari3.dat",
  ]},
  {desc: "Face portraits 23-25 (Dmitrii)", no_sprite: true, palette: 0x022C6718, gfx_file_names: [
    "/sc/f_fdomi0.dat",
    "/sc/f_fdomi1.dat",
    "/sc/f_fdomi2.dat",
  ]},
  {desc: "Face portrait 26 (Dmitrii)", no_sprite: true, palette: 0x022C673C, gfx_file_names: [
    "/sc/f_fdomi3.dat",
  ]},
  {desc: "Face portrait 27-28 (Soma)", no_sprite: true, palette: 0x022C64D8, gfx_file_names: [
    "/sc/f_fsoma7.dat",
    "/sc/f_fsoma8.dat",
  ]},
]

CANDLE_FRAME_IN_COMMON_SPRITE = 0xDB
MONEY_FRAME_IN_COMMON_SPRITE = 0xEF
CANDLE_SPRITE = COMMON_SPRITE
MONEY_SPRITE = COMMON_SPRITE

OVERLAY_FILES_WITH_SPRITE_DATA = [2, 3]

TEXT_LIST_START_OFFSET = 0x0222F300
TEXT_RANGE = (0..0x50A)
TEXT_REGIONS = {
  "Character Names" => (0..0xB),
  "Item Names" => (0xC..0xD9),
  "Item Descriptions" => (0xDA..0x1A7),
  "Enemy Names" => (0x1A8..0x21D),
  "Enemy Descriptions" => (0x21E..0x293),
  "Soul Names" => (0x294..0x30E),
  "Soul Descriptions" => (0x30F..0x389),
  "Area Names" => (0x38A..0x395),
  "Music Names" => (0x396..0x3B2),
  "System" => (0x3B3..0x3D8),
  "Menus" => (0x3D9..0x477),
  "Library" => (0x478..0x4A5),
  "Events" => (0x4A6..0x50A)
}
TEXT_REGIONS_OVERLAYS = {
  "Character Names" => 0,
  "Item Names" => 0,
  "Item Descriptions" => 0,
  "Enemy Names" => 0,
  "Enemy Descriptions" => 0,
  "Soul Names" => 0,
  "Soul Descriptions" => 0,
  "Area Names" => 0,
  "Music Names" => 0,
  "System" => 0,
  "Menus" => 0,
  "Library" => 0,
  "Events" => 0
}
STRING_DATABASE_START_OFFSET = 0x02217E14
STRING_DATABASE_ORIGINAL_END_OFFSET = 0x0222B8CA
STRING_DATABASE_ALLOWABLE_END_OFFSET = STRING_DATABASE_ORIGINAL_END_OFFSET
TEXT_COLOR_NAMES = {
  0x00 => "TRANSPARENT",
  0x01 => "WHITE",
  0x02 => "GREY",
  0x03 => "PINK",
  0x04 => "BROWN",
  0x05 => "AZURE",
  0x06 => "DARKBLUE",
  0x07 => "YELLOW",
  0x08 => "ORANGE",
  0x09 => "LIGHTGREEN",
  0x0A => "GREEN",
  0x0B => "BRIGHTPINK",
  0x0C => "PURPLE",
  0x0D => "BROWN2",
  0x0E => "BLACK",
  0x0F => "BLACK2",
}

NAMES_FOR_UNNAMED_SKILLS = {
  0x2E => "Bat Form",
  0x2F => "Holy Flame",
  0x30 => "Blue Splash",
  0x31 => "Holy Lightning",
  0x32 => "Cross",
  0x33 => "Holy Water",
  0x34 => "Grand Cross",
}

ENEMY_IDS = (0x00..0x75).to_a
COMMON_ENEMY_IDS = (0x00..0x64).to_a
BOSS_IDS = (0x65..0x75).to_a

BOSS_DOOR_SUBTYPE = 0x25
BOSS_ID_TO_BOSS_INDEX = {
  0x65 => 0x01, # Flying Armor
  0x66 => 0x02, # Balore
  0x67 => 0x04, # Malphas
  0x68 => 0x03, # Dmitrii
  0x69 => 0x05, # Dario
  0x6A => 0x06, # Puppet Master
  0x6B => 0x08, # Rahab
  0x6C => 0x07, # Gergoth
  0x6D => 0x09, # Zephyr
  0x6E => 0x0A, # Bat Company
  0x6F => 0x0C, # Paranoia
  0x70 => 0x0B, # Aguni
  0x71 => 0x0D, # Death
  0x72 => 0x0F, # Abaddon
}

WOODEN_DOOR_SUBTYPE = 0x1D

AREA_NAME_SUBTYPE = 0x06

SAVE_POINT_SUBTYPE = 0x30
WARP_POINT_SUBTYPE = 0x31

ITEM_LOCAL_ID_RANGES = {
  0x02 => (0x00..0x41), # consumable
  0x03 => (0x01..0x4E), # weapon
  0x04 => (0x00..0x3C), # armor
}
ITEM_GLOBAL_ID_RANGE = (0..0xCD)
SKILL_GLOBAL_ID_RANGE = (0xCE..0x148)
SKILL_GLOBAL_ID_RANGE_EXCLUDING_JULIUS = (0xCE...0xFB).to_a + (0x103..0x148).to_a

SKILL_LOCAL_ID_RANGE = (0..0x7A)
PICKUP_GLOBAL_ID_RANGE = (0..0x148)
MAGIC_SEAL_GLOBAL_ID_RANGE = (0x3D..0x41)

PICKUP_SUBTYPES_FOR_ITEMS = (0x02..0x04)
PICKUP_SUBTYPES_FOR_SKILLS = (0x05..0xFF)

NEW_GAME_STARTING_AREA_INDEX_OFFSET = nil
NEW_GAME_STARTING_SECTOR_INDEX_OFFSET = 0x0202FB84
NEW_GAME_STARTING_ROOM_INDEX_OFFSET = 0x0202FB90
NEW_GAME_STARTING_X_POS_OFFSET = 0x0222DEC8
NEW_GAME_STARTING_Y_POS_OFFSET = 0x0222DECC

TRANSITION_ROOM_LIST_POINTER_HARDCODED_LOCATIONS = [0x02006FB0, 0x02025D64]
FAKE_TRANSITION_ROOMS = []

ITEM_ICONS_PALETTE_POINTER = 0x022C4684
GLYPH_ICONS_PALETTE_POINTER = nil
ITEM_ICONS_GFX_POINTERS = nil

CONSUMABLE_FORMAT = [
  # length: 16
  [2, "Item ID"],
  [2, "Icon"],
  [4, "Price"],
  [1, "Type"],
  [1, "Unknown 1"],
  [2, "Var A"],
  [4, "Unused"],
]
WEAPON_FORMAT = [
  # length: 28
  [2, "Item ID"],
  [2, "Icon"],
  [4, "Price"],
  [1, "Swing Anim"],
  [1, "Unknown 1"],
  [1, "Attack"],
  [1, "Defense"],
  [1, "Strength"],
  [1, "Constitution"],
  [1, "Intelligence"],
  [1, "Luck"],
  [4, "Effects", :bitfield],
  [1, "Sprite"],
  [1, "Super Anim"],
  [1, "Sprite Anim"],
  [1, "IFrames"],
  [2, "Swing Modifiers", :bitfield],
  [2, "Swing Sound"],
]
ARMOR_FORMAT = [
  # length: 20
  [2, "Item ID"],
  [2, "Icon"],
  [4, "Price"],
  [1, "Type"],
  [1, "Unknown 1"],
  [1, "Attack (unused)"],
  [1, "Defense"],
  [1, "Strength"],
  [1, "Constitution"],
  [1, "Intelligence"],
  [1, "Luck"],
  [4, "Resistances", :bitfield],
]
SOUL_FORMAT = [
  # length: 28
  [4, "Code"],
  [2, "Sprite"],
  [1, "Type"],
  [1, "Input flags", :bitfield],
  [2, "Soul Scaling"],
  [2, "Mana cost"],
  [2, "DMG multiplier"],
  [2, "Unknown 3"],
  [4, "Effects", :bitfield],
  [4, "Unwanted States", :bitfield],
  [2, "Var A"],
  [2, "Var B"],
]
SOUL_EXTRA_DATA_FORMAT = [
  # length: 2
  [1, "Max at once"],
  [1, "Bonus max at once"],
]
SUPER_ATTACK_DATA_FORMAT = [
  # length: 8
  [4, "Code"],
  [4, "Mana cost"],
]
ITEM_TYPES = [
  {
    name: "Consumables",
    list_pointer: 0x0209BA68,
    count: 66,
    format: CONSUMABLE_FORMAT # length: 16
  },
  {
    name: "Weapons",
    list_pointer: 0x0209C34C,
    count: 79,
    format: WEAPON_FORMAT # length: 28
  },
  {
    name: "Armor",
    list_pointer: 0x0209BE88,
    count: 61,
    format: ARMOR_FORMAT # length: 20
  },
  {
    name: "Souls",
    list_pointer: 0x0209D190,
    count: 123,
    kind: :skill,
    format: SOUL_FORMAT # length: 28
  },
  {
    name: "Souls (extra data)",
    list_pointer: 0x0209D124,
    count: 53,
    kind: :skill,
    format: SOUL_EXTRA_DATA_FORMAT # length: 2
  },
  {
    name: "Super attacks",
    list_pointer: 0x0222EDAC,
    count: 15,
    kind: :special_attack,
    format: SUPER_ATTACK_DATA_FORMAT # length: 8
  },
]

ITEM_BITFIELD_ATTRIBUTES = {
  "Resistances" => [
    "Strike",
    "Stab",
    "Slash",
    "Fire",
    "Ice",
    "Lightning",
    "Dark",
    "Holy",
    "Poison",
    "Curse",
    "Stone",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Unknown 16",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Unknown 24",
    "Unknown 25",
    "(Dmitrii's) Red souls",
    "(Dmitrii's) Blue souls",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ],
  "Effects" => [
    "Strike",
    "Stab",
    "Slash",
    "Fire",
    "Ice",
    "Lightning",
    "Dark",
    "Holy",
    "Poison",
    "Curse",
    "Stone",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Unknown 16",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Knuckles",
    "Is a weapon",
    "Is a red soul",
    "Is a blue soul",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ],
  "Swing Modifiers" => [
    "No interrupt on land",
    "Weapon floats in place",
    "No flip on player turn",
    "Player can move",
    "No trail gradual fadeout",
    "Unknown 6",
    "Transparent weapon",
    "Shaky weapon",
    "No interrupt on ???",
    "No interrupt on anim end",
    "Unknown 11",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Unknown 16",
  ],
  "Input flags" => [
    "Can't be copied",
    "Unknown 2",
    "Unknown 3",
    "Unknown 4",
    "Hold R",
    "Hold R (2)",
    "Hold R (3)",
    "Hold R (4)",
  ],
  "Unwanted States" => [
    "Moving",
    "Moving forward",
    "Facing left",
    "In air",
    "Double jumping",
    "Hippogryph jumping",
    "Bouncing after a jumpkick",
    "Crouching",
    "Unknown 9",
    "On jump-through platform",
    "Unknown 11",
    "Taking damage in the air",
    "Unknown 13",
    "Jumpkicking",
    "Swinging melee weapon",
    "Super attacking",
    "Unknown 17",
    "Using R-button soul",
    "Backdashing",
    "Unknown 20",
    "Jumpkicking",
    "Taking damage",
    "Unknown 23",
    "Unknown 24",
    "Unknown 25",
    "Unknown 26",
    "Unknown 27",
    "Floating in water",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ]
}

ITEM_POOLS_LIST_POINTER = nil
ITEM_POOL_INDEXES_FOR_AREAS_LIST_POINTER = nil
NUMBER_OF_ITEM_POOLS = 0

PLAYER_LIST_POINTER = 0x0222E474
PLAYER_COUNT = 4
PLAYER_NAMES = [
  "Soma",
  "Julius",
  "Yoko",
  "Alucard",
]
PLAYER_LIST_FORMAT = [
  # length: 88
  [4, "GFX list pointer"],
  [4, "Sprite pointer"],
  [4, "Palette pointer"],
  [4, "State anims ptr"],
  [4, "Filename pointer"],
  [4, "Walking speed"],
  [4, "Jump force"],
  [4, "Actions", :bitfield],
  [4, "??? bitfield", :bitfield],
  [2, "Backdash duration"],
  [2, "Unknown 10"],
  [4, "Backdash force"],
  [4, "Backdash friction"],
  [4, "Number of trails"],
  [4, "Trail start color"],
  [4, "Trail end color"],
  [4, "Unknown 16"],
  [2, "Sprite Y offset"],
  [2, "Unknown 17"],
  [4, "Trail & width scale"],
  [4, "Player height scale"],
  [4, "Enable player scale"],
  [2, "Outline color index"],
  [2, "Outline color"],
  [4, "Sprite asset index"],
]
PLAYER_BITFIELD_ATTRIBUTES = {
  "Actions" => [
    "Can slide",
    "Can use weapons",
    "Can float in water",
    "Can sit",
    "Unknown 5",
    "Can jumpkick",
    "Can superjump",
    "Unknown 8",
    "Unknown 9",
    "Unknown 10",
    "Unknown 11",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Unknown 16",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Unknown 24",
    "Unknown 25",
    "Unknown 26",
    "Unknown 27",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ],
  "??? bitfield" => [
    "Horizontal flip",
    "Can smash head",
    "Unknown 3",
    "Unknown 4",
    "Unknown 5",
    "Unknown 6",
    "Unknown 7",
    "Unknown 8",
    "Unknown 9",
    "Unknown 10",
    "Unknown 11",
    "Unknown 12",
    "Unknown 13",
    "Unknown 14",
    "Unknown 15",
    "Unknown 16",
    "Unknown 17",
    "Unknown 18",
    "Unknown 19",
    "Unknown 20",
    "Unknown 21",
    "Unknown 22",
    "Unknown 23",
    "Unknown 24",
    "Unknown 25",
    "Unknown 26",
    "Unknown 27",
    "Unknown 28",
    "Unknown 29",
    "Unknown 30",
    "Unknown 31",
    "Unknown 32",
  ]
}

NEW_OVERLAY_ID = 41
NEW_OVERLAY_FREE_SPACE_START = 0x02308920
NEW_OVERLAY_FREE_SPACE_MAX_SIZE = 0xC000
ASSET_MEMORY_START_HARDCODED_LOCATION = 0x02060234

TEST_ROOM_SAVE_FILE_INDEX_LOCATION = 0x0203E520
TEST_ROOM_AREA_INDEX_LOCATION      = nil
TEST_ROOM_SECTOR_INDEX_LOCATION    = 0x0203E540
TEST_ROOM_ROOM_INDEX_LOCATION      = 0x0203E548
TEST_ROOM_X_POS_LOCATION           = 0x0203E574
TEST_ROOM_Y_POS_LOCATION           = 0x0203E578
TEST_ROOM_OVERLAY = nil

WEAPON_SYNTH_CHAIN_LIST_START = 0x0209CCBC
WEAPON_SYNTH_CHAIN_NAMES = [
  "Swords",
  "Great Swords",
  "Rapiers",
  "Polearms",
  "Axes",
  "Hammers",
  "Katanas",
  "Punchs",
]

SHOP_ITEM_POOL_LIST = 0x02037264
SHOP_ITEM_POOL_COUNT = 3
SHOP_ITEM_POOL_LENGTH_HARDCODED_LOCATIONS = [0x020370F4, 0x0203711C, 0x02037144]
SHOP_ITEM_POOL_REQUIRED_EVENT_FLAG_HARDCODED_LOCATIONS = [nil, 0x0203710C, 0x02037134]

FAKE_FREE_SPACES = []

MAGIC_SEAL_COUNT = 5
MAGIC_SEAL_LIST_START = 0x0222F1DC
MAGIC_SEAL_FOR_BOSS_LIST_START = 0x0222F290

NUM_PLAYER_ANIM_STATES = 0x42
PLAYER_ANIM_STATE_NAMES = [
  "Idle",
  "Holding up",
  "Starting to walk",
  "Turning around",
  "Walking",
  "Stopping",
  "Landing while moving",
  "Starting to crouch",
  "Crouching",
  "Standing up",
  "Jumping straight up",
  "Jumping diagonally",
  "Double jumping",
  "Superjumping",
  "Smashing head",
  "Falling",
  "Landing from small height",
  "Landing from medium height",
  "Hard landing straight down",
  "Hard landing diagonally",
  "Swimming",
  "Turning around while swimming",
  "Sitting",
  "Using skill on ground",
  "Using skill in air",
  "Starting to use transformation skill",
  "Using transformation skill",
  "Using armor knight",
  "Using malacoda",
  "Using succubus",
  "Using ghost",
  "Using alura une",
  "Using slaughterer",
  "Using hell boar",
  "Starting to charge skull archer",
  "Charging skull archer",
  "Firing skull archer",
  "",
  "Starting to use gergoth/white dragon/gorgon",
  "Using gergoth/white dragon/gorgon",
  "Stop using gergoth",
  "Bat mode",
  "Flying up in bat mode",
  "Transforming into bat mode",
  "Untransforming from bat mode",
  "Using black panther",
  "Using werewolf",
  "Backdashing",
  "Sliding on flat ground",
  "Sliding on slope",
  "Jumpkicking straight down",
  "Jumpkicking diagonally down",
  "Taking damage while standing/walking",
  "Taking damage while backdashing",
  "Taking damage while crouching",
  "Taking damage in air from the front",
  "Taking damage in air from behind",
  "Petrified 1",
  "Petrified 2",
  "Dying",
  "Attacking (unused for Soma)",
  "Attacking while crouching (unused for Soma)",
  "Attacking in air (unused for Soma)",
  "Stop attacking (unused for Soma)",
  "Stop attacking while crouching (unused for Soma)",
  "",
]

MENU_BG_LAYER_INFOS = [
  {
    name: "Main menu (bottom screen)",
    gfx_list_pointer:       0x02079F64,
    palette_list_pointer:   0x022DA284,
    layer_metadata_pointer: 0x0207C8CC,
  },
  {
    name: "Main menu (top screen)",
    gfx_file_pointers:      [0x022D9F48, 0x022D9F54],
    palette_list_pointer:   0x022DA390,
    layer_metadata_pointer: 0x0207BE7C,
  },
  {
    name: "Sound config",
    gfx_file_pointers:      [0x022D9F3C],
    palette_list_pointer:   0x022D9F60,
    layer_metadata_pointer: 0x0207C29C,
  },
  {
    name: "Sound mode",
    gfx_file_pointers:      [0x022D9F3C],
    palette_list_pointer:   0x022D9F60,
    layer_metadata_pointer: 0x0207C4AC,
  },
  {
    name: "Shop",
    gfx_list_pointer:       0x02079EE4,
    palette_list_pointer:   0x022D9FC4,
    layer_metadata_pointer: 0x0207C6BC,
  },
  {
    name: "Weapon synthesis",
    gfx_list_pointer:       0x02079EEC,
    palette_list_pointer:   0x022D9FE8,
    layer_metadata_pointer: 0x0207BA5C,
  },
  {
    name: "Info screen",
    gfx_file_pointers:      [0x022D7E40],
    palette_list_pointer:   0x022DA30C,
    layer_metadata_pointer: 0x0207C08C,
  },
  {
    name: "Pause screen",
    gfx_list_pointer:       0x02079E70,
    palette_list_pointer:   0x022DA3D4,
    layer_metadata_pointer: 0x0207B63C,
  },
  {
    name: "Equip",
    gfx_file_pointers:      [0x022D9E70],
    palette_list_pointer:   0x022DA2A8,
    layer_metadata_pointer: 0x0207BC6C,
  },
  {
    name: "Use item",
    gfx_file_pointers:      [0x022D9EA0],
    palette_list_pointer:   0x022DA240,
    layer_metadata_pointer: 0x0207B00C,
  },
  {
    name: "Ability souls",
    gfx_file_pointers:      [0x022D9EAC],
    palette_list_pointer:   0x022DA1DC,
    layer_metadata_pointer: 0x0207A7CC,
  },
  {
    name: "Config",
    gfx_file_pointers:      [0x022D9EB8],
    palette_list_pointer:   0x022DA0D4,
    layer_metadata_pointer: 0x0207A9DC,
  },
  {
    name: "Bestiary list",
    gfx_list_pointer:       0x02217CA8,
    palette_list_pointer:   0x022DA138,
    layer_metadata_pointer: 0x0207ABEC,
  },
  {
    name: "Bestiary entry",
    gfx_list_pointer:       0x02217CA8,
    palette_list_pointer:   0x022DA138,
    layer_metadata_pointer: 0x0207ADFC,
  },
  {
    name: "Library list",
    gfx_file_pointers:      [0x022D9EDC],
    palette_list_pointer:   0x022DA070,
    layer_metadata_pointer: 0x0207B21C,
  },
  {
    name: "Library entry",
    gfx_file_pointers:      [0x022D9EDC],
    palette_list_pointer:   0x022DA070,
    layer_metadata_pointer: 0x0207B42C,
  },
  {
    name: "Magic Seal practice",
    gfx_file_pointers:      [0x022D9EE8],
    palette_list_pointer:   0x022DA00C,
    layer_metadata_pointer: 0x0207B84C,
  },
]

FONTS = [
  {
    font_path: "/font/LD_font_u8.DAT",
    char_width: 8,
    char_height: 8,
  },
  {
    font_path: "/font/LD_font_u12.DAT",
    char_width: 16,
    char_height: 12,
  },
]
