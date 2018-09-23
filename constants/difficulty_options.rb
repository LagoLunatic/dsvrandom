
DIFFICULTY_RANGES = {
  :item_price_range               => 100..15000,
  :weapon_attack_range            => 0..150,
  :weapon_iframes_range           => 4..55,
  :armor_defense_range            => 0..55,
  :item_extra_stats_range         => -25..50,
  :restorative_amount_range       => 1..1000,
  :heart_restorative_amount_range => 1..350,
  :ap_increase_amount_range       => 1..65535,
  
  :skill_price_range              => 1000..30000,
  :skill_dmg_range                => 5..30,
  :crush_or_union_dmg_range       => 15..55,
  :skill_iframes_range            => 4..55,
  :subweapon_sp_to_master_range   => 100..2000,
  :spell_charge_time_range        => 8..120,
  :skill_mana_cost_range          => 1..60,
  :crush_mana_cost_range          => 50..200,
  :union_heart_cost_range         => 5..50,
  :skill_max_at_once_range        => 1..8,
  :glyph_attack_delay_range       => 1..20,
  
  :item_drop_chance_range         => 1..25,
  :skill_drop_chance_range        => 1..15,
  
  :item_placement_weight          => 0.1..100,
  :soul_candle_placement_weight   => 0.1..100,
  :por_skill_placement_weight     => 0.1..100,
  :glyph_placement_weight         => 0.1..100,
  :max_up_placement_weight        => 0.1..100,
  :money_placement_weight         => 0.1..100,
  
  :max_room_difficulty_mult       => 1.0..5.0,
  :max_enemy_difficulty_mult      => 1.0..5.0,
  :enemy_id_preservation_exponent => 0.0..5.0,
  
  :enemy_stat_mult_range          => 0.5..2.5,
  :enemy_num_weaknesses_range     => 0..8,
  :enemy_num_resistances_range    => 0..8,
  :boss_stat_mult_range           => 0.75..1.25,
  :enemy_anim_speed_mult_range    => 0.33..3.0,
  
  :starting_room_max_difficulty   => 15..75,
}

DIFFICULTY_LEVELS = {
  "Easy" => {
    :item_price_range               => 500,
    :weapon_attack_range            => 30,
    :weapon_iframes_range           => 26,
    :armor_defense_range            => 10,
    :item_extra_stats_range         => 7,
    :restorative_amount_range       => 200,
    :heart_restorative_amount_range => 75,
    :ap_increase_amount_range       => 2000,
    
    :skill_price_range              => 5000,
    :skill_dmg_range                => 11,
    :crush_or_union_dmg_range       => 38,
    :skill_iframes_range            => 26,
    :subweapon_sp_to_master_range   => 100,
    :spell_charge_time_range        => 32,
    :skill_mana_cost_range          => 25,
    :crush_mana_cost_range          => 50,
    :union_heart_cost_range         => 10,
    :skill_max_at_once_range        => 2,
    :glyph_attack_delay_range       => 7,
  
    :item_drop_chance_range         => 13,
    :skill_drop_chance_range        => 8,
    
    :item_placement_weight          => 55,
    :soul_candle_placement_weight   => 8,
    :por_skill_placement_weight     => 25,
    :glyph_placement_weight         => 25,
    :max_up_placement_weight        => 18,
    :money_placement_weight         => 2,
    
    :max_room_difficulty_mult       => 2.0,
    :max_enemy_difficulty_mult      => 1.3,
    :enemy_id_preservation_exponent => 3.0,
  
    :enemy_stat_mult_range          => 1.0,
    :enemy_num_weaknesses_range     => 2,
    :enemy_num_resistances_range    => 2,
    :boss_stat_mult_range           => 1.0,
    :enemy_anim_speed_mult_range    => 0.9,
    
    :starting_room_max_difficulty   => 22,
  },
  
  "Normal" => {
    :item_price_range               => 1500,
    :weapon_attack_range            => 20,
    :weapon_iframes_range           => 33,
    :armor_defense_range            => 6,
    :item_extra_stats_range         => 0,
    :restorative_amount_range       => 150,
    :heart_restorative_amount_range => 50,
    :ap_increase_amount_range       => 1600,
    
    :skill_price_range              => 10000,
    :skill_dmg_range                => 9,
    :crush_or_union_dmg_range       => 33,
    :skill_iframes_range            => 33,
    :subweapon_sp_to_master_range   => 300,
    :spell_charge_time_range        => 37,
    :skill_mana_cost_range          => 30,
    :crush_mana_cost_range          => 60,
    :union_heart_cost_range         => 15,
    :skill_max_at_once_range        => 1.5,
    :glyph_attack_delay_range       => 8.5,
    
    :item_drop_chance_range         => 11,
    :skill_drop_chance_range        => 6,
    
    :item_placement_weight          => 55,
    :soul_candle_placement_weight   => 8,
    :por_skill_placement_weight     => 25,
    :glyph_placement_weight         => 25,
    :max_up_placement_weight        => 18,
    :money_placement_weight         => 2,
    
    :max_room_difficulty_mult       => 2.5,
    :max_enemy_difficulty_mult      => 1.7,
    :enemy_id_preservation_exponent => 3.5,
    
    :enemy_stat_mult_range          => 1.4,
    :enemy_num_weaknesses_range     => 1,
    :enemy_num_resistances_range    => 2.5,
    :boss_stat_mult_range           => 1.12,
    :enemy_anim_speed_mult_range    => 1.3,
    
    :starting_room_max_difficulty   => 35,
  },
}