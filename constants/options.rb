
OPTIONS = {
  randomize_pickups: "Randomizes items and skills you find lying on the ground.",
  randomize_boss_souls: "Randomizes the souls dropped by bosses as well as Wallman's glyph (DoS/OoE only).",
  randomize_world_map_exits: "Randomizes the order areas are unlocked on the world map (OoE only, and the Open World Map option must be disabled).",
  randomize_red_walls: "Randomizes which bullet souls are needed to open red walls (DoS only).",
  randomize_portraits: "Randomizes where portraits are located (PoR only).",
  randomize_villagers: "Randomizes where villagers are located (OoE only).",
  
  randomize_maps: "Randomly generates entirely new maps and connects rooms to match the map.",
  randomize_starting_room: "Randomizes which room you start in.",
  
  randomize_enemies: "Randomizes which non-boss enemies appear where.",
  randomize_bosses: "Randomizes which bosses appear where.",
  randomize_enemy_drops: "Randomizes the items, souls, and glyphs dropped by non-boss enemies, as well as their drop chances.",
  randomize_enemy_stats: "Randomizes enemy attack, defense, HP, EXP given, and other stats.",
  randomize_enemy_anim_speed: "Randomizes the speed at which each enemy's animations play at, which affects their attack speed.",
  randomize_enemy_tolerances: "Randomizes enemy elemental weaknesses and resistances.",
  
  randomize_consumable_behavior: "Randomizes what consumables do and how powerful they are.",
  randomize_weapon_behavior: "Randomizes how weapons behave.",
  randomize_skill_behavior: "Randomizes how skills behave.",
  randomize_equipment_stats: "Randomizes weapon and armor stats.",
  randomize_skill_stats: "Randomizes skill stats.",
  randomize_weapon_and_skill_elements: "Randomizes what elemental damage types and status effects each weapon/skill does.",
  
  randomize_shop: "Randomizes what items are for sale in the shop as well as item prices.",
  randomize_weapon_synths: "Randomizes which items Yoko can synthesize (DoS only).",
  randomize_wooden_chests: "Randomizes the pool of items for wooden chests in each area (OoE only).",
  
  experimental_options_enabled: "",
  randomize_enemy_sprites: "Randomizes the graphics of non-boss enemies.",
  randomize_boss_sprites: "Randomizes the graphics of bosses.",
  
  
  enable_glitch_reqs: "If checked, certain glitches may be necessary to beat the game.",
  rebalance_enemies_in_room_rando: "Balances enemy and boss difficulty around the order you will reach them, as opposed to how difficult they were in the vanilla game. (Has no effect if all room randomizer options are off.)",
  
  
  scavenger_mode: "Common enemies never drop items, souls, or glyphs. You have to rely on pickups you find placed in the world.",
  revise_item_descriptions: "Updates all weapon, armor, and skill descriptions to indicate what their randomized attributes are.",
  unlock_all_modes: "Unlocks alternate modes that normally require you to beat the main game first.",
  reveal_breakable_walls: "Breakable walls will always blink as if you have Peeping Eye/Eye for Decay on.",
  reveal_bestiary: "All enemies will appear in the bestiary, even before you kill them once.",
  remove_area_names: "Removes the area names that appear on screen when you first enter an area.",
  show_map_markers_on_top_screen: "Makes reminder markers that you place on the bottom screen in the map menu also show up on the top screen map (PoR and OoE only).",
  
  fix_luck: "Make each point of luck give +0.1% drop chances (as opposed to almost nothing).",
  no_touch_screen: "Seals auto-draw, no name signing, melee weapons destroy ice blocks.",
  unlock_boss_doors: "You don't need magic seals to open boss doors.",
  remove_slot_machines: "Removes golden slot machines that require specific amounts of gold to open.",
  always_start_with_rare_ring: "Gives you the rewards for having AoS in the GBA slot even when AoS is not in the GBA slot.",
  menace_to_somacula: "Changes the final boss of Soma mode to be Somacula instead of Menace.",
  dos_new_style_map: "Makes the map in DoS look like the map in PoR and OoE - doors have a hole in them and the colors have better contrast.",
  
  por_short_mode: "Removes 4 random portrait areas from the game. Unlocking Brauner requires beating the bosses of the 4 portraits that remain (not counting Nest of Evil).",
  start_with_change_cube: "Uncheck this option if you want the Change Cube to be randomized (you won't be able to control Charlotte directly until you find it).",
  por_nerf_enemy_resistances: "Makes enemy resistances behave more like in DoS and OoE: An enemy must resist ALL elements of an attack to resist the attack, instead of just any one of the elements.",
  skip_emblem_drawing: "Skips the screen where you have to use the touch screen to draw an emblem when starting a new game.",
  fix_infinite_quest_rewards: "Fixes a bug where you could get any quest reward over and over again.",
  always_show_drop_percentages: "Drop chances always display as percentages instead of stars.",
  allow_mastering_charlottes_skills: "Allow Charlotte's skills to gain SP like Jonathan's. When mastered they act fully charged at half charge, and when both mastered and fully charged they act supercharged.",
  
  open_world_map: "Make all areas except Dracula's Castle accessible from the start.",
  always_dowsing: "Hidden blue chests always make a beeping sound.",
  gain_extra_attribute_points: "You gain 25x more AP when killing enemies or absorbing glyphs.",
  summons_gain_extra_exp: "Your summons gain far more EXP every time they hit an enemy.",
  
  
  randomize_bgm: "Randomizes what songs play in what areas.",
  randomize_dialogue: "Generates random dialogue for all cutscenes.",
  randomize_player_sprites: "Randomizes the graphics of player characters.",
  randomize_skill_sprites: "Randomizes the graphics used by each skill.",
}

GAME_SPECIFIC_OPTIONS = {
  "dos" => [
    :randomize_boss_souls,
    :randomize_red_walls,
    :randomize_weapon_behavior,
    :randomize_weapon_synths,
    
    :fix_luck,
    :no_touch_screen,
    :unlock_boss_doors,
    :remove_slot_machines,
    :always_start_with_rare_ring,
    :menace_to_somacula,
    :dos_new_style_map,
  ],
  "por" => [
    :randomize_portraits,
    :randomize_weapon_behavior,
    
    :show_map_markers_on_top_screen,
    
    :por_short_mode,
    :start_with_change_cube,
    :por_nerf_enemy_resistances,
    :skip_emblem_drawing,
    :fix_infinite_quest_rewards,
    :always_show_drop_percentages,
    :allow_mastering_charlottes_skills,
  ],
  "ooe" => [
    :randomize_boss_souls,
    :randomize_world_map_exits,
    :randomize_villagers,
    :randomize_wooden_chests,
    
    :show_map_markers_on_top_screen,
    
    :open_world_map,
    :always_dowsing,
    :gain_extra_attribute_points,
    :summons_gain_extra_exp,
  ],
}
