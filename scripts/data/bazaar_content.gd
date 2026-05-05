class_name BazaarContent
extends RefCounted

const ItemDataClass = preload("res://scripts/data/item_data.gd")
const MonsterDataClass = preload("res://scripts/data/monster_data.gd")
const HeroDataClass = preload("res://scripts/data/hero_data.gd")
const PassiveSkillDataClass = preload("res://scripts/data/passive_skill.gd")
const WikiMonsterCatalogClass = preload("res://scripts/data/wiki_monster_catalog.gd")
const WikiEventCatalogClass = preload("res://scripts/data/wiki_event_catalog.gd")
const EffectDefinitionClass = preload("res://scripts/data/effect_definition.gd")
const EnchantmentCatalogClass = preload("res://scripts/data/enchantment_catalog.gd")
const PlayerSkillCatalogClass = preload("res://scripts/data/player_skill_catalog.gd")

const RARITY_BRONZE: int = 1
const RARITY_SILVER: int = 2
const RARITY_GOLD: int = 3
const RARITY_DIAMOND: int = 4

const MONSTER_DIRECT_NUMERIC_SKILL_BINDINGS: Dictionary = {
	"ammo_stash": {"bonus_key": "max_ammo", "target": "leftmost_ammo_item", "mechanic": "skill:ammo_stash:leftmost_ammo_item_max_ammo"},
	"command_ship": {"bonus_key": "cooldown_percent", "target": "non_vehicle_items_if_vehicle_present", "mechanic": "skill:command_ship:non_vehicle_cooldown_reduction"},
	"critical_aid": {"bonus_key": "crit_chance", "target": "heal_items", "mechanic": "skill:critical_aid:heal_item_crit_bonus"},
	"deadly_eye": {"bonus_key": "crit_chance", "target": "weapons", "mechanic": "skill:deadly_eye:weapon_crit_bonus"},
	"diamond_fangs": {"bonus_key": "cooldown_percent", "target": "small_diamond_items", "mechanic": "skill:diamond_fangs:small_diamond_item_cooldown_reduction"},
	"final_flame": {"bonus_key": "burn", "target": "rightmost_burn_item", "mechanic": "skill:final_flame:rightmost_burn_bonus"},
	"flamedancer": {"bonus_key": "crit_chance", "target": "burn_items", "mechanic": "skill:flamedancer:burn_item_crit_bonus"},
	"first_responder": {"bonus_key": "heal", "target": "leftmost_heal_item", "mechanic": "skill:first_responder:leftmost_heal_bonus"},
	"follow_up_care": {"bonus_key": "heal", "target": "rightmost_heal_item", "mechanic": "skill:follow_up_care:rightmost_heal_bonus"},
	"friend_zone": {"bonus_key": "cooldown_percent", "target": "friend_items", "mechanic": "skill:friend_zone:friend_cooldown_reduction"},
	"frontal_shielding": {"bonus_key": "shield", "target": "leftmost_shield_item", "mechanic": "skill:frontal_shielding:leftmost_shield_bonus"},
	"full_arsenal": {"bonus_key": "cooldown_percent_per_present_tag", "target": "all_items", "presence_tags": ["Vehicle", "Weapon", "Tool"], "mechanic": "skill:full_arsenal:vehicle_weapon_tool_cooldown_reduction"},
	"gunner": {"bonus_key": "max_ammo", "target": "ammo_items", "mechanic": "skill:gunner:ammo_item_max_ammo"},
	"hyper_focus": {"bonus_key": "cooldown_percent", "target": "only_medium_item", "mechanic": "skill:hyper_focus:solo_medium_item_cooldown_reduction"},
	"initial_dose": {"bonus_key": "poison", "target": "leftmost_poison_item", "mechanic": "skill:initial_dose:leftmost_poison_bonus"},
	"keen_eye": {"bonus_key": "crit_chance", "target": "all_items", "mechanic": "skill:keen_eye:all_item_crit_bonus"},
	"left_handed": {"bonus_key": "damage", "target": "leftmost_weapon", "mechanic": "skill:left_handed:leftmost_weapon_damage_bonus"},
	"right_handed": {"bonus_key": "damage", "target": "rightmost_weapon", "mechanic": "skill:right_handed:rightmost_weapon_damage_bonus"},
	"strength": {"bonus_key": "damage", "target": "weapons", "mechanic": "skill:strength:weapon_damage_bonus"},
	"vengeance": {"bonus_key": "cooldown_percent", "target": "edge_items", "mechanic": "skill:vengeance:edge_item_cooldown_reduction"},
}

const TOP_MONSTER_SPECIAL_IDS: Array[String] = [
	"banannabal", "fanged_inglet", "haunted_kimono", "kyver_drone", "pyro", "viper",
	"coconut_crab", "giant_mosquito", "boarrior", "covetous_thief", "dabbling_apprentice",
	"tempest_bravo", "boilerroom_brawler", "frost_street_challenger", "outlands_dervish",
	"rogue_scrapper", "street_gamer", "ventriloquist", "bloodreef_raider",
	"eccentric_etherwright", "hooverbike_hooligan", "preening_duelist", "retiree",
	"sabretooth", "ahexa", "dire_inglet", "dire_mosquito", "flame_juggler",
	"harkuvian_rocket_trooper", "hellbilly",
]

const HERO_PROFILE_SPECS: Array[Dictionary] = [
	{"type": HeroDataClass.HeroType.VANESSA, "id": "vanessa", "name": "Vanessa", "max_hp": 100, "crit": 0.08, "collection": "Vanessa", "skills": ["deadly_eye", "gunner", "flashy_reload", "crashing_waves", "improved_toxins"], "passives": [{"name": "Aggressive Arsenal", "description": "Wiki gameplay profile: Weapons, Ammo, and Aquatic control define Vanessa's core plans.", "type": "crit", "value": 3.0}, {"name": "Control/Aquatic", "description": "Vanessa supports slowing opponents while building Poison and heavy Aquatic payoffs.", "type": "cooldown", "value": 3.0}]},
	{"type": HeroDataClass.HeroType.PYGMALIEN, "id": "pygmalien", "name": "Pygmalien", "max_hp": 125, "crit": 0.04, "collection": "Pygmalien", "skills": ["toughness", "overheal_haste", "critical_aid", "frontal_shielding", "strength"], "passives": [{"name": "Immovable Object", "description": "Wiki gameplay profile: Healing, Shielding, Max Health, and economy scaling.", "type": "health", "value": 25.0}, {"name": "Jaballian Value", "description": "Pygmalien's item set converts economy and value into combat pressure.", "type": "shield", "value": 15.0}]},
	{"type": HeroDataClass.HeroType.DOOLEY, "id": "dooley", "name": "Dooley", "max_hp": 105, "crit": 0.05, "collection": "Dooley", "skills": ["flashy_mechanic", "electrified_hull", "beautiful_friendship", "time_to_tinker", "distributed_systems"], "passives": [{"name": "Core Chain Reaction", "description": "Wiki gameplay profile: Cores trigger and buff items around them for chain reactions.", "type": "cooldown", "value": 5.0}, {"name": "Robot Friends", "description": "Dooley has access to many robot Friend items and Companion Core-style boards.", "type": "shield", "value": 10.0}]},
	{"type": HeroDataClass.HeroType.MAK, "id": "mak", "name": "Mak", "max_hp": 100, "crit": 0.05, "collection": "Mak", "skills": ["fiery", "improved_toxins", "heated_shells", "paralytic_poison", "slow_burn"], "passives": [{"name": "Alchemy", "description": "Wiki gameplay profile: Potions, Reagents, Burn, Poison, Regeneration, and Catalyst transformations.", "type": "cooldown", "value": 3.0}, {"name": "Regenerative Formula", "description": "Mak can stack Regeneration while transforming Reagents into enchanted items.", "type": "health", "value": 10.0}]},
	{"type": HeroDataClass.HeroType.STELLE, "id": "stelle", "name": "Stelle", "max_hp": 95, "crit": 0.07, "collection": "Stelle", "skills": ["command_ship", "full_arsenal", "the_right_tool", "slow_and_steady", "slowed_targets"], "pool_note": "Stelle has a thinner confirmed wiki pool than launched heroes; current app pool includes every source-backed Stelle item in wiki_monster_catalog.", "passives": [{"name": "Aeronaut", "description": "Wiki item collection profile: Vehicles, Flying, Tools, and Ammo define Stelle content.", "type": "cooldown", "value": 4.0}, {"name": "Precision Pilot", "description": "Stelle boards reward Vehicle/Flying timing and repeated technical activations.", "type": "crit", "value": 2.0}]},
	{"type": HeroDataClass.HeroType.JULES, "id": "jules", "name": "Jules", "max_hp": 110, "crit": 0.05, "collection": "Jules", "skills": ["fiery", "tools_of_the_trade", "strength", "tracer_fire", "flashy_mechanic"], "pool_note": "Jules is upcoming and intentionally thin; current app pool includes every source-backed Jules item in wiki_monster_catalog.", "passives": [{"name": "Joyful Kitchen", "description": "Wiki profile: Jules is upcoming and uses Joy plus Food/Cooking item support.", "type": "health", "value": 10.0}, {"name": "Seasoned Heat", "description": "Jules' confirmed item collection is food/kitchen heavy with Burn and Charge hooks.", "type": "crit", "value": 2.0}]},
	{"type": HeroDataClass.HeroType.KARNOK, "id": "karnok", "name": "Karnok", "max_hp": 110, "crit": 0.05, "collection": "Karnok", "skills": ["burning_rage", "rush", "thick_hide", "void_rage", "draconic_rage"], "pool_note": "Karnok uses the checked BazaarDB/Mobalytics subset plus wiki catalog rows; keep Rage/Enrage gaps explicit until canonical runtime support lands.", "passives": [{"name": "Karnok's Rage", "description": "Mobalytics Karnok guide: item uses build Rage to 100; Enrage clears Slow/Freeze and reduces item Cooldowns by 10% for 5 seconds.", "type": "cooldown", "value": 10.0}, {"name": "Monstrous Hunter", "description": "Temporary app passive derived from Karnok's confirmed monster-hunter/Rage playstyle; replace if Tempo publishes canonical innate passives.", "type": "lifesteal", "value": 4.0}]},
]

const HERO_ARCHETYPE_SPECS: Dictionary = {
	"vanessa": [
		{
			"id": "vanessa_ammo_weapons",
			"name": "Ammo Weapons",
			"tags": ["Weapon", "Ammo", "Damage", "Crit"],
			"core_items": ["bolas", "grenade", "grapeshot", "throwing_knives", "cutlass"],
			"core_skills": ["deadly_eye", "gunner", "flashy_reload", "parting_shot"],
			"summary": "Ammo-backed Weapons scale damage, crit, and reload loops.",
		},
		{
			"id": "vanessa_aquatic_control",
			"name": "Aquatic Control",
			"tags": ["Aquatic", "Slow", "Poison", "Haste"],
			"core_items": ["jellyfish", "dock_lines", "dive_weights", "electric_eels", "turtle_shell"],
			"core_skills": ["crashing_waves", "improved_toxins", "slow_and_steady", "slowed_targets"],
			"summary": "Aquatic items slow, poison, and haste Weapons into control payoffs.",
		},
	],
	"pygmalien": [
		{
			"id": "pygmalien_heal_shield",
			"name": "Heal and Shield",
			"tags": ["Heal", "Shield", "Health"],
			"core_items": ["bandages", "textiles", "hogwash", "igloo", "succulents"],
			"core_skills": ["toughness", "overheal_haste", "critical_aid", "frontal_shielding"],
			"summary": "Healing and Shielding convert sustain into tempo and survivability.",
		},
		{
			"id": "pygmalien_value_weapons",
			"name": "Value Weapons",
			"tags": ["Property", "Economy", "Value", "Weapon"],
			"core_items": ["atm", "landscraper", "spacescraper", "golf_clubs", "tusked_helm"],
			"core_skills": ["strength", "toughness", "left_handed", "right_handed"],
			"summary": "Properties and value engines turn economy into Shield, Heal, and Weapon pressure.",
		},
	],
	"dooley": [
		{
			"id": "dooley_core_tech",
			"name": "Core Tech",
			"tags": ["Tech", "Charge", "Ammo", "Shield"],
			"core_items": ["battery", "lightbulb", "tesla_coil", "nitro", "induction_aegis"],
			"core_skills": ["flashy_mechanic", "electrified_hull", "time_to_tinker"],
			"summary": "Tech items charge neighbors, shield, and chain repeated activations through Cores.",
		},
		{
			"id": "dooley_friend_weapons",
			"name": "Robot Friends",
			"tags": ["Friend", "Weapon", "Vehicle", "Damage"],
			"core_items": ["bill_dozer", "bomb_squad", "micro_dave", "dooltron", "laser_pistol"],
			"core_skills": ["beautiful_friendship", "distributed_systems", "friend_zone"],
			"summary": "Friend boards convert robot activations into Weapon damage and small-item tempo.",
		},
	],
	"mak": [
		{
			"id": "mak_potion_status",
			"name": "Potion Status",
			"tags": ["Potion", "Ammo", "Burn", "Poison"],
			"core_items": ["fire_potion", "noxious_potion", "rainbow_potion", "infinite_potion", "bottled_lightning"],
			"core_skills": ["fiery", "improved_toxins", "heated_shells", "slow_burn"],
			"summary": "Potions deliver Burn, Poison, Slow, and Reload loops through Ammo-backed status pressure.",
		},
		{
			"id": "mak_reagent_transform",
			"name": "Reagent Transform",
			"tags": ["Reagent", "Regen", "Poison", "Transform"],
			"core_items": ["hemlock", "myrrh", "nightshade", "mortar_and_pestle", "aludel"],
			"core_skills": ["paralytic_poison", "poison_tyrant", "regenerative"],
			"summary": "Reagents and catalysts grow Poison and Regeneration while enabling transformation payoffs.",
		},
	],
	"stelle": [
		{
			"id": "stelle_vehicle_flying",
			"name": "Vehicle Flying",
			"tags": ["Vehicle", "Flying", "Cooldown", "Haste"],
			"core_items": ["ornithopter", "paper_airplane", "ice_bomb", "daggerwing", "hammer"],
			"core_skills": ["command_ship", "full_arsenal", "rush"],
			"summary": "Vehicles and Flying effects reduce cooldowns while repeatedly reloading or hasting key items.",
		},
		{
			"id": "stelle_tools_control",
			"name": "Tool Control",
			"tags": ["Tool", "Slow", "Freeze", "Damage"],
			"core_items": ["multitool", "orbital_polisher", "hammer", "lightning_rod", "ice_bomb"],
			"core_skills": ["the_right_tool", "slow_and_steady", "slowed_targets"],
			"summary": "Tools combine Slow, Freeze, and technical damage support for precision control boards.",
		},
	],
	"jules": [
		{
			"id": "jules_food_burn",
			"name": "Food Burn",
			"tags": ["Food", "Burn", "Charge", "Multicast"],
			"core_items": ["black_pepper", "hot_sauce", "pickled_peppers", "ice_cubes", "curry"],
			"core_skills": ["fiery", "tracer_fire", "tools_of_the_trade"],
			"summary": "Food and kitchen items stack Burn, Charge adjacent items, and use Multicast to scale heat.",
		},
		{
			"id": "jules_kitchen_tools",
			"name": "Kitchen Tools",
			"tags": ["Tool", "Weapon", "Charge", "Damage"],
			"core_items": ["knife_set", "black_pepper", "dishwasher", "skillet", "hot_sauce"],
			"core_skills": ["strength", "flashy_mechanic", "tools_of_the_trade"],
			"summary": "Kitchen Tools and Weapons turn repeated tool activations into damage, crit, and haste.",
		},
	],
	"karnok": [
		{
			"id": "karnok_rage_weapons",
			"name": "Rage Weapons",
			"tags": ["Weapon", "Rage", "Damage", "Slow"],
			"core_items": ["bear_claws", "hunters_axe", "adrenaline_shot", "battle_axe", "bear_trap"],
			"core_skills": ["burning_rage", "rush", "thick_hide"],
			"summary": "Rage-tagged Weapons and Ammo pressure enemies while reducing cooldown pressure through Slow/Haste hooks.",
		},
		{
			"id": "karnok_hunter_sustain",
			"name": "Hunter Sustain",
			"tags": ["Heal", "Food", "Tool", "RageReference"],
			"core_items": ["honey_jar", "bagpipes", "campfire", "karst", "black_mamba"],
			"core_skills": ["void_rage", "draconic_rage", "small_refresh"],
			"summary": "Hunter sustain combines Heal/Food/Tool items with Rage-reference payoffs and Burn-triggered tempo.",
		},
	],
}

const KARNOK_BAZAARDB_ITEMS: Array[Dictionary] = [
	{"id": "adrenaline_shot", "name": "Adrenaline Shot", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [6.0], "ammo": 1, "tags": ["Potion", "Rage"], "effect": "Gain 20/30/40/50 Rage. When you Crit, reload this.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "anaconda", "name": "Anaconda", "size": "Large", "starting_tier": "Bronze", "cost": [12, 24, 48, 96], "cooldown": [6.0, 6.0, 4.0, 4.0], "tags": ["Friend", "Weapon", "Vehicle", "Aquatic", "Damage", "RageReference"], "effect": "Deal damage equal to double the Rage you have gained this fight. When you Enrage, this gains +3 Multicast for the fight.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "ancient_locket", "name": "Ancient Locket", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [], "tags": ["Apparel", "Relic", "RageReference"], "effect": "When you become Enraged, destroy this and you take no damage for 2/3/4 seconds.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "assault_sigil", "name": "Assault Sigil", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [], "tags": ["Weapon", "Rage", "HealthReference", "Damage"], "effect": "When you use a Weapon, gain 5 Rage. When you Enrage, deal Damage equal to 10/15/20% of your Max Health.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "aurora_vista", "name": "Aurora Vista", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [6.0, 5.0, 4.0], "tags": ["Property", "Heal", "Shield", "Crit"], "heal": [10, 10, 10], "crit": [20, 20, 20], "effect": "Heal 10. Your Heal items have +Heal equal to this item's Crit Chance. When you Heal, shield equal to the amount Healed.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "bagpipes", "name": "Bagpipes", "size": "Medium", "starting_tier": "Bronze", "cost": [4, 8, 16, 32], "cooldown": [5.0], "tags": ["Tool", "Heal", "RageReference"], "heal": [30, 60, 90, 120], "effect": "Heal 30/60/90/120. Gain 10 Rage. When you Enrage, reduce this item's Cooldown by half for the fight.", "source_url": "https://bazaardb.gg/card/63mc0bxld6ng0mg6g3wjj8p37w/Bagpipes"},
	{"id": "bandoleer", "name": "Bandoleer", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [], "tags": ["Apparel", "AmmoReference", "Rage", "RageReference"], "effect": "When you use an Ammo item, gain 9/12/15 Rage. When you Enrage and stop being Enraged, Reload all your items.", "source_url": "https://bazaardb.gg/card/8qgz7jysczzz7pwnhp3mb4q5k1/Bandoleer"},
	{"id": "bat", "name": "Bat", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [3.0], "tags": ["Friend", "Weapon", "Damage", "Slow", "Flying"], "damage": [5, 5, 5, 5], "slow": [1, 2, 3, 3], "slow_duration": [1.0, 1.0, 1.0, 1.0], "effect": "Deal 5 Damage. Slow 1/2/3 items for 1 second. This starts Flying.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "battle_axe", "name": "Battle Axe", "size": "Medium", "starting_tier": "Bronze", "cost": [4, 8, 16, 32], "cooldown": [8.0], "tags": ["Weapon", "Damage", "RageReference"], "damage": [60, 120, 180, 240], "effect": "Deal 60/120/180/240 Damage. When you Enrage, this gains that much Damage for the fight. While Enraged, this has its Cooldown reduced by 4 seconds.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "bear_claws", "name": "Bear Claws", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [6.0, 5.0, 4.0, 3.0], "tags": ["Weapon", "Damage", "Rage"], "damage": [10, 10, 10, 10], "effect": "Deal 10 Damage. Gain 10 Rage.", "source_url": "https://bazaardb.gg/card/1352swl02hw2jdg7zb1x926szby/Bear-Claws"},
	{"id": "bear_mask", "name": "Bear Mask", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [], "tags": ["Apparel", "Rage", "Health"], "effect": "The first time any item is used each fight, gain 30 Rage. When you Enrage, gain +10/15/20% Max Health for the fight.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "bear_trap", "name": "Bear Trap", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [30.0], "ammo": 1, "tags": ["Tool", "Weapon", "Trap", "Damage", "Slow"], "damage": [25, 50, 75], "slow": [1, 1, 1], "slow_duration": [2.0, 3.0, 4.0], "effect": "Deal 25/50/75 Damage. Slow an item for 2/3/4 seconds. When your enemy uses an item, use this.", "source_url": "https://mobalytics.gg/the-bazaar/karnok-items"},
	{"id": "black_mamba", "name": "Black Mamba", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [5.0], "tags": ["Friend", "Poison", "RageReference"], "poison": [1, 1, 1, 1], "effect": "Poison 1. When you Enrage, your Poison items gain +5/10/15/20 Poison for the fight.", "source_url": "https://bazaardb.gg/card/3p58cjqg4f689hcxknb08f1dpg/Black-Mamba"},
	{"id": "campfire", "name": "Campfire", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [5.0], "tags": ["Heal", "BurnReference", "RageReference"], "effect": "Heal equal to 1/2/3 times the Rage you have gained this fight. For each adjacent Tool, Food or Burn item, this has +1 Multicast.", "source_url": "https://bazaardb.gg/card/193lnch558c38h35lqsyf9g3mln/Campfire"},
	{"id": "enervating_sigil", "name": "Enervating Sigil", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [], "tags": ["SlowReference", "Rage", "RageReference", "Slow"], "effect": "When you Slow, gain 4/6/8 Rage. When you Enrage, Slow ALL items 3 seconds.", "source_url": "https://bazaardb.gg/card/776yfcy5lkgg3fw0kbp9spkmj4/Enervating-Sigil"},
	{"id": "flame_sigil", "name": "Flame Sigil", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [], "tags": ["Burn", "Rage", "RageReference", "HealthReference"], "effect": "When you Burn, gain 5 Rage. When you Enrage, Burn equal to 3/6% of your Max Health.", "source_url": "https://bazaardb.gg/card/qm5shwbzddydf09wy0vlmgbb62/Flame-Sigil"},
	{"id": "honey_jar", "name": "Honey Jar", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [6.0, 5.0, 4.0, 3.0], "tags": ["Food", "Heal", "Slow"], "heal": [30, 30, 30, 30], "slow": [1, 1, 1, 1], "slow_duration": [2.0, 2.0, 2.0, 2.0], "effect": "Heal 30. Slow an item for 2 seconds.", "source_url": "https://bazaardb.gg/card/q8tsclsy2f3nlb938g4vmyqwl5/Honey-Jar"},
	{"id": "hunters_axe", "name": "Hunter's Axe", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [5.0], "tags": ["Weapon", "Tool", "Damage", "Rage"], "damage": [10, 20, 40, 80], "effect": "Deal 10/20/40/80 Damage. When you use an adjacent Tool or Friend, gain 4 Rage.", "source_url": "https://bazaardb.gg/card/8xnw25wskczp7bx357dq048hs1/Hunter%27s-Axe"},
	{"id": "karst", "name": "Karst", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [], "tags": ["Property", "Shield", "RageReference"], "shield": [15, 30, 45], "effect": "When you use a Friend or non-Weapon item, gain 6/8/10 Rage and Shield 15/30/45. Your Enrage lasts half as long.", "source_url": "https://bazaardb.gg/card/4cq3d5p9jh6b47ckysg322nnvj/Karst"},
	{"id": "lichen", "name": "Lichen", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [], "tags": ["Food", "Heal", "RageReference"], "heal": [500, 1000, 1500], "effect": "You need twice as much Rage to Enrage. When you stop being Enraged, Heal 500/1000/1500 and remove half your Poison and Burn.", "source_url": "https://bazaardb.gg/card/mdpv7d1spm58123pn0jkh40b3t/Lichen"},
	{"id": "machete", "name": "Machete", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [4.0, 3.0, 2.0], "tags": ["Weapon", "Tool", "Damage", "Rage"], "damage": [10, 20, 30], "effect": "Deal 10/20/30 Damage. If this is your only item with a Cooldown, gain 50 Rage.", "source_url": "https://bazaardb.gg/card/wlq3bg9xd371vychl8c4f1y0m/Machete"},
	{"id": "night_vision", "name": "Night Vision", "size": "Small", "starting_tier": "Gold", "cost": [8, 16], "cooldown": [3.0], "tags": ["Apparel", "Slow", "Haste"], "slow": [1, 1], "slow_duration": [2.0, 1.0], "haste": [1, 1], "haste_duration": [1.0, 2.0], "effect": "Slow adjacent items for 2/1 seconds. When an adjacent item is Slowed, Haste an item 1/2 seconds.", "source_url": "https://bazaardb.gg/card/9f2nf833fhwjkjf93zqssqkvvq/Night-Vision"},
	{"id": "steel_bramble", "name": "Steel Bramble", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [], "tags": ["Tool", "Rage"], "effect": "When your enemy uses an item, gain 1/2/3 Rage.", "source_url": "https://bazaardb.gg/card/153116qd98x9gvjvq0flg2xst4s/Steel-Bramble"},
]

const REACHABLE_EXTRA_REWARD_ITEM_IDS: Array[String] = [
	"ornithopter", "wanted_poster", "catfish", "revolver", "pearl", "pufferfish",
	"dooltron", "cog", "flamberge", "hot_sauce", "ice_cubes", "coolant",
	"genie_lamp", "chocolate_bar", "mortar_pestle", "powder_flask", "pelt",
	"bear_claws", "magic_carpet", "cosmic_amulet", "cinders", "upgrade_hammer",
]

const DAY1_EVENT_SPECS: Array[Dictionary] = [
	{"id": "a_strange_mushroom", "name": "A Strange Mushroom", "icon": "*", "day": "1-2", "min_day": 1, "max_day": 2, "rarity": "Bronze", "weight": 10, "summary": "Mak can brew a small Silver-tier Potion."},
	{"id": "armory", "name": "Armory", "icon": "W", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a free Weapon."},
	{"id": "b1_b2", "name": "B1&B2", "icon": "^", "day": "1-8", "min_day": 1, "max_day": 8, "rarity": "Silver", "weight": 8, "summary": "Upgrade 1 Bronze-tier item."},
	{"id": "battlefield", "name": "Battlefield", "icon": "W", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 12, "summary": "Get a free small Weapon."},
	{"id": "borrow", "name": "Borrow", "icon": "$", "day": "1-2 / 3-4 / 5-6", "min_day": 1, "max_day": 6, "rarity": "Silver", "weight": 8, "summary": "Lose 1 Income and gain 8/7/6 Gold."},
	{"id": "botanical_gardens", "name": "Botanical Gardens", "icon": "P", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a free Poison item.", "collection": "Vanessa, Mak"},
	{"id": "cache_of_riches", "name": "Cache of Riches", "icon": "$", "day": "1-2 / 3-4 / 5+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 12, "summary": "Gain 3/4/5 Gold."},
	{"id": "candy_stash", "name": "Candy Stash", "icon": "C", "day": "1-3 / 4-6 / 7-9 / 10+", "min_day": 1, "max_day": 0, "rarity": "Bronze / Silver / Gold / Diamond", "weight": 8, "summary": "Get 3 Chocolate Bars."},
	{"id": "cinder_chase", "name": "Cinder Chase", "icon": "F", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get Cinders (+Burn)."},
	{"id": "extract_extract", "name": "Extract Extract", "icon": "P", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get an Extract (+Poison)."},
	{"id": "finns_big_bite", "name": "Finn's Big Bite", "icon": "H", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Gold", "weight": 5, "summary": "Eat at Finn's to get max Health."},
	{"id": "furnace", "name": "Furnace", "icon": "F", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a small Burn item."},
	{"id": "guard_locker", "name": "Guard Locker", "icon": "S", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a small Shield item."},
	{"id": "house_party", "name": "House Party", "icon": "F", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a small Friend."},
	{"id": "invest_in_yourself", "name": "Invest in Yourself", "icon": "$", "day": "1-3 / 3-6", "min_day": 1, "max_day": 6, "rarity": "Silver", "weight": 8, "summary": "Gain Income."},
	{"id": "jungle_ruins", "name": "Jungle Ruins", "icon": "R", "day": "1-2", "min_day": 1, "max_day": 2, "rarity": "Bronze", "weight": 8, "summary": "Mak can hunt for a Silver-tier Reagent."},
	{"id": "look_for_spare_change", "name": "Look for Spare Change", "icon": "$", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 10, "summary": "Get 3 Spare Change."},
	{"id": "lost_and_found", "name": "Lost and Found", "icon": "N", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 10, "summary": "Get a small non-Weapon item."},
	{"id": "medicine_cabinet", "name": "Medicine Cabinet", "icon": "H", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a small Heal or Regeneration item."},
	{"id": "obstacle_course", "name": "Obstacle Course", "icon": "S", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a Slow item."},
	{"id": "procure_medkit", "name": "Procure Medkit", "icon": "H", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a Med Kit (+Heal)."},
	{"id": "racetrack", "name": "Racetrack", "icon": "H", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a Haste item."},
	{"id": "regenerative_tincture", "name": "Regenerative Tincture", "icon": "R", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 10, "summary": "Gain Regeneration equal to your level."},
	{"id": "recycling_center", "name": "Recycling Center", "icon": "N", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a non-Weapon item."},
	{"id": "relax", "name": "Relax", "icon": "R", "day": "?-3+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 8, "summary": "Start your next fight with 100 Shield per Level."},
	{"id": "scrap_salvage", "name": "Scrap Salvage", "icon": "S", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a Scrap (+Shield)."},
	{"id": "sharpening_kit", "name": "Sharpening Kit", "icon": "W", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Get a Sharpening Stone (+Damage)."},
	{"id": "snack_time", "name": "Snack Time", "icon": "H", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Silver", "weight": 8, "summary": "Gain 20 Max Health per level."},
	{"id": "the_lost_crate", "name": "The Lost Crate", "icon": "B", "day": "1-5", "min_day": 1, "max_day": 5, "rarity": "Bronze", "weight": 8, "summary": "Open it for a Medium item or return it for a Skill."},
	{"id": "tiny_furry_monster", "name": "Tiny Furry Monster", "icon": "M", "day": "1-2", "min_day": 1, "max_day": 2, "rarity": "Bronze", "weight": 10, "summary": "Pet it for 25 Max Health."},
	{"id": "treasure_chest", "name": "Treasure Chest", "icon": "B", "day": "1+", "min_day": 1, "max_day": 0, "rarity": "Bronze", "weight": 10, "summary": "Get an item."},
]

const DAY1_MERCHANT_SPECS: Array[Dictionary] = [
	{"id": "aila", "name": "Aila", "type": "Weapon", "starting_tier": "Bronze", "day": "1+", "summary": "Sells Weapons."},
	{"id": "ande", "name": "Ande", "type": "Small", "starting_tier": "Bronze", "day": "1+", "summary": "Sells Small items."},
	{"id": "barkun", "name": "Barkun", "type": "Medium, Large", "starting_tier": "Silver", "day": "1+", "summary": "Sells Medium and Large items."},
	{"id": "colt", "name": "Colt", "type": "Ammo", "starting_tier": "Silver", "day": "1+", "summary": "Sells items with Ammo."},
	{"id": "curio", "name": "Curio", "type": "Bronze, Junk", "starting_tier": "Silver", "day": "1+", "summary": "Sells Bronze-tier Junk items."},
	{"id": "eli", "name": "Eli", "type": "Potion", "starting_tier": "Silver", "day": "1+", "summary": "Sells Potions."},
	{"id": "jay_jay", "name": "Jay Jay", "type": "Items", "starting_tier": "Bronze", "day": "1+", "summary": "Sells Items."},
	{"id": "kina", "name": "Kina", "type": "NonWeapon", "starting_tier": "Bronze", "day": "1+", "summary": "Sells non-Weapon items."},
	{"id": "midsworth", "name": "Midsworth", "type": "Small, Large", "starting_tier": "Silver", "day": "1+", "summary": "Sells Small and Large items."},
	{"id": "silvia", "name": "Silvia", "type": "Silver", "starting_tier": "Silver", "day": "1+", "summary": "Sells Silver-tier items."},
]

const MAK_BRONZE_ITEMS: Array[Dictionary] = [
	{"id": "aludel", "name": "Aludel", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [7.0], "tags": ["Poison", "Tool"], "poison": [4, 8, 12, 16], "effect": "Poison 4/8/12/16. +1 Multicast for each adjacent Potion or Reagent. At the start of each day, get a Catalyst."},
	{"id": "barbed_claws", "name": "Barbed Claws", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [6.0], "tags": ["Weapon", "Damage", "PoisonReference"], "damage": [5, 10, 20, 40], "effect": "Deal 5/10/20/40 Damage. +1 Multicast for each player with Poison."},
	{"id": "bottled_lightning", "name": "Bottled Lightning", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [6.0], "ammo": 1, "tags": ["Potion", "Weapon", "Ammo", "Burn", "Damage"], "damage": [20, 30, 40, 50], "burn": [2, 3, 4, 5], "crit": [100, 100, 100, 100], "effect": "Deal 20/30/40/50 Damage. Burn 2/3/4/5. 100% Crit Chance."},
	{"id": "calcinator", "name": "Calcinator", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [7.0], "tags": ["Tool", "Burn"], "burn": [6, 6, 6, 6], "effect": "Burn 6. When you transform a Reagent, this permanently gains +3/5/7/9 Burn. At the start of each day, spend 3 Gold to get a Chunk of Lead."},
	{"id": "candles", "name": "Candles", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [9.0], "tags": ["Burn"], "burn": [8, 12, 16, 20], "effect": "Burn 8/12/16/20. When you use a small item, Charge this 2 seconds."},
	{"id": "catalyst", "name": "Catalyst", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot"], "effect": "When you sell this, transform your leftmost item."},
	{"id": "emerald", "name": "Emerald", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [7.0], "tags": ["Poison", "Relic"], "poison": [1, 2, 3, 4], "effect": "Poison 1/2/3/4. Your other items have +3/4/5/6 Poison."},
	{"id": "fire_potion", "name": "Fire Potion", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [5.0], "ammo": 1, "tags": ["Potion", "Ammo", "Burn"], "burn": [6, 8, 10, 12], "effect": "Burn 6/8/10/12."},
	{"id": "fireflies", "name": "Fireflies", "size": "Small", "cost": [2, 4, 6, 8], "cooldown": [7.0], "tags": ["Friend", "Burn", "SlowReference"], "burn": [3, 4, 5, 6], "effect": "Burn 3/4/5/6. When you Slow, this gains 1/2/3/4 Burn for the fight."},
	{"id": "fungal_spores", "name": "Fungal Spores", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [5.0], "tags": ["PoisonReference"], "effect": "Your Poison items gain +2/3/4/5 Poison for the fight."},
	{"id": "hourglass", "name": "Hourglass", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Tool", "Cooldown"], "effect": "Adjacent items have their Cooldowns reduced by 3/6/9/12%."},
	{"id": "ice_claw", "name": "Ice Claw", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [9.0], "tags": ["Weapon", "Damage", "Freeze"], "damage": [40, 40, 40, 40], "freeze": [1, 2, 3, 4], "effect": "Deal 40 Damage. Freeze 1/2/3/4 items for 1 second. When you Freeze, this gains 20/30/40/50 Damage for the fight."},
	{"id": "incense", "name": "Incense", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [6.0], "tags": ["Slow", "Regen"], "slow": [1, 2, 3, 4], "regen": [2, 4, 6, 8], "effect": "Slow 1/2/3/4 item for 1 second. Gain 2/4/6/8 Regen for the fight."},
	{"id": "leeches", "name": "Leeches", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [8.0], "tags": ["Friend", "Weapon", "Damage", "PoisonReference", "Lifesteal"], "damage": [20, 20, 20, 20], "effect": "Deal 20 Damage. When you Poison, this gains 10/15/20/25 Damage for the fight. Lifesteal."},
	{"id": "letter_opener", "name": "Letter Opener", "size": "Small", "cost": [2, 4, 6, 8], "cooldown": [5.0], "tags": ["Tool", "Damage", "Weapon"], "damage": [10, 20, 30, 40], "crit": [100, 125, 150, 175], "effect": "Deal 10/20/30/40 Damage. This loses 25% Crit Chance for the fight. Crit Chance: 100/125/150/175%."},
	{"id": "magic_carpet", "name": "Magic Carpet", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [6.0], "tags": ["Vehicle", "Weapon", "Relic", "Damage"], "damage": [50, 100, 150, 200], "effect": "Deal 50/100/150/200 Damage. When you Crit, reduce this item's Cooldown by 1 second for the fight."},
	{"id": "mortar_pestle", "name": "Mortar & Pestle", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [7.0], "tags": ["Tool", "DamageReference"], "effect": "Your Lifesteal Weapons gain +10/15/20/25 Damage for the fight. The Weapon on the right has Lifesteal. At the start of each day, get a Catalyst."},
	{"id": "mothmeal", "name": "Mothmeal", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [5.0], "tags": ["Reagent", "Slow"], "slow": [1, 1, 1, 1], "slow_duration": [1, 2, 3, 4], "effect": "Slow 1 item for 1/2/3/4 seconds. When this is transformed, enchant it with Heavy if able."},
	{"id": "myrrh", "name": "Myrrh", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [6.0], "tags": ["Regen", "Reagent"], "regen": [1, 3, 5, 7], "effect": "Gain 1/3/5/7 Regen for the fight. When this is transformed, enchant it with Restorative if able."},
	{"id": "nightshade", "name": "Nightshade", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [6.0], "tags": ["HealReference", "Reagent", "Poison", "RegenReference"], "poison": [6, 6, 6, 6], "effect": "Poison 6. When you Heal or gain Regen, this gains 2/4/6/8 Poison for the fight. When this is transformed, enchant it with Toxic if able."},
	{"id": "noxious_potion", "name": "Noxious Potion", "size": "Small", "cost": [], "cooldown": [5.0], "ammo": 1, "tags": ["Potion", "Ammo", "Poison"], "poison": [3, 6, 9, 12], "effect": "Poison 3/6/9/12."},
	{"id": "optical_augment", "name": "Optical Augment", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Tool", "Poison", "Crit"], "effect": "At the start of each fight, Poison yourself 4/8/12/16. The item to the left has Crit Chance equal to your Poison."},
	{"id": "peacewrought", "name": "Peacewrought", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [8.0, 7.0, 6.0, 5.0], "tags": ["Relic", "Regen"], "regen": [2, 2, 2, 2], "effect": "Gain 2 Regen for the fight. When you visit a Merchant, destroy the item to the left to increase this Regen by its Value. When you destroy an item, gain 2/4/6/8 Gold."},
	{"id": "philosophers_stone", "name": "Philosopher's Stone", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [5.0], "tags": ["Regen", "Relic"], "regen": [1, 1, 1, 1], "effect": "Gain 1 Regen for the fight. When you transform a Reagent, this permanently gains +2/3/4/5 Regen. When you buy this, get a Catalyst."},
	{"id": "potion_potion", "name": "Potion Potion", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [2.0], "ammo": 1, "tags": ["Potion"], "effect": "Transform into 2 small Potions for the fight."},
	{"id": "quill_and_ink", "name": "Quill and Ink", "size": "Small", "cost": [4, 8, 16], "cooldown": [7.0], "tags": ["Poison", "Regen", "Tool"], "poison": [1, 2, 3, 4], "regen": [1, 2, 3, 4], "effect": "Poison 1/2/3/4. Gain 1/2/3/4 Regen for the fight. If you have no other Weapons, this has +1 Multicast."},
	{"id": "refractor", "name": "Refractor", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [6.0], "tags": ["Weapon", "Damage", "BurnReference", "FreezeReference", "PoisonReference", "SlowReference"], "damage": [20, 20, 20, 20], "effect": "Deal 20 Damage. When you Slow, Freeze, Burn or Poison, this gains 10/20/30/40 Damage for the fight."},
	{"id": "retort", "name": "Retort", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [6.0], "tags": ["Tool", "Poison"], "poison": [6, 6, 6, 6], "effect": "Poison 6. When you transform a Reagent, this permanently gains +3/5/7/9 Poison. At the start of each day, spend 3 Gold to get a Chunk of Lead."},
	{"id": "ruby", "name": "Ruby", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [10.0], "tags": ["Burn", "Relic"], "burn": [3, 6, 9, 12], "effect": "Burn 3/6/9/12. Your other Burn items have +3/4/5/6."},
	{"id": "smelling_salts", "name": "Smelling Salts", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [7.0], "tags": ["Slow", "Haste"], "slow": [1, 1, 1, 1], "slow_duration": [1, 2, 3, 4], "effect": "Slow 1 item for 1/2/3/4 seconds. When this or an adjacent item Slows, Haste the item to the left for 1/2/3/4 seconds."},
	{"id": "spider_mace", "name": "Spider Mace", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [10.0], "tags": ["Weapon", "Relic", "SlowReference", "Damage"], "damage": [10, 20, 30, 40], "effect": "Deal 10/20/30/40 Damage. When you Slow or Poison, Charge this 2 seconds."},
	{"id": "sulphur", "name": "Sulphur", "size": "Small", "cost": [6, 12, 24, 48], "cooldown": [7.0], "tags": ["Reagent", "Burn"], "burn": [2, 3, 4, 5], "effect": "Burn 2/3/4/5. When this is transformed, enchant it with Fiery if able."},
	{"id": "sword_cane", "name": "Sword Cane", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [4.0], "tags": ["Weapon", "Damage", "Regen", "Burn", "Poison"], "damage": [10, 15, 20, 25], "effect": "Deal 10/15/20/25 Damage. If adjacent to Regen/Burn/Poison items, gain 2/4/6/8 Regen, Burn 2/4/6/8, or Poison 2/4/6/8."},
	{"id": "tazidian_dagger", "name": "Tazidian Dagger", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [6.0], "tags": ["Weapon", "AmmoReference", "Damage", "Relic"], "damage": [5, 10, 15, 20], "effect": "Deal 5/10/15/20 Damage. The Potion to the left has +1/2/3/4 Ammo."},
	{"id": "venom", "name": "Venom", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Poison"], "effect": "When you use the Weapon to the left of this, Poison 2/3/4/5."},
	{"id": "venomander", "name": "Venomander", "size": "Small", "cost": [8, 16], "cooldown": [6.0], "tags": ["Friend", "Poison", "Regen"], "poison": [1, 2, 3, 4], "regen": [1, 2, 3, 4], "effect": "Poison 1/2/3/4. Gain 1/2/3/4 Regeneration for the fight."},
	{"id": "venomous_dose", "name": "Venomous Dose", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [4.0], "tags": ["Poison", "Regen"], "poison": [2, 4, 6, 8], "regen": [2, 4, 6, 8], "effect": "Poison both players 2/4/6/8. Gain Regen for the fight equal to this item's Poison."},
]

const MAK_ADDITIONAL_ITEMS: Array[Dictionary] = [
	{"id": "adrenal_converter", "name": "Adrenal Converter", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [6], "tags": ["Apparel", "Poison", "Regen", "Haste"], "poison": [5, 10, 15], "effect": "Poison both players 5/10/15. When you Poison yourself, gain 10/15/20 Regen for the fight and Haste 1 item for 1 second(s)."},
	{"id": "alembic", "name": "Alembic", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["Tool"], "effect": "At the start of each day, get a Catalyst and transform the small item to the left of this into a random Potion."},
	{"id": "amber", "name": "Amber", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [6], "tags": ["Slow", "Relic"], "slow": [1, 2, 3], "slow_duration": [3], "effect": "Slow 1/2/3 item for 3 seconds. Your other Slow items have +1 Slow."},
	{"id": "apothecary", "name": "Apothecary", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [6], "tags": ["Property", "Regen"], "regen": [5, 10, 15], "effect": "Gain 5/10/15 Regen for the fight. When you Haste, Slow, Poison, or Burn, Charge this 1 second(s). At the start of each day, get a Reagent or Catalyst."},
	{"id": "athanor", "name": "Athanor", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [5], "tags": ["Property", "AmmoReference", "Burn"], "effect": "Reload adjacent items. When you use a Potion, Burn 8/12/16. At the start of each day, get a small Potion. At the start of each day, get a Catalyst."},
	{"id": "basilisk_fang", "name": "Basilisk Fang", "size": "Small", "starting_tier": "Gold", "cost": [8, 16], "cooldown": [4], "tags": ["Weapon", "Crit", "Damage", "Relic", "Lifesteal"], "damage": [10, 20], "effect": "Deal 10/20 Damage. When your enemy has Poison, this has 50/100% Crit Chance. Lifesteal."},
	{"id": "black_ice", "name": "Black Ice", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [7], "tags": ["Freeze", "Poison"], "freeze": [1, 2, 3], "freeze_duration": [1], "effect": "Freeze 1/2/3 item(s) for 1 second. When you Freeze, Poison 6/8/10."},
	{"id": "black_rose", "name": "Black Rose", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [8], "tags": ["PoisonReference", "Regen"], "regen": [4], "effect": "Gain 4 Regen for the fight. When you Poison, this gains +1/2/3 Regen for the fight."},
	{"id": "boiling_flask", "name": "Boiling Flask", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [10, 9], "tags": ["Tool", "AmmoReference"], "effect": "Reload adjacent Potions. Adjacent Potions have +1 Multicast."},
	{"id": "bottled_explosion", "name": "Bottled Explosion", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [7], "ammo": [1], "tags": ["Potion", "Weapon", "Damage", "Ammo"], "damage": [5, 10, 15], "effect": "Deal 5/10/15 Damage. Double this item's Damage for the fight."},
	{"id": "bottled_tornado", "name": "Bottled Tornado", "size": "Small", "starting_tier": "Silver", "cost": [4, 6, 8], "cooldown": [7], "ammo": [1], "tags": ["Potion", "Ammo", "Slow"], "slow": [1, 2, 3], "slow_duration": [3], "effect": "The Sandstorm begins! Slow 1/2/3 item(s) for 3 second(s)."},
	{"id": "cauldron", "name": "Cauldron", "size": "Medium", "starting_tier": "Silver", "cost": [4, 8, 16, 32], "cooldown": [5], "tags": ["Tool", "Burn", "Poison"], "poison": [1, 2, 3], "burn": [1, 2, 3], "effect": "Burn 1/2/3 for each type this has. Poison 1/2/3 for each type this has. This has the Types of items you have."},
	{"id": "cellar", "name": "Cellar", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [4], "tags": ["Regen", "AmmoReference", "CritReference"], "regen": [2, 4, 6], "effect": "Reload an item. Gain 2/4/6 Regen for the fight."},
	{"id": "covetous_raven", "name": "Covetous Raven", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [8], "tags": ["Friend", "Weapon", "Damage"], "damage": [60, 80, 100], "effect": "Deal 60/80/100 Damage. When you use another Enchanted item, Charge this 2 second(s)."},
	{"id": "crocodile_tears", "name": "Crocodile Tears", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [13], "ammo": [1], "tags": ["Potion", "Weapon", "Damage", "Ammo"], "damage": [1], "effect": "Deal 1 Damage. When your enemy takes Damage, this gains 10/20/30 Damage for the fight."},
	{"id": "death_caps", "name": "Death Caps", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [5], "tags": ["Reagent", "Poison"], "poison": [2], "effect": "Poison 2. Your Poison items gain 2/4/6 Poison for the fight. When this is transformed, enchant it with Toxic if able."},
	{"id": "dragons_breath", "name": "Dragon's Breath", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [10], "ammo": [1], "tags": ["Burn", "Dragon", "Potion", "Ammo", "Relic"], "burn": [10], "effect": "Burn 10. When you use an adjacent item or Dragon item, this gains 6/8/10 Burn for the fight."},
	{"id": "earrings", "name": "Earrings", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [5], "tags": ["HasteReference", "Health", "Relic", "SlowReference"], "effect": "Gain 50/75/100 Max Health for the fight. When you Haste or Slow, Charge this 1 second(s)."},
	{"id": "energy_potion", "name": "Energy Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [6], "ammo": [1], "tags": ["Potion", "Ammo", "Haste"], "haste": [99, 99, 99], "haste_duration": [1, 2, 3], "effect": "Haste your other items for 1/2/3 second(s)."},
	{"id": "fire_claw", "name": "Fire Claw", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [7], "tags": ["Burn"], "burn": [6, 9, 12], "effect": "Burn 6/9/12. This has +Burn equal to 50/75/100% of the Burn of your other items."},
	{"id": "floor_spike", "name": "Floor Spike", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [9], "tags": ["Weapon", "Damage", "Poison"], "damage": [20, 40, 60], "poison": [2, 4, 6], "effect": "Deal 20/40/60 Damage. Poison 2/4/6. When either player uses a Weapon, Charge this 1 second(s)."},
	{"id": "frost_potion", "name": "Frost Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [6], "ammo": [1], "tags": ["Potion", "Ammo", "Freeze"], "freeze": [1, 2, 3], "freeze_duration": [1], "effect": "Freeze 1/2/3 item(s) for 1 seconds."},
	{"id": "frozen_flame", "name": "Frozen Flame", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [5], "tags": ["Burn", "Freeze", "Relic"], "burn": [8], "effect": "Burn 8. When you Freeze, this gains Burn 4/8/12 for the fight. The first time you fall below half health each fight, Freeze all enemy items for 1/2/3 seconds."},
	{"id": "goop_flail", "name": "Goop Flail", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [12, 11, 10], "tags": ["Weapon", "Damage", "Poison"], "damage": [1], "effect": "Deal 1 Damage. Poison equal to this item's Damage. Multicast: 3."},
	{"id": "hemlock", "name": "Hemlock", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [7], "tags": ["Reagent", "Poison"], "poison": [2, 3, 4, 5], "effect": "Poison 2/3/4/5. When this is transformed, enchant it with Toxic if able."},
	{"id": "infinite_potion", "name": "Infinite Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [4], "ammo": [1], "tags": ["Potion", "Regen", "Ammo"], "regen": [1, 2, 3], "effect": "Gain 1/2/3 Regen for the fight. Reload this."},
	{"id": "infused_bracers", "name": "Infused Bracers", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [5], "tags": ["Apparel", "Tool", "Poison", "DamageReference"], "poison": [5], "effect": "Poison both players 5. When you Poison yourself, your Weapons gain + Damage for the fight equal to 1/2 times the amount Poisoned. The Weapon to the left has Lifesteal."},
	{"id": "invulnerability_potion", "name": "Invulnerability Potion", "size": "Small", "starting_tier": "Gold", "cost": [8, 16], "cooldown": [10], "ammo": [1], "tags": ["Potion", "Ammo"], "effect": "You take no Damage for 1/2 second(s). The first time you fall below half health each fight, use this."},
	{"id": "laboratory", "name": "Laboratory", "size": "Large", "starting_tier": "Gold", "cost": [24, 48], "cooldown": [4], "tags": ["Property", "Charge"], "effect": "Enchant another non-enchanted item for the fight. Charge your other Relics and Enchanted items 1/2 second(s). At the start of each day, get a Catalyst."},
	{"id": "library", "name": "Library", "size": "Large", "starting_tier": "Gold", "cost": [24, 48], "tags": ["Property", "Cooldown"], "effect": "ALL Weapon Cooldowns are increased by +1/2 second(s). Your non-Weapon items' Cooldowns are decreased by 1 second(s)."},
	{"id": "magnus_femur", "name": "Magnus' Femur", "size": "Large", "starting_tier": "Silver", "cost": [24, 48], "cooldown": [17, 15, 13], "tags": ["Weapon", "Damage", "SlowReference", "Relic"], "damage": [300], "effect": "Deal 300 Damage. When you Slow, Charge this 2 second(s) and this gains 25/50/75 Damage for the fight."},
	{"id": "memento_mori", "name": "Memento Mori", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "effect": "The first time you would die each fight, Heal for 1 and take no damage for 1/2 second(s)."},
	{"id": "mirror", "name": "Mirror", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [4], "tags": ["Relic"], "effect": "Transform into a Gold/Diamond copy of the medium, non-legendary item to the left of this for the fight."},
	{"id": "oil_lantern", "name": "Oil Lantern", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [10, 9, 8], "tags": ["Tool", "Burn", "RegenReference"], "burn": [10], "effect": "Burn 10. When you gain Regen, Charge this 2 second(s)."},
	{"id": "ouroboros_statue", "name": "Ouroboros Statue", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [6], "tags": ["Poison", "Regen", "Relic"], "poison": [4, 6, 8], "effect": "Poison 4/6/8. When you Poison, gain 2/6/10 Regen for the fight."},
	{"id": "palanquin", "name": "Palanquin", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "tags": ["Vehicle"], "effect": "Your items have 15/30/50% Crit Chance. When you Crit with an item, reduce its Cooldown by 4/8/12% for the fight."},
	{"id": "pendulum", "name": "Pendulum", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "tags": ["Relic", "Charge"], "effect": "When you use an adjacent item, Charge the other adjacent item for 1/2 second(s)."},
	{"id": "plague_glaive", "name": "Plague Glaive", "size": "Large", "starting_tier": "Gold", "cost": [24, 48], "cooldown": [10], "tags": ["Weapon", "Damage", "PoisonReference", "Relic", "Lifesteal"], "damage": [100, 150], "effect": "Deal 100/150 Damage. Your Poison items have +10/15 Poison. For every 20 Poison on the enemy, this has +1 Multicast. Lifesteal."},
	{"id": "poppy_field", "name": "Poppy Field", "size": "Large", "starting_tier": "Silver", "cost": [12, 36, 48], "cooldown": [7], "tags": ["Property", "DamageReference", "Poison"], "poison": [4, 5, 6], "effect": "When you use a Weapon, Poison 4/5/6. Your Weapons have + Damage equal to 50/75/100% of the Poison on your enemy."},
	{"id": "potion_distillery", "name": "Potion Distillery", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "tags": ["Tool", "AmmoReference", "Cooldown"], "effect": "Your Potions have +1/2/3 Ammo. Your Potions have their Cooldowns reduced by 10/15/20%. When you visit a Merchant, transform the small item to the left of this into a random Potion."},
	{"id": "quicksilver", "name": "Quicksilver", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [3], "effect": "Transform into a Silver/Gold/Diamond copy of another small, non-legendary item you have for the fight."},
	{"id": "rainbow_potion", "name": "Rainbow Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [7], "ammo": [1], "tags": ["Potion", "Ammo", "Burn", "Freeze", "Poison", "Slow"], "poison": [3, 6, 9], "burn": [3, 6, 9], "slow": [1], "slow_duration": [2, 3, 4], "freeze": [1], "freeze_duration": [1, 2, 3], "effect": "Burn 3/6/9. Poison 3/6/9. Freeze 1 small item for 1/2/3 second(s). Slow 1 item for 2/3/4 seconds."},
	{"id": "rapid_injection_system", "name": "Rapid Injection System", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["Tool", "Poison", "Regen"], "effect": "When you Poison yourself, Poison 4/8/12. When you use an adjacent item, Poison yourself 4/8/12 and gain 2/4/6 Regen for the fight."},
	{"id": "recycling_bin", "name": "Recycling Bin", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["AmmoReference"], "effect": "When you use a Potion, transform it into another Potion for the fight. Your Potions have their Cooldowns reduced by 1"},
	{"id": "regeneration_potion", "name": "Regeneration Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [5], "ammo": [1], "tags": ["Potion", "Ammo", "Regen"], "regen": [8, 16, 24], "effect": "Gain 8/16/24 Regen for the fight."},
	{"id": "ritual_dagger", "name": "Ritual Dagger", "size": "Small", "starting_tier": "Gold", "cost": [8, 16], "cooldown": [9, 7], "tags": ["Weapon", "Damage", "Regen", "Relic"], "damage": [2], "effect": "Deal 2 Damage. Gain Regen for the fight equal to this item's Damage."},
	{"id": "runic_blade", "name": "Runic Blade", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [12, 10], "tags": ["Weapon", "Damage", "CritReference", "Relic", "Lifesteal"], "damage": [20], "effect": "Deal 20 Damage. When you Crit, double this item's Damage for the fight. Lifesteal."},
	{"id": "runic_daggers", "name": "Runic Daggers", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [6], "tags": ["Weapon", "Damage", "CritReference", "Relic", "Lifesteal"], "damage": [10, 15, 20], "effect": "Deal 10/15/20 Damage. When you Crit with another item, Charge this 1 second(s). Crit Chance 10%. Lifesteal. Multicast: 2"},
	{"id": "runic_double_bow", "name": "Runic Double Bow", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [7], "tags": ["Weapon", "Damage", "Relic", "Lifesteal"], "damage": [25, 35, 45], "effect": "Deal 25/35/45 Damage. This deals double Crit Chance Damage. Multicast: 2. Lifesteal"},
	{"id": "runic_great_axe", "name": "Runic Great Axe", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [11], "tags": ["Weapon", "Damage", "Relic", "Lifesteal"], "damage": [80, 120, 160], "effect": "Deal 80/120/160 Damage. Your Lifesteal Weapons have +100% Crit Chance. Lifesteal."},
	{"id": "runic_potion", "name": "Runic Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [4], "ammo": [1, 2, 3], "tags": ["Potion", "Haste", "Ammo"], "haste": [1], "haste_duration": [1], "effect": "Haste your Lifesteal Weapons for 1 second(s). A Weapon gains Lifesteal for the fight."},
	{"id": "sapphire", "name": "Sapphire", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [8], "tags": ["Freeze", "Relic"], "freeze": [1, 2, 3], "freeze_duration": [1], "effect": "Freeze 1/2/3 item(s) for 1 second(s). Your other Freeze items have +0.5 Freeze duration."},
	{"id": "satchel", "name": "Satchel", "size": "Medium", "starting_tier": "Silver", "cost": [4, 8, 16, 32], "cooldown": [8, 7, 6], "tags": ["Tool", "AmmoReference", "Regen"], "effect": "Reload 2 items. When you Reload, gain 2 Regen for the fight. When you buy a Potion, increase the Regen this item gives by +2/4/6."},
	{"id": "scales", "name": "Scales", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [5], "tags": ["Tool", "Charge"], "effect": "Charge adjacent items 1/2 second(s). If you have the same amount of items on both sides of this, Charge all other items instead."},
	{"id": "secret_formula", "name": "Secret Formula", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [10, 8], "tags": ["Regen", "BurnReference", "PoisonReference", "Relic"], "regen": [5, 10], "effect": "Gain 5/10 Regen for the fight. The Burn item to the left of this gains +Burn equal to your Regen for the fight. The Poison item to the right of this gains +Poison equal to your Regen for the fight."},
	{"id": "shard_of_obsidian", "name": "Shard of Obsidian", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [5], "tags": ["Weapon", "Reagent", "Damage", "Lifesteal"], "damage": [5, 10, 15, 20], "effect": "Deal 5/10/15/20 Damage. When this is transformed, enchant it with Obsidian if able. Lifesteal."},
	{"id": "show_globe", "name": "Show Globe", "size": "Medium", "starting_tier": "Silver", "cost": [4, 6, 8], "cooldown": [6], "tags": ["Regen", "Burn"], "burn": [3, 4, 5], "regen": [3, 4, 5], "effect": "Burn 3/4/5. Gain 3/4/5 Regeneration for the fight. When you use a Potion, your items gain +3/6/9 Burn and 3/6/9 Regeneration for the fight."},
	{"id": "shrinking_potion", "name": "Shrinking Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [8], "ammo": [1], "tags": ["Potion", "Ammo"], "effect": "Reduce your enemy's Max Health by 10/15/20% for the fight."},
	{"id": "sifting_pan", "name": "Sifting Pan", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["Tool", "Regen", "Value", "EconomyReference"], "effect": "At the start of each day, get a Catalyst. When you sell a Catalyst, gain 1/2/3 Regen."},
	{"id": "sleeping_potion", "name": "Sleeping Potion", "size": "Small", "starting_tier": "Bronze", "cost": [2, 4, 8, 16], "cooldown": [4], "ammo": [1], "tags": ["Potion", "Slow"], "slow": [1], "slow_duration": [3, 4, 5, 6], "effect": "Slow the slowest enemy item for 3/4/5/6 second(s)."},
	{"id": "soul_ring", "name": "Soul Ring", "size": "Small", "starting_tier": "Gold", "cost": [4, 8, 16], "cooldown": [10], "tags": ["Poison", "Regen", "Apparel", "Relic"], "effect": "Poison equal to your Regen. You have +10/20 Regen."},
	{"id": "staff_of_the_moose", "name": "Staff of the Moose", "size": "Large", "starting_tier": "Gold", "cost": [24, 48], "cooldown": [10], "tags": ["Weapon", "Regen", "Damage", "Relic"], "damage": [200], "effect": "Deal 200 Damage. The first time you fall below half Health each fight, take no Damage for 1/2 second(s) and gain 25/50 Regen for the fight. Your Weapons have +Damage equal to your Regen. Multicast: 2"},
	{"id": "strength_potion", "name": "Strength Potion", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [6], "ammo": [1], "tags": ["Potion", "Crit", "Ammo"], "effect": "Your items gain 100% Crit Chance for 3/4/5 seconds."},
	{"id": "sunlight_spear", "name": "Sunlight Spear", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [12, 11, 10], "tags": ["Burn", "Weapon", "Relic", "Regen", "Damage"], "effect": "Burn equal to your Regeneration. Deal Damage equal to the Regeneration plus the Burn on both players. You have +4/8/12 Regeneration."},
	{"id": "test_subject_alpha", "name": "Test Subject Alpha", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [9, 7, 5], "tags": ["Weapon", "Friend", "Damage", "Poison"], "damage": [50], "effect": "Deal 50 Damage. When you use an adjacent item, Poison both players 15/30/45. When you Poison, this gains +Damage for the fight equal to the amount Poisoned."},
	{"id": "the_tome_of_yyahan", "name": "The Tome of Yyahan", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "effect": "When you transform a Reagent, permanently gain 4/10/15 Regen. At the start of each day, get a Small Reagent"},
	{"id": "thrown_net", "name": "Thrown Net", "size": "Medium", "starting_tier": "Gold", "cost": [8, 16, 32], "cooldown": [5], "tags": ["Slow"], "slow": [1], "slow_duration": [2, 3], "effect": "Slow 1 item for 2/3 second(s). This has +1 Multicast for each Weapon or Friend your enemy has."},
	{"id": "thurible", "name": "Thurible", "size": "Small", "starting_tier": "Silver", "cost": [4, 8, 16], "cooldown": [6], "tags": ["Tool", "Burn", "Regen", "Relic"], "burn": [4, 6, 8, 10], "regen": [1, 2, 3, 4], "effect": "Burn 4/6/8/10. Gain 1/2/3/4 Regeneration for the fight."},
	{"id": "vat_of_acid", "name": "Vat of Acid", "size": "Large", "starting_tier": "Silver", "cost": [12, 24, 48], "cooldown": [7], "tags": ["Poison", "Burn"], "poison": [3, 6, 9], "burn": [3, 6, 9], "effect": "Poison 3/6/9 for each type this has. Burn 3/6/9 for each type this has. When you sell an item, this gains that item's type(s)."},
	{"id": "vial_launcher", "name": "Vial Launcher", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["Weapon", "Tool", "Damage"], "effect": "When you use a Potion, deal 15/30/45 Damage. When you Reload or transform a Potion, this gains +15/30/45 Damage for the fight."},
	{"id": "viper_cane", "name": "Viper Cane", "size": "Medium", "starting_tier": "Gold", "cost": [16, 32], "cooldown": [7], "tags": ["Weapon", "Damage", "PoisonReference", "RegenReference"], "damage": [25], "effect": "Deal 25 Damage. A Poison item gains +Poison equal to 15/25% this item's Damage for the fight. A Regen item gains +Regen equal to 15/25% this item's Damage for the fight."},
	{"id": "vitality_potion", "name": "Vitality Potion", "size": "Small", "starting_tier": "Gold", "cost": [8, 16], "cooldown": [11], "ammo": [1], "tags": ["Potion", "Heal", "Ammo", "Health"], "effect": "Heal equal to 50/100% of your Max Health."},
	{"id": "weaselpede", "name": "Weaselpede", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "cooldown": [6], "tags": ["Freeze", "PoisonReference", "Friend"], "freeze": [1], "freeze_duration": [1, 2, 3], "effect": "Freeze 1 item(s) for 1/2/3 second(s). While your enemy has Poison, this has +1 Multicast."},
	{"id": "wild_quillback", "name": "Wild Quillback", "size": "Medium", "starting_tier": "Silver", "cost": [8, 16, 32], "tags": ["Friend", "Poison", "Regen", "WeaponReference"], "effect": "When a player uses a Weapon, Poison that player 3/4/5. When you use a non-Weapon item, gain 3/4/5 Regen for the fight."},
]

const SHARED_ITEM_SPECS: Array[Dictionary] = [
	{"id": "bluenanas", "name": "Bluenanas", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [10.0], "tags": ["Food", "Heal", "Health"], "heal": [10, 20, 40, 80], "effect": "Heal 10/20/40/80. When you sell this, gain 20/60/120/200 Max Health."},
	{"id": "chocolate_bar", "name": "Chocolate Bar", "size": "Small", "cost": [2, 4, 6, 8], "cooldown": [], "tags": ["Food", "Health"], "effect": "When you sell this, gain 10/20/30/40 Max Health."},
	{"id": "cinders", "name": "Cinders", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "BurnReference", "Junk"], "effect": "When you sell this, your leftmost Burn item gains +1/2/3/4 Burn."},
	{"id": "duct_tape", "name": "Duct Tape", "size": "Small", "cost": [4, 8, 16], "cooldown": [6.0], "tags": ["Tool", "Shield", "Slow"], "shield": [5, 10, 15, 15], "slow": [1, 1, 1, 1], "slow_duration": [1, 2, 3, 3], "effect": "Slow 1 item for 1/2/3 seconds. When you use the item to the left, Shield 5/10/15."},
	{"id": "eagle_talisman", "name": "Eagle Talisman", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "Crit"], "effect": "When you sell this, give your leftmost item 5/10/15/20% Crit Chance."},
	{"id": "extract", "name": "Extract", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "PoisonReference"], "effect": "When you sell this, your leftmost Poison item gains +1/2/3/4 Poison."},
	{"id": "fang", "name": "Fang", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [3.0], "tags": ["Weapon", "Damage"], "damage": [5, 10, 15, 20], "effect": "Deal 5/10/15/20 Damage."},
	{"id": "gland", "name": "Gland", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "Regen"], "effect": "When you sell this, gain 1/2/3/4 Regen."},
	{"id": "insect_wing", "name": "Insect Wing", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "Cooldown"], "effect": "When you sell this, reduce your items' Cooldowns by 3/6/9%."},
	{"id": "langxian", "name": "Langxian", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [10.0], "tags": ["Weapon", "Damage"], "damage": [40, 40, 40, 40], "effect": "Deal 40 Damage. When you win with Langxian in play, this gains 40/60/80/100 Damage."},
	{"id": "lighter", "name": "Lighter", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [4.0], "tags": ["Tool", "Burn"], "burn": [2, 4, 6, 8], "effect": "Burn 2/4/6/8."},
	{"id": "med_kit", "name": "Med Kit", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["HealReference"], "effect": "When you sell this, your leftmost Heal item gains 5/10/20/40 Heal."},
	{"id": "pelt", "name": "Pelt", "size": "Small", "cost": [], "cooldown": [], "tags": ["Loot"], "effect": "Sells for gold. (2/4/6/8 Gold)."},
	{"id": "scrap", "name": "Scrap", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [], "tags": ["Loot", "ShieldReference"], "effect": "When you sell this, give your leftmost Shield item +3/6/12/24 Shield."},
	{"id": "silk_scarf", "name": "Silk Scarf", "size": "Medium", "cost": [4, 8, 16, 32], "cooldown": [8.0], "tags": ["Apparel", "Shield"], "shield": [10, 20, 40, 80], "effect": "Shield 10/20/40/80. When you sell another non-Weapon, this gains +6/12/18/24 Shield."},
	{"id": "stinger", "name": "Stinger", "size": "Small", "cost": [2, 4, 8, 16], "cooldown": [7.0], "tags": ["Weapon", "Damage", "Slow", "Lifesteal"], "damage": [5, 10, 20, 40], "slow": [1, 2, 3, 4], "effect": "Deal 5/10/20/40 Damage. Slow 1/2/3/4 item for 1 second. Lifesteal."},
]

const DAY1_MONSTER_SPECS: Array[Dictionary] = [
	{"id": "banannabal", "name": "Banannabal", "tier": "Bronze", "level": 1, "health": 100, "gold": 2, "xp": 2, "skills": [{"name": "Overheal Haste", "effect": "The first time you Over-Heal each fight, Haste your items for 2/4 seconds."}], "items": [{"id": "med_kit"}, {"id": "bluenanas"}, {"id": "duct_tape", "rarity": 2}]},
	{"id": "fanged_inglet", "name": "Fanged Inglet", "tier": "Bronze", "level": 1, "health": 100, "gold": 2, "xp": 2, "skills": [{"name": "Deadly Eye", "effect": "Weapons have +5/10/15/20% Crit Chance."}], "items": [{"id": "pelt"}, {"id": "fang"}]},
	{"id": "haunted_kimono", "name": "Haunted Kimono", "tier": "Bronze", "level": 1, "health": 100, "gold": 2, "xp": 2, "skills": [{"name": "Haunting Flight", "effect": "The first time you use an item each fight, 1/2/3 Small items start Flying."}], "items": [{"id": "scrap"}, {"id": "silk_scarf"}]},
	{"id": "kyver_drone", "name": "Kyver Drone", "tier": "Bronze", "level": 1, "health": 100, "gold": 2, "xp": 2, "skills": [{"name": "Trained", "effect": "When you Slow, a Weapon gains +5/10/15/20 Damage for the fight."}], "items": [{"id": "insect_wing", "rarity": 2}, {"id": "stinger"}, {"id": "langxian"}, {"id": "eagle_talisman"}]},
	{"id": "pyro", "name": "Pyro", "tier": "Bronze", "level": 1, "health": 100, "gold": 2, "xp": 2, "skills": [{"name": "Fiery", "effect": "Burn items have +1/2/3/4 Burn.", "burn_bonus": 1}], "items": [{"id": "cinders"}, {"id": "lighter"}]},
	{"id": "viper", "name": "Viper", "tier": "Silver", "level": 1, "health": 75, "gold": 3, "xp": 2, "skills": [{"name": "Lash Out", "effect": "At the start of each fight, Poison 3/6/9/12.", "start_poison": 3}], "items": [{"id": "gland"}, {"id": "fang"}, {"id": "extract"}]},
]

static func create_mak_hero() -> HeroDataClass:
	return create_bazaar_hero(HeroDataClass.HeroType.MAK)

static func create_bazaar_hero(hero_type: HeroDataClass.HeroType) -> HeroDataClass:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return null
	var hero: HeroDataClass = HeroDataClass.new()
	hero.hero_name = str(profile.get("name", "Hero"))
	hero.hero_type = hero_type
	hero.max_hp = int(profile.get("max_hp", 100))
	hero.current_hp = hero.max_hp
	hero.crit_chance = float(profile.get("crit", 0.05))
	hero.available_items = get_hero_item_ids(hero_type)
	hero.skills = _string_array(profile.get("skills", []))
	for passive_spec in profile.get("passives", []):
		if passive_spec is Dictionary:
			hero.passive_skills.append(_create_passive_skill(passive_spec as Dictionary))
	return hero

static func get_hero_profile_specs() -> Array[Dictionary]:
	return HERO_PROFILE_SPECS.duplicate(true)

static func get_hero_profile_spec(hero_type: HeroDataClass.HeroType) -> Dictionary:
	for profile in HERO_PROFILE_SPECS:
		if int(profile.get("type", -1)) == int(hero_type):
			return profile.duplicate(true)
	return {}

static func get_hero_starter_skill_ids(hero_type: HeroDataClass.HeroType) -> Array[String]:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return []
	return _string_array(profile.get("skills", []))

static func get_hero_archetypes(hero_type: HeroDataClass.HeroType) -> Array[Dictionary]:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return []
	var hero_id: String = str(profile.get("id", ""))
	var archetypes: Array[Dictionary] = []
	for archetype in HERO_ARCHETYPE_SPECS.get(hero_id, []):
		if archetype is Dictionary:
			archetypes.append((archetype as Dictionary).duplicate(true))
	return archetypes

static func get_hero_identity_summary(hero_type: HeroDataClass.HeroType) -> Dictionary:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return {}
	return {
		"id": str(profile.get("id", "")),
		"name": str(profile.get("name", "")),
		"collection": str(profile.get("collection", "")),
		"starter_skills": get_hero_starter_skill_ids(hero_type),
		"item_ids": get_hero_item_ids(hero_type),
		"archetypes": get_hero_archetypes(hero_type),
		"art_path": get_hero_art_path(hero_type),
		"pool_note": str(profile.get("pool_note", "")),
	}

static func get_hero_art_path(hero_type: HeroDataClass.HeroType) -> String:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	return _get_wiki_art_path("heroes", str(profile.get("id", "")))

static func apply_phase1_player_skill_loadout(hero: HeroDataClass) -> void:
	if hero == null:
		return
	var profile: Dictionary = get_hero_profile_spec(hero.hero_type)
	if not profile.is_empty():
		hero.skills = _string_array(profile.get("skills", []))

static func get_mak_item_ids() -> Array[String]:
	return get_hero_item_ids(HeroDataClass.HeroType.MAK)

static func get_mak_item_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	specs.append_array(MAK_BRONZE_ITEMS)
	specs.append_array(MAK_ADDITIONAL_ITEMS)
	return specs

static func get_hero_item_ids(hero_type: HeroDataClass.HeroType) -> Array[String]:
	var ids: Array[String] = []
	for spec in get_hero_item_specs(hero_type):
		var item_id: String = str(spec.get("id", ""))
		if not item_id.is_empty() and not ids.has(item_id):
			ids.append(item_id)
	return ids

static func get_hero_item_specs(hero_type: HeroDataClass.HeroType) -> Array[Dictionary]:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return []
	var collection_name: String = str(profile.get("collection", ""))
	var specs: Array[Dictionary] = []
	if hero_type == HeroDataClass.HeroType.MAK:
		specs.append_array(get_mak_item_specs())
	if hero_type == HeroDataClass.HeroType.KARNOK:
		specs.append_array(KARNOK_BAZAARDB_ITEMS)
	for spec in WikiMonsterCatalogClass.get_item_specs_for_collection(collection_name):
		var item_id: String = str(spec.get("id", ""))
		var duplicate: bool = false
		for existing in specs:
			if str(existing.get("id", "")) == item_id:
				duplicate = true
				break
		if not duplicate:
			specs.append(spec)
	return specs

static func get_reachable_item_effect_coverage_report() -> Dictionary:
	var ids: Dictionary = {}
	var sources: Dictionary = {}
	for profile in HERO_PROFILE_SPECS:
		var hero_type: HeroDataClass.HeroType = profile.get("type", HeroDataClass.HeroType.MAK)
		for spec in get_hero_item_specs(hero_type):
			_add_reachable_item_source(spec, "hero:%s" % str(profile.get("id", "hero")), ids, sources)
	for monster_spec in WikiMonsterCatalogClass.get_monster_specs():
		for item_entry in _get_monster_item_entries(monster_spec):
			var item_id: String = str(item_entry.get("id", ""))
			if not item_id.is_empty():
				_add_reachable_item_id(item_id, "monster:%s" % str(monster_spec.get("id", "monster")), ids, sources)
		for reward_entry in _get_monster_reward_item_pool(monster_spec):
			var reward_item_id: String = str(reward_entry.get("id", ""))
			if not reward_item_id.is_empty():
				_add_reachable_item_id(reward_item_id, "monster_reward:%s" % str(monster_spec.get("id", "monster")), ids, sources)
	for item_id in REACHABLE_EXTRA_REWARD_ITEM_IDS:
		_add_reachable_item_id(item_id, "event_reward", ids, sources)

	var warning_items: Array[Dictionary] = []
	var warning_family_counts: Dictionary = {}
	var unknown_item_ids: Array[String] = []
	var unknown_warning_families: Array[String] = []
	var warning_total: int = 0
	var implemented_total: int = 0
	var sorted_item_ids: Array = ids.keys()
	sorted_item_ids.sort()
	for item_id in sorted_item_ids:
		var item: ItemDataClass = create_item(str(item_id), RARITY_BRONZE)
		if item == null:
			unknown_item_ids.append(str(item_id))
			continue
		if item.effect_warnings.is_empty():
			implemented_total += 1
			continue
		var warning_entries: Array[Dictionary] = []
		for warning in item.effect_warnings:
			var warning_text: String = str(warning)
			warning_total += 1
			var family_key: String = _item_warning_family_key(warning_text)
			warning_family_counts[family_key] = int(warning_family_counts.get(family_key, 0)) + 1
			if not EffectDefinitionClass.is_known_item_warning_family(warning_text) and not unknown_warning_families.has(family_key):
				unknown_warning_families.append(family_key)
			warning_entries.append({
				"warning": warning_text,
				"reason": EffectDefinitionClass.get_item_warning_reason(item, warning_text),
			})
		warning_items.append({
			"id": item.source_id,
			"name": item.item_name,
			"sources": _sorted_string_array(sources.get(item.source_id, [])),
			"warnings": warning_entries,
		})
	unknown_item_ids.sort()
	unknown_warning_families.sort()
	return {
		"total_item_ids": ids.size(),
		"implemented_item_total": implemented_total,
		"warning_item_total": warning_items.size(),
		"warning_entry_total": warning_total,
		"warning_family_counts": warning_family_counts,
		"warning_items": warning_items,
		"unknown_item_total": unknown_item_ids.size(),
		"unknown_items": unknown_item_ids,
		"unknown_effect_categories": unknown_warning_families,
	}

static func _item_warning_family_key(warning: String) -> String:
	var parts: PackedStringArray = warning.split(":")
	if parts.size() >= 3:
		return "%s:%s" % [parts[0], parts[2]]
	return warning

static func _add_reachable_item_source(spec: Dictionary, source: String, ids: Dictionary, sources: Dictionary) -> void:
	var item_id: String = str(spec.get("id", ""))
	if item_id.is_empty():
		return
	_add_reachable_item_id(item_id, source, ids, sources)

static func _add_reachable_item_id(item_id: String, source: String, ids: Dictionary, sources: Dictionary) -> void:
	if item_id.is_empty():
		return
	ids[item_id] = true
	var source_list: Array = sources.get(item_id, [])
	if not source_list.has(source):
		source_list.append(source)
	sources[item_id] = source_list

static func _sorted_string_array(values: Array) -> Array[String]:
	var sorted: Array[String] = []
	for value in values:
		sorted.append(str(value))
	sorted.sort()
	return sorted

static func get_hero_skill_ids(hero_type: HeroDataClass.HeroType) -> Array[String]:
	var ids: Array[String] = []
	for spec in get_hero_skill_specs(hero_type):
		var skill_id: String = str(spec.get("id", ""))
		if not skill_id.is_empty() and not ids.has(skill_id):
			ids.append(skill_id)
	return ids

static func get_hero_skill_specs(hero_type: HeroDataClass.HeroType) -> Array[Dictionary]:
	var profile: Dictionary = get_hero_profile_spec(hero_type)
	if profile.is_empty():
		return []
	return WikiMonsterCatalogClass.get_skill_specs_for_collection(str(profile.get("collection", "")))

static func get_day1_events() -> Array[Dictionary]:
	return get_event_specs_for_day(1)

static func get_all_event_specs() -> Array[Dictionary]:
	return WikiEventCatalogClass.get_event_specs()

static func get_event_specs_for_day(day: int) -> Array[Dictionary]:
	return WikiEventCatalogClass.get_event_specs_for_day(day)

static func find_event_spec(event_id: String) -> Dictionary:
	return WikiEventCatalogClass.find_event_spec(event_id)

static func get_day1_merchants() -> Array[Dictionary]:
	return DAY1_MERCHANT_SPECS.duplicate(true)

static func get_event_art_path(event_id: String) -> String:
	return _get_wiki_art_path("events", event_id)

static func get_merchant_art_path(merchant_id: String) -> String:
	return _get_wiki_art_path("merchants", merchant_id)

static func get_day1_monster_specs() -> Array[Dictionary]:
	return get_monster_specs_for_level(1)

static func get_all_monster_specs() -> Array[Dictionary]:
	return WikiMonsterCatalogClass.get_monster_specs()

static func get_monster_specs_for_level(level: int) -> Array[Dictionary]:
	if level == 1:
		return DAY1_MONSTER_SPECS.duplicate(true)
	var specs: Array[Dictionary] = WikiMonsterCatalogClass.get_monster_specs_for_level(level)
	if not specs.is_empty():
		return specs
	return []

static func get_monster_specs_for_day(day: int) -> Array[Dictionary]:
	return get_monster_specs_for_level(maxi(day, 1))

static func get_top_monster_special_ids(limit: int = 30) -> Array[String]:
	return TOP_MONSTER_SPECIAL_IDS.slice(0, clampi(limit, 0, TOP_MONSTER_SPECIAL_IDS.size())).duplicate()

static func get_monster_encounter_metadata(monster_id: String, day: int = 1) -> Dictionary:
	var spec: Dictionary = WikiMonsterCatalogClass.find_monster_spec(monster_id)
	if spec.is_empty():
		for candidate in DAY1_MONSTER_SPECS:
			if str(candidate.get("id", "")) == monster_id:
				spec = candidate
				break
	if spec.is_empty():
		return {}
	return _build_monster_encounter_metadata(spec, day)

static func get_top_monster_special_report(limit: int = 30) -> Dictionary:
	var monster_ids: Array[String] = get_top_monster_special_ids(limit)
	var specs: Array[Dictionary] = []
	for monster_id in monster_ids:
		var spec: Dictionary = WikiMonsterCatalogClass.find_monster_spec(monster_id)
		if spec.is_empty():
			for candidate in DAY1_MONSTER_SPECS:
				if str(candidate.get("id", "")) == monster_id:
					spec = candidate
					break
		specs.append(spec)
	var report: Dictionary = _build_monster_parity_report(specs, "first 30 leveled monsters by wiki/day curve order", "tests/test_monster_specials.gd")
	report["requested_limit"] = limit
	return report

static func get_all_monster_parity_report() -> Dictionary:
	return _build_monster_parity_report(get_all_monster_specs(), "all 101 wiki catalog monsters", "tests/test_full_content_parity_p1e_monster_report.gd")

static func create_random_mak_day1_item(rarity: int = RARITY_BRONZE, required_size: String = "", required_tag: String = "", buyable_only: bool = true) -> ItemDataClass:
	return create_random_hero_item(HeroDataClass.HeroType.MAK, rarity, required_size, required_tag, buyable_only)

static func create_random_hero_item(hero_type: HeroDataClass.HeroType, rarity: int = RARITY_BRONZE, required_size: String = "", required_tag: String = "", buyable_only: bool = true) -> ItemDataClass:
	var candidates: Array[Dictionary] = []
	var target_rarity: int = clampi(rarity, RARITY_BRONZE, RARITY_DIAMOND)
	for spec in get_hero_item_specs(hero_type):
		if _get_spec_start_rarity(spec) > target_rarity:
			continue
		if buyable_only and (spec.get("cost", []) as Array).is_empty():
			continue
		if not required_size.is_empty() and str(spec.get("size", "")) != required_size:
			continue
		if not required_tag.is_empty() and not _spec_has_tag(spec, required_tag):
			continue
		candidates.append(spec)
	if candidates.is_empty():
		return null
	return create_item_from_spec(candidates.pick_random(), target_rarity)

static func create_random_mak_day1_shop_item(max_rarity: int = RARITY_BRONZE, owned_items: Array = [], required_size: String = "", required_tag: String = "") -> ItemDataClass:
	return create_random_hero_shop_item(HeroDataClass.HeroType.MAK, max_rarity, owned_items, required_size, required_tag)

static func create_random_hero_shop_item(hero_type: HeroDataClass.HeroType, max_rarity: int = RARITY_BRONZE, owned_items: Array = [], required_size: String = "", required_tag: String = "") -> ItemDataClass:
	var candidates: Array[Dictionary] = []
	var safe_max_rarity: int = clampi(max_rarity, RARITY_BRONZE, RARITY_DIAMOND)
	for spec in get_hero_item_specs(hero_type):
		if (spec.get("cost", []) as Array).is_empty():
			continue
		var start_rarity: int = _get_spec_start_rarity(spec)
		if start_rarity > safe_max_rarity:
			continue
		if not required_size.is_empty() and str(spec.get("size", "")) != required_size:
			continue
		if not required_tag.is_empty() and not _spec_has_tag(spec, required_tag):
			continue
		var item_id: String = str(spec.get("id", ""))
		if item_id == "catalyst":
			continue  # catalyst只能由其他道具生成，不能在商店购买
		for rarity in range(start_rarity, safe_max_rarity + 1):
			if _shop_candidate_allowed(item_id, rarity, owned_items):
				candidates.append({"spec": spec, "rarity": rarity})
	if candidates.is_empty():
		return null
	var choice: Dictionary = candidates.pick_random()
	return create_item_from_spec(choice.get("spec", {}), int(choice.get("rarity", RARITY_BRONZE)))

static func is_shop_candidate_allowed(item_id: String, rarity: int, owned_items: Array) -> bool:
	return _shop_candidate_allowed(item_id, rarity, owned_items)

static func _get_wiki_art_path(category: String, source_id: String) -> String:
	var clean_id: String = source_id.strip_edges().to_lower().replace(" ", "_")
	if clean_id.is_empty():
		return ""
	for extension in [".png", ".jpg", ".jpeg", ".webp"]:
		var texture_path: String = "res://assets/art/%s/wiki/%s%s" % [category, clean_id, extension]
		if ResourceLoader.exists(texture_path) or FileAccess.file_exists(texture_path):
			return texture_path
	return ""

static func create_item(
	item_id: String,
	rarity: int = RARITY_BRONZE,
	enchantment: String = ""
) -> ItemDataClass:
	var spec: Dictionary = _find_item_spec(item_id)
	if spec.is_empty():
		return null
	return create_item_from_spec(spec, rarity, enchantment)

static func create_item_from_spec(
	spec: Dictionary,
	rarity: int = RARITY_BRONZE,
	enchantment: String = ""
) -> ItemDataClass:
	var item: ItemDataClass = ItemDataClass.new()
	_apply_spec_to_item(item, spec, rarity, enchantment)
	return item

static func apply_rarity_to_item(item: ItemDataClass, rarity: int) -> bool:
	if item == null:
		return false
	var spec: Dictionary = _find_item_spec(item.source_id)
	var previous_enchantment: String = item.enchantment_id
	if spec.is_empty():
		item.rarity = clampi(rarity, RARITY_BRONZE, RARITY_DIAMOND)
		return false
	var previous_slot: int = item.slot_index
	var previous_cooldown: float = item.current_cooldown
	_apply_spec_to_item(item, spec, rarity, previous_enchantment)
	item.slot_index = previous_slot
	item.current_cooldown = previous_cooldown
	item.clear_runtime_ammo()
	return true

static func _apply_spec_to_item(
	item: ItemDataClass,
	spec: Dictionary,
	rarity: int,
	enchantment: String = ""
) -> void:
	var item_rarity: int = clampi(rarity, RARITY_BRONZE, RARITY_DIAMOND)
	item.source_id = str(spec.get("id", ""))
	item.item_name = str(spec.get("name", "Item"))
	item.base_item_name = item.item_name
	item.description = str(spec.get("effect", ""))
	item.source_effect_text = item.description
	item.enchantment_id = ""
	item.tags = _string_array(spec.get("tags", []))
	item.rarity = item_rarity
	item.size = _size_to_enum(str(spec.get("size", "Small")))
	item.type = _tags_to_item_type(item.tags)
	var start_rarity: int = _get_spec_start_rarity(spec)
	var raw_ammo: Variant = spec.get("ammo", 0)
	var ammo_fallback: int = int(raw_ammo) if raw_ammo is int or raw_ammo is float else 0
	item.buy_price = _get_int_for_rarity(spec.get("cost", []), item_rarity, 0, start_rarity)
	item.cooldown = _get_float_for_rarity(spec.get("cooldown", []), item_rarity, 0.0, start_rarity)
	item.ammo = _get_int_for_rarity(raw_ammo, item_rarity, ammo_fallback, start_rarity)
	item.damage = _get_int_for_rarity(spec.get("damage", []), item_rarity, 0, start_rarity)
	item.shield = _get_int_for_rarity(spec.get("shield", []), item_rarity, 0, start_rarity)
	item.heal = _get_int_for_rarity(spec.get("heal", []), item_rarity, 0, start_rarity)
	item.poison_damage = float(_get_int_for_rarity(spec.get("poison", []), item_rarity, 0, start_rarity))
	item.burn_damage = float(_get_int_for_rarity(spec.get("burn", []), item_rarity, 0, start_rarity))
	item.regeneration = float(_get_int_for_rarity(spec.get("regen", []), item_rarity, 0, start_rarity))
	item.stun_duration = float(_get_float_for_rarity(spec.get("freeze_duration", []), item_rarity, 0.0, start_rarity))
	item.slow_count = _get_int_for_rarity(spec.get("slow", []), item_rarity, 0, start_rarity)
	item.slow_duration = _get_float_for_rarity(spec.get("slow_duration", []), item_rarity, _default_tempo_duration(item.slow_count), start_rarity)
	item.freeze_count = _get_int_for_rarity(spec.get("freeze", []), item_rarity, 0, start_rarity)
	item.freeze_duration = _get_float_for_rarity(spec.get("freeze_duration", []), item_rarity, _default_tempo_duration(item.freeze_count), start_rarity)
	item.haste_count = _get_int_for_rarity(spec.get("haste", []), item_rarity, 0, start_rarity)
	item.haste_duration = _get_float_for_rarity(spec.get("haste_duration", []), item_rarity, _default_tempo_duration(item.haste_count), start_rarity)
	item.crit_chance = float(_get_int_for_rarity(spec.get("crit", []), item_rarity, 0, start_rarity)) / 100.0
	if enchantment.is_empty():
		item.effects = EffectDefinitionClass.build_item_effects(item)
		item.effect_warnings = EffectDefinitionClass.collect_item_warnings(item, item.effects)
	else:
		EnchantmentCatalogClass.apply_to_item(item, enchantment)
	item.current_cooldown = 0.0

static func create_day1_monster(monster_id: String = "") -> MonsterDataClass:
	return create_monster(monster_id, 1)

static func create_monster(monster_id: String = "", level: int = 1) -> MonsterDataClass:
	var spec: Dictionary = {}
	if monster_id.is_empty():
		var candidates: Array[Dictionary] = get_monster_specs_for_level(maxi(level, 1))
		if candidates.is_empty():
			candidates = get_day1_monster_specs()
		if candidates.is_empty():
			return null
		spec = candidates.pick_random()
	else:
		if level == 1:
			for candidate in DAY1_MONSTER_SPECS:
				if str(candidate.get("id", "")) == monster_id:
					spec = candidate
					break
		if spec.is_empty():
			spec = WikiMonsterCatalogClass.find_monster_spec(monster_id)
		if spec.is_empty():
			for candidate in DAY1_MONSTER_SPECS:
				if str(candidate.get("id", "")) == monster_id:
					spec = candidate
					break
	if spec.is_empty():
		return null

	var monster: MonsterDataClass = MonsterDataClass.new()
	monster.monster_name = str(spec.get("name", "Monster"))
	monster.tier = _monster_tier_to_enum(str(spec.get("tier", "Bronze")))
	monster.max_hp = int(spec.get("health", 100))
	monster.current_hp = monster.max_hp
	monster.gold_reward_min = int(spec.get("gold", 2))
	monster.gold_reward_max = int(spec.get("gold", 2))
	monster.xp_reward = int(spec.get("xp", 2))
	var encounter_metadata: Dictionary = _build_monster_encounter_metadata(spec, level)
	monster.reward = {
		"gold": int(spec.get("gold", 2)),
		"xp": int(spec.get("xp", 2)),
		"item_pool": _get_monster_reward_item_pool(spec),
		"skill_pool": _get_monster_reward_skill_pool(spec),
		"item_count": 1,
		"skill_count": 1,
		"monster_id": str(spec.get("id", "")),
		"monster_name": str(spec.get("name", "Monster")),
		"risk_score": int(encounter_metadata.get("risk_score", 0)),
		"risk_tags": encounter_metadata.get("risk_tags", []),
		"reward_tags": encounter_metadata.get("reward_tags", []),
		"reward_paths": encounter_metadata.get("reward_paths", []),
		"reward_summary": str(encounter_metadata.get("reward_summary", "")),
	}
	monster.monster_skills = _get_monster_skill_entries(spec)
	monster.monster_items = []
	var burn_bonus: int = _get_monster_numeric_bonus(monster.monster_skills, "burn_bonus")
	var poison_bonus: int = _get_monster_numeric_bonus(monster.monster_skills, "poison_bonus")
	var shield_bonus: int = _get_monster_numeric_bonus(monster.monster_skills, "shield_bonus")
	var damage_bonus: int = _get_monster_numeric_bonus(monster.monster_skills, "damage_bonus")
	var direct_numeric_bonuses: Array[Dictionary] = _get_monster_direct_numeric_skill_bonuses(monster.monster_skills)
	for item_entry in _get_monster_item_entries(spec):
		var item_id: String = str(item_entry.get("id", ""))
		var item_spec: Dictionary = _find_item_spec(item_id)
		var default_rarity: int = RARITY_BRONZE if item_spec.is_empty() else _get_spec_start_rarity(item_spec)
		var item_rarity: int = int(item_entry.get("rarity", default_rarity))
		var item_data: ItemDataClass = create_item(item_id, item_rarity)
		if item_data == null:
			continue
		var monster_item: Dictionary = item_to_monster_item(item_data)
		if burn_bonus > 0 and int(monster_item.get("burn", 0)) > 0:
			monster_item["burn"] = int(monster_item["burn"]) + burn_bonus
		if poison_bonus > 0 and int(monster_item.get("poison", 0)) > 0:
			monster_item["poison"] = int(monster_item["poison"]) + poison_bonus
		if shield_bonus > 0 and int(monster_item.get("shield", 0)) > 0:
			monster_item["shield"] = int(monster_item["shield"]) + shield_bonus
		if damage_bonus > 0 and int(monster_item.get("damage", 0)) > 0:
			monster_item["damage"] = int(monster_item["damage"]) + damage_bonus
		monster.monster_items.append(monster_item)
	_apply_monster_direct_numeric_bonuses(monster.monster_items, direct_numeric_bonuses)
	return monster

static func item_to_monster_item(item_data: ItemDataClass) -> Dictionary:
	var cooldown: float = maxf(item_data.cooldown, 0.0)
	return {
		"name": item_data.item_name,
		"enchantment": item_data.enchantment_id,
		"type": item_data.type,
		"rarity": item_data.rarity,
		"buy_price": item_data.buy_price,
		"damage": item_data.damage,
		"shield": item_data.shield,
		"heal": item_data.heal,
		"burn": int(item_data.burn_damage),
		"poison": int(item_data.poison_damage),
		"regen": int(item_data.regeneration),
		"slow": item_data.slow_count,
		"slow_duration": item_data.slow_duration,
		"freeze": item_data.freeze_count,
		"freeze_duration": item_data.freeze_duration,
		"haste": item_data.haste_count,
		"haste_duration": item_data.haste_duration,
		"crit_chance": item_data.crit_chance,
		"cooldown": cooldown,
		"current_cooldown": cooldown,
		"ammo": item_data.get_max_ammo(),
		"max_ammo": item_data.get_max_ammo(),
		"current_ammo": item_data.get_max_ammo(),
		"size": item_data.get_size_text(),
		"slot_count": item_data.get_slot_count(),
		"source_id": item_data.source_id,
		"tags": item_data.tags.duplicate(),
		"description": item_data.source_effect_text,
		"effects": item_data.effects.duplicate(true),
		"effect_warnings": item_data.effect_warnings.duplicate(),
	}

static func _build_monster_encounter_metadata(spec: Dictionary, day: int) -> Dictionary:
	var item_entries: Array[Dictionary] = _get_monster_item_entries(spec)
	var skill_entries: Array[Dictionary] = _get_monster_skill_entries(spec)
	var risk_tags: Array[String] = []
	var reward_tags: Array[String] = []
	var risk_score: int = maxi(int(spec.get("level", day)), day)
	match str(spec.get("tier", "Bronze")):
		"Silver": risk_score += 1
		"Gold": risk_score += 2
		"Diamond": risk_score += 3
	var health: int = int(spec.get("health", 100))
	if health >= 1000:
		risk_tags.append("high_hp")
		risk_score += 2
	elif health >= 400:
		risk_tags.append("sturdy")
		risk_score += 1
	for item_entry in item_entries:
		var item_id: String = str(item_entry.get("id", ""))
		var item_spec: Dictionary = _find_item_spec(item_id)
		if item_spec.is_empty():
			continue
		var tags: Array[String] = _string_array(item_spec.get("tags", []))
		if _array_has_tag(tags, "Weapon") or item_spec.has("damage"):
			_add_unique_string(risk_tags, "damage")
			_add_unique_string(reward_tags, "weapon")
		if item_spec.has("poison"):
			_add_unique_string(risk_tags, "poison")
		if item_spec.has("burn"):
			_add_unique_string(risk_tags, "burn")
		if item_spec.has("slow"):
			_add_unique_string(risk_tags, "slow")
		if item_spec.has("freeze"):
			_add_unique_string(risk_tags, "freeze")
		if item_spec.has("shield"):
			_add_unique_string(risk_tags, "shield")
			_add_unique_string(reward_tags, "shield")
		if item_spec.has("heal") or item_spec.has("regen"):
			_add_unique_string(risk_tags, "sustain")
			_add_unique_string(reward_tags, "sustain")
		for tag in tags:
			match tag.to_lower():
				"ammo", "crit", "haste", "charge", "multicast", "economy", "value":
					_add_unique_string(reward_tags, tag.to_lower())
	for skill_entry in skill_entries:
		var skill_id: String = _monster_skill_entry_id(skill_entry)
		if skill_id.is_empty():
			continue
		if _monster_skill_has_direct_runtime(skill_entry):
			_add_unique_string(risk_tags, "skill:%s" % skill_id)
		else:
			_add_unique_string(risk_tags, "unsupported_skill:%s" % skill_id)
	var reward_paths: Array[String] = ["payout"]
	if not _get_monster_reward_item_pool(spec).is_empty():
		reward_paths.append("item")
	if not _get_monster_reward_skill_pool(spec).is_empty():
		reward_paths.append("skill")
	return {
		"monster_id": str(spec.get("id", "")),
		"name": str(spec.get("name", "Monster")),
		"level": int(spec.get("level", day)),
		"tier": str(spec.get("tier", "Bronze")),
		"health": health,
		"risk_score": risk_score,
		"risk_tags": risk_tags,
		"reward_tags": reward_tags,
		"reward_paths": reward_paths,
		"reward_summary": _describe_monster_reward_paths(spec),
	}

static func _build_monster_special_entry(spec: Dictionary, metadata: Dictionary) -> Dictionary:
	var supported_mechanics: Array[String] = []
	var unsupported_reasons: Array[String] = []
	for item_entry in _get_monster_item_entries(spec):
		var item_id: String = str(item_entry.get("id", ""))
		var item_spec: Dictionary = _find_item_spec(item_id)
		if item_spec.is_empty():
			unsupported_reasons.append("missing_item_spec:%s" % item_id)
			continue
		var item_data: ItemDataClass = create_item(item_id, int(item_entry.get("rarity", _get_spec_start_rarity(item_spec))))
		if item_data == null:
			unsupported_reasons.append("create_item_failed:%s" % item_id)
			continue
		var mechanics: Array[String] = _item_runtime_mechanics(item_data)
		for mechanic in mechanics:
			_add_unique_string(supported_mechanics, mechanic)
		for warning in item_data.effect_warnings:
			unsupported_reasons.append("item:%s:%s" % [item_id, str(warning)])
	for skill_entry in _get_monster_skill_entries(spec):
		var skill_id: String = _monster_skill_entry_id(skill_entry)
		var normalized: Dictionary = PlayerSkillCatalogClass.normalize_skill_ref(skill_entry)
		if _monster_skill_has_direct_runtime(skill_entry):
			_add_unique_string(supported_mechanics, _monster_skill_direct_runtime_mechanic(skill_entry))
		elif str(normalized.get("support_status", "")) == PlayerSkillCatalogClass.SUPPORT_IMPLEMENTED:
			unsupported_reasons.append("skill:%s:player_skill_runtime_not_bound_to_monster_ai:%s" % [skill_id, str(normalized.get("implementation_kind", "implemented"))])
		else:
			var reason: String = str(normalized.get("unsupported_reason", "phase1_catalog_rule_missing"))
			unsupported_reasons.append("skill:%s:%s" % [skill_id, reason])
	supported_mechanics.sort()
	unsupported_reasons.sort()
	var level: int = int(spec.get("level", 0))
	var encounter_day: int = maxi(level, 1)
	return {
		"id": str(spec.get("id", "")),
		"name": str(spec.get("name", "Monster")),
		"level": level,
		"day": encounter_day,
		"tier": str(spec.get("tier", "")),
		"risk_score": int(metadata.get("risk_score", 0)),
		"risk_tags": metadata.get("risk_tags", []),
		"reward_paths": metadata.get("reward_paths", []),
		"supported": not supported_mechanics.is_empty(),
		"has_missing_mechanics": not unsupported_reasons.is_empty(),
		"supported_mechanics": supported_mechanics,
		"unsupported_reasons": unsupported_reasons,
		"deterministic_evidence": "tests/test_monster_specials.gd",
	}

static func _build_monster_parity_report(specs: Array[Dictionary], selection: String, deterministic_evidence: String) -> Dictionary:
	var monsters: Array[Dictionary] = []
	var supported_count: int = 0
	var unsupported_count: int = 0
	var missing_count: int = 0
	var reward_path_count: Dictionary = {"item": 0, "skill": 0, "payout": 0}
	var day_counts: Dictionary = {}
	var tier_counts: Dictionary = {}
	var missing_by_monster: Array[Dictionary] = []
	var missing_by_level: Dictionary = {}
	var missing_by_day: Dictionary = {}
	var missing_by_risk: Dictionary = {}
	var reason_counts: Dictionary = {}
	for spec in specs:
		var entry: Dictionary = {}
		if spec.is_empty():
			entry = {"id": "", "name": "", "level": 0, "day": 1, "tier": "", "risk_score": 0, "risk_tags": [], "reward_paths": [], "supported": false, "has_missing_mechanics": true, "supported_mechanics": [], "unsupported_reasons": ["missing_monster_spec"], "deterministic_evidence": "tests/test_monster_specials.gd"}
		else:
			var day: int = maxi(int(spec.get("level", 1)), 1)
			var metadata: Dictionary = _build_monster_encounter_metadata(spec, day)
			entry = _build_monster_special_entry(spec, metadata)
		entry["deterministic_evidence"] = deterministic_evidence
		if bool(entry.get("supported", false)):
			supported_count += 1
		else:
			unsupported_count += 1
		var reward_paths: Array = entry.get("reward_paths", [])
		for path_value in reward_paths:
			var path_key: String = str(path_value)
			reward_path_count[path_key] = int(reward_path_count.get(path_key, 0)) + 1
		var level_key: String = str(entry.get("level", 0))
		var day_key: String = str(entry.get("day", 1))
		day_counts[day_key] = int(day_counts.get(day_key, 0)) + 1
		var tier_key: String = str(entry.get("tier", ""))
		tier_counts[tier_key] = int(tier_counts.get(tier_key, 0)) + 1
		var unsupported_reasons: Array = entry.get("unsupported_reasons", [])
		if not unsupported_reasons.is_empty():
			missing_count += 1
			_record_monster_missing_group(missing_by_level, level_key, entry)
			_record_monster_missing_group(missing_by_day, str(entry.get("day", 1)), entry)
			_record_monster_missing_group(missing_by_risk, _monster_risk_group(int(entry.get("risk_score", 0))), entry)
			for reason in unsupported_reasons:
				var reason_key: String = str(reason)
				reason_counts[reason_key] = int(reason_counts.get(reason_key, 0)) + 1
			missing_by_monster.append({
				"id": str(entry.get("id", "")),
				"name": str(entry.get("name", "")),
				"level": int(entry.get("level", 0)),
				"day": int(entry.get("day", 1)),
				"tier": str(entry.get("tier", "")),
				"risk_score": int(entry.get("risk_score", 0)),
				"risk_group": _monster_risk_group(int(entry.get("risk_score", 0))),
				"unsupported_reasons": unsupported_reasons.duplicate(),
			})
		monsters.append(entry)
	return {
		"schema_version": 2,
		"selection": selection,
		"monster_count": monsters.size(),
		"supported_count": supported_count,
		"unsupported_count": unsupported_count,
		"missing_mechanics_count": missing_count,
		"reward_path_count": reward_path_count,
		"day_counts": _sorted_count_dictionary(day_counts),
		"tier_counts": _sorted_count_dictionary(tier_counts),
		"grouped_missing_mechanics": {
			"by_monster": missing_by_monster,
			"by_level": _sorted_missing_groups(missing_by_level),
			"by_day": _sorted_missing_groups(missing_by_day),
			"by_risk": _sorted_missing_groups(missing_by_risk),
			"reason_counts": _sorted_count_dictionary(reason_counts),
		},
		"monsters": monsters,
	}

static func _record_monster_missing_group(groups: Dictionary, key: String, entry: Dictionary) -> void:
	if not groups.has(key):
		groups[key] = {"count": 0, "monster_ids": [], "reason_counts": {}}
	var group: Dictionary = groups[key]
	group["count"] = int(group.get("count", 0)) + 1
	var monster_ids: Array = group.get("monster_ids", [])
	monster_ids.append(str(entry.get("id", "")))
	group["monster_ids"] = monster_ids
	var reason_counts: Dictionary = group.get("reason_counts", {})
	for reason in entry.get("unsupported_reasons", []):
		var reason_key: String = str(reason)
		reason_counts[reason_key] = int(reason_counts.get(reason_key, 0)) + 1
	group["reason_counts"] = reason_counts
	groups[key] = group

static func _sorted_missing_groups(groups: Dictionary) -> Array[Dictionary]:
	var keys: Array = groups.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key in keys:
		var group: Dictionary = groups[key]
		var monster_ids: Array = group.get("monster_ids", [])
		monster_ids.sort()
		result.append({
			"group": str(key),
			"count": int(group.get("count", 0)),
			"monster_ids": monster_ids,
			"reason_counts": _sorted_count_dictionary(group.get("reason_counts", {})),
		})
	return result

static func _sorted_count_dictionary(counts: Dictionary) -> Dictionary:
	var keys: Array = counts.keys()
	keys.sort()
	var result: Dictionary = {}
	for key in keys:
		result[str(key)] = int(counts[key])
	return result

static func _monster_risk_group(risk_score: int) -> String:
	if risk_score >= 18:
		return "risk_18_plus"
	if risk_score >= 13:
		return "risk_13_17"
	if risk_score >= 8:
		return "risk_08_12"
	return "risk_00_07"

static func _monster_skill_has_direct_runtime(skill_entry: Dictionary) -> bool:
	for key in ["start_poison", "start_burn", "start_shield", "burn_bonus", "poison_bonus", "shield_bonus", "damage_bonus"]:
		if int(skill_entry.get(key, 0)) > 0:
			return true
	return not _get_monster_direct_numeric_skill_binding(skill_entry).is_empty()

static func _monster_skill_direct_runtime_mechanic(skill_entry: Dictionary) -> String:
	var skill_id: String = _monster_skill_entry_id(skill_entry)
	var binding: Dictionary = _get_monster_direct_numeric_skill_binding(skill_entry)
	if not binding.is_empty():
		return str(binding.get("mechanic", "skill:%s:direct_monster_runtime" % skill_id))
	return "skill:%s:direct_monster_runtime" % skill_id

static func _get_monster_direct_numeric_skill_binding(skill_entry: Dictionary) -> Dictionary:
	var skill_id: String = _monster_skill_entry_id(skill_entry)
	if skill_id.is_empty() or not MONSTER_DIRECT_NUMERIC_SKILL_BINDINGS.has(skill_id):
		return {}
	return (MONSTER_DIRECT_NUMERIC_SKILL_BINDINGS[skill_id] as Dictionary).duplicate(true)

static func _get_monster_direct_numeric_skill_bonuses(skills: Array) -> Array[Dictionary]:
	var bonuses: Array[Dictionary] = []
	for skill in skills:
		if not skill is Dictionary:
			continue
		var skill_entry: Dictionary = skill as Dictionary
		var binding: Dictionary = _get_monster_direct_numeric_skill_binding(skill_entry)
		if binding.is_empty():
			continue
		var value: float = PlayerSkillCatalogClass.get_tier_value(skill_entry)
		if value <= 0.0:
			continue
		bonuses.append({
			"skill_id": _monster_skill_entry_id(skill_entry),
			"bonus_key": str(binding.get("bonus_key", "")),
			"target": str(binding.get("target", "all_items")),
			"presence_tags": (binding.get("presence_tags", []) as Array).duplicate(),
			"value": value,
		})
	return bonuses

static func _apply_monster_direct_numeric_bonuses(monster_items: Array, bonuses: Array[Dictionary]) -> void:
	if monster_items.is_empty() or bonuses.is_empty():
		return
	for bonus in bonuses:
		var target_indexes: Array[int] = _get_monster_numeric_skill_target_indexes(monster_items, str(bonus.get("target", "")))
		for index in target_indexes:
			if index < 0 or index >= monster_items.size() or not monster_items[index] is Dictionary:
				continue
			var monster_item: Dictionary = monster_items[index] as Dictionary
			match str(bonus.get("bonus_key", "")):
				"damage":
					monster_item["damage"] = maxi(int(monster_item.get("damage", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"crit_chance":
					monster_item["crit_chance"] = clampf(float(monster_item.get("crit_chance", 0.0)) + float(bonus.get("value", 0.0)) / 100.0, 0.0, 3.0)
				"heal":
					monster_item["heal"] = maxi(int(monster_item.get("heal", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"shield":
					monster_item["shield"] = maxi(int(monster_item.get("shield", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"burn":
					monster_item["burn"] = maxi(int(monster_item.get("burn", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"poison":
					monster_item["poison"] = maxi(int(monster_item.get("poison", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"regen":
					monster_item["regen"] = maxi(int(monster_item.get("regen", 0)) + int(round(float(bonus.get("value", 0.0)))), 0)
				"max_ammo":
					var max_ammo: int = maxi(int(monster_item.get("max_ammo", monster_item.get("ammo", 0))) + int(round(float(bonus.get("value", 0.0)))), 0)
					monster_item["max_ammo"] = max_ammo
					monster_item["ammo"] = max_ammo
					monster_item["current_ammo"] = max_ammo
				"cooldown_percent":
					_apply_monster_item_cooldown_percent(monster_item, float(bonus.get("value", 0.0)))
				"cooldown_percent_per_present_tag":
					var present_tag_count: int = _count_present_monster_item_tags(monster_items, bonus.get("presence_tags", []))
					_apply_monster_item_cooldown_percent(monster_item, float(bonus.get("value", 0.0)) * float(present_tag_count))

static func _apply_monster_item_cooldown_percent(monster_item: Dictionary, percent: float) -> void:
	if percent <= 0.0:
		return
	var cooldown: float = maxf(float(monster_item.get("cooldown", 0.0)), 0.0)
	if cooldown <= 0.0:
		return
	monster_item["base_cooldown"] = float(monster_item.get("base_cooldown", cooldown))
	var reduced: float = maxf(cooldown * (1.0 - percent / 100.0), 0.0)
	monster_item["cooldown"] = reduced
	monster_item["current_cooldown"] = reduced

static func _count_present_monster_item_tags(monster_items: Array, tags: Array) -> int:
	var count: int = 0
	for tag_value in tags:
		var tag: String = str(tag_value)
		if tag.is_empty():
			continue
		for item in monster_items:
			if item is Dictionary and _monster_item_has_tag(item as Dictionary, tag):
				count += 1
				break
	return count

static func _get_monster_numeric_skill_target_indexes(monster_items: Array, target: String) -> Array[int]:
	var indexes: Array[int] = []
	match target:
		"leftmost_weapon":
			var leftmost: int = _find_monster_weapon_index(monster_items, false)
			if leftmost >= 0:
				indexes.append(leftmost)
			return indexes
		"rightmost_weapon":
			var rightmost: int = _find_monster_weapon_index(monster_items, true)
			if rightmost >= 0:
				indexes.append(rightmost)
			return indexes
		"leftmost_heal_item":
			var leftmost_heal: int = _find_monster_numeric_item_index(monster_items, "heal", false)
			if leftmost_heal >= 0:
				indexes.append(leftmost_heal)
			return indexes
		"rightmost_heal_item":
			var rightmost_heal: int = _find_monster_numeric_item_index(monster_items, "heal", true)
			if rightmost_heal >= 0:
				indexes.append(rightmost_heal)
			return indexes
		"leftmost_shield_item":
			var leftmost_shield: int = _find_monster_numeric_item_index(monster_items, "shield", false)
			if leftmost_shield >= 0:
				indexes.append(leftmost_shield)
			return indexes
		"leftmost_poison_item":
			var leftmost_poison: int = _find_monster_numeric_item_index(monster_items, "poison", false)
			if leftmost_poison >= 0:
				indexes.append(leftmost_poison)
			return indexes
		"rightmost_burn_item":
			var rightmost_burn: int = _find_monster_numeric_item_index(monster_items, "burn", true)
			if rightmost_burn >= 0:
				indexes.append(rightmost_burn)
			return indexes
		"leftmost_ammo_item":
			var leftmost_ammo: int = _find_monster_numeric_item_index(monster_items, "ammo", false)
			if leftmost_ammo >= 0:
				indexes.append(leftmost_ammo)
			return indexes
		"rightmost_regen_item":
			var rightmost_regen: int = _find_monster_numeric_item_index(monster_items, "regen", true)
			if rightmost_regen >= 0:
				indexes.append(rightmost_regen)
			return indexes
		"edge_items":
			if not monster_items.is_empty():
				indexes.append(0)
				var last_index: int = monster_items.size() - 1
				if last_index > 0:
					indexes.append(last_index)
			return indexes
		"non_vehicle_items_if_vehicle_present":
			if _any_monster_item_has_tag(monster_items, "Vehicle"):
				for index in range(monster_items.size()):
					if monster_items[index] is Dictionary and not _monster_item_has_tag(monster_items[index] as Dictionary, "Vehicle"):
						indexes.append(index)
			return indexes
		"only_medium_item":
			var medium_indexes: Array[int] = []
			for index in range(monster_items.size()):
				if monster_items[index] is Dictionary and int((monster_items[index] as Dictionary).get("slot_count", 1)) == 2:
					medium_indexes.append(index)
			if medium_indexes.size() == 1:
				indexes.append(medium_indexes[0])
			return indexes
	for index in range(monster_items.size()):
		if monster_items[index] is Dictionary and _monster_item_matches_numeric_skill_target(monster_items[index] as Dictionary, target):
			indexes.append(index)
	return indexes

static func _find_monster_weapon_index(monster_items: Array, from_right: bool) -> int:
	if from_right:
		for index in range(monster_items.size() - 1, -1, -1):
			if monster_items[index] is Dictionary and int((monster_items[index] as Dictionary).get("type", ItemDataClass.Type.UTILITY)) == ItemDataClass.Type.WEAPON:
				return index
		return -1
	for index in range(monster_items.size()):
		if monster_items[index] is Dictionary and int((monster_items[index] as Dictionary).get("type", ItemDataClass.Type.UTILITY)) == ItemDataClass.Type.WEAPON:
			return index
	return -1

static func _find_monster_numeric_item_index(monster_items: Array, key: String, from_right: bool) -> int:
	if from_right:
		for index in range(monster_items.size() - 1, -1, -1):
			if monster_items[index] is Dictionary and float((monster_items[index] as Dictionary).get(key, 0.0)) > 0.0:
				return index
		return -1
	for index in range(monster_items.size()):
		if monster_items[index] is Dictionary and float((monster_items[index] as Dictionary).get(key, 0.0)) > 0.0:
			return index
	return -1

static func _monster_item_matches_numeric_skill_target(monster_item: Dictionary, target: String) -> bool:
	match target:
		"weapons":
			return int(monster_item.get("type", ItemDataClass.Type.UTILITY)) == ItemDataClass.Type.WEAPON
		"all_items":
			return true
		"ammo_items":
			return int(monster_item.get("ammo", monster_item.get("max_ammo", 0))) > 0
		"burn_items":
			return int(monster_item.get("burn", 0)) > 0
		"heal_items":
			return int(monster_item.get("heal", 0)) > 0
		"friend_items":
			return _monster_item_has_tag(monster_item, "Friend")
		"small_diamond_items":
			return int(monster_item.get("slot_count", 1)) == 1 and int(monster_item.get("rarity", RARITY_BRONZE)) == RARITY_DIAMOND
		"non_vehicle_items_if_vehicle_present":
			return not _monster_item_has_tag(monster_item, "Vehicle")
		"only_medium_item":
			return int(monster_item.get("slot_count", 1)) == 2
	return false

static func _any_monster_item_has_tag(monster_items: Array, tag: String) -> bool:
	for item in monster_items:
		if item is Dictionary and _monster_item_has_tag(item as Dictionary, tag):
			return true
	return false

static func _monster_item_has_tag(monster_item: Dictionary, tag: String) -> bool:
	for value in monster_item.get("tags", []):
		if str(value) == tag:
			return true
	return false

static func _item_runtime_mechanics(item: ItemDataClass) -> Array[String]:
	var mechanics: Array[String] = []
	if item.damage > 0:
		mechanics.append("damage")
	if item.shield > 0:
		mechanics.append("shield")
	if item.heal > 0:
		mechanics.append("heal")
	if item.burn_damage > 0:
		mechanics.append("burn")
	if item.poison_damage > 0:
		mechanics.append("poison")
	if item.regeneration > 0:
		mechanics.append("regen")
	if item.slow_count > 0:
		mechanics.append("slow")
	if item.freeze_count > 0:
		mechanics.append("freeze")
	if item.haste_count > 0:
		mechanics.append("haste")
	if item.get_max_ammo() > 0:
		mechanics.append("ammo")
	if not item.effects.is_empty():
		mechanics.append("effect_dsl")
	if mechanics.is_empty() and item.cooldown <= 0.0:
		mechanics.append("passive_or_loot")
	return mechanics

static func _describe_monster_reward_paths(spec: Dictionary) -> String:
	var parts: Array[String] = ["Gold %d" % int(spec.get("gold", 0)), "XP %d" % int(spec.get("xp", 0))]
	var item_pool: Array[Dictionary] = _get_monster_reward_item_pool(spec)
	var skill_pool: Array[Dictionary] = _get_monster_reward_skill_pool(spec)
	if not item_pool.is_empty():
		parts.append("%d item drops" % item_pool.size())
	if not skill_pool.is_empty():
		parts.append("%d skill drops" % skill_pool.size())
	return ", ".join(parts)

static func _add_unique_string(values: Array[String], value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	values.append(value)

static func _find_item_spec(item_id: String) -> Dictionary:
	for spec in get_mak_item_specs():
		if str(spec.get("id", "")) == item_id:
			return spec
	for spec in KARNOK_BAZAARDB_ITEMS:
		if str(spec.get("id", "")) == item_id:
			return spec
	for spec in SHARED_ITEM_SPECS:
		if str(spec.get("id", "")) == item_id:
			return spec
	var wiki_spec: Dictionary = WikiMonsterCatalogClass.find_item_spec(item_id)
	if not wiki_spec.is_empty():
		return wiki_spec
	return {}

static func _create_passive_skill(spec: Dictionary) -> PassiveSkillDataClass:
	var skill: PassiveSkillDataClass = PassiveSkillDataClass.new()
	skill.skill_name = str(spec.get("name", "Hero Mechanic"))
	skill.description = str(spec.get("description", ""))
	match str(spec.get("type", "health")):
		"crit":
			skill.effect_type = PassiveSkillDataClass.EffectType.CRIT_BONUS
		"shield":
			skill.effect_type = PassiveSkillDataClass.EffectType.SHIELD_BONUS
		"cooldown":
			skill.effect_type = PassiveSkillDataClass.EffectType.COOLDOWN_REDUCTION
		"reflect":
			skill.effect_type = PassiveSkillDataClass.EffectType.DAMAGE_REFLECTION
		"lifesteal":
			skill.effect_type = PassiveSkillDataClass.EffectType.LIFESTEAL
		_:
			skill.effect_type = PassiveSkillDataClass.EffectType.HEALTH_BONUS
	skill.effect_value = float(spec.get("value", 0.0))
	return skill

static func _get_monster_item_entries(spec: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if spec.has("items"):
		for value in spec.get("items", []):
			if value is Dictionary:
				entries.append((value as Dictionary).duplicate(true))
		return entries
	for item_id in spec.get("item_ids", []):
		var clean_id: String = str(item_id)
		if clean_id.is_empty():
			continue
		entries.append({"id": clean_id})
	return entries

static func _get_monster_skill_entries(spec: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if spec.has("skills"):
		for value in spec.get("skills", []):
			if value is Dictionary:
				entries.append((value as Dictionary).duplicate(true))
		return entries
	for skill_id in spec.get("skill_ids", []):
		var clean_id: String = str(skill_id)
		if clean_id.is_empty():
			continue
		var skill_spec: Dictionary = WikiMonsterCatalogClass.find_skill_spec(clean_id)
		if not skill_spec.is_empty():
			entries.append(skill_spec)
	return entries

static func _get_monster_reward_item_pool(spec: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for item_entry in _get_monster_item_entries(spec):
		var item_id: String = str(item_entry.get("id", ""))
		if item_id.is_empty():
			continue
		var item_spec: Dictionary = _find_item_spec(item_id)
		if item_spec.is_empty():
			continue
		pool.append({
			"id": item_id,
			"tier": str(item_entry.get("tier", item_entry.get("rarity", item_spec.get("starting_tier", "Bronze")))),
		})
	return pool

static func _get_monster_reward_skill_pool(spec: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for skill_id_ref in spec.get("skill_ids", []):
		var skill_id: String = str(skill_id_ref)
		if skill_id.is_empty():
			continue
		var skill_spec: Dictionary = WikiMonsterCatalogClass.find_skill_spec(skill_id)
		pool.append({
			"id": skill_id,
			"tier": str(skill_spec.get("starting_tier", "Bronze")),
		})
	if not pool.is_empty():
		return pool
	for skill_entry in _get_monster_skill_entries(spec):
		var skill_id: String = _monster_skill_entry_id(skill_entry)
		if skill_id.is_empty():
			continue
		pool.append({
			"id": skill_id,
			"tier": str(skill_entry.get("starting_tier", skill_entry.get("tier", "Bronze"))),
		})
	return pool

static func _monster_skill_entry_id(skill_entry: Dictionary) -> String:
	var skill_id: String = str(skill_entry.get("id", ""))
	if not skill_id.is_empty():
		return skill_id
	var skill_name: String = str(skill_entry.get("name", "")).strip_edges().to_lower()
	if skill_name.is_empty():
		return ""
	skill_name = skill_name.replace("&", "and")
	skill_name = skill_name.replace("'", "")
	skill_name = skill_name.replace(".", "")
	skill_name = skill_name.replace(" ", "_")
	return skill_name

static func _shop_candidate_allowed(item_id: String, rarity: int, owned_items: Array) -> bool:
	if item_id.is_empty():
		return true
	var lowest_owned_rarity: int = RARITY_DIAMOND + 1
	for value in owned_items:
		if not value is ItemDataClass:
			continue
		var owned: ItemDataClass = value
		if owned.source_id != item_id:
			continue
		if owned.rarity >= RARITY_DIAMOND:
			return false
		lowest_owned_rarity = mini(lowest_owned_rarity, owned.rarity)
	if lowest_owned_rarity == RARITY_DIAMOND + 1:
		return true
	return rarity >= lowest_owned_rarity

static func _spec_has_tag(spec: Dictionary, tag: String) -> bool:
	for value in spec.get("tags", []):
		if str(value).to_lower() == tag.to_lower():
			return true
	return false

static func _string_array(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value in values:
			result.append(str(value))
	return result

static func _size_to_enum(size_text: String) -> ItemDataClass.Size:
	match size_text:
		"Medium":
			return ItemDataClass.Size.MEDIUM
		"Large":
			return ItemDataClass.Size.LARGE
	return ItemDataClass.Size.SMALL

static func _tags_to_item_type(tags: Array[String]) -> ItemDataClass.Type:
	if _array_has_tag(tags, "Weapon"):
		return ItemDataClass.Type.WEAPON
	if _array_has_tag(tags, "Shield"):
		return ItemDataClass.Type.SHIELD
	if _array_has_tag(tags, "Heal") or _array_has_tag(tags, "Regen"):
		return ItemDataClass.Type.HEAL
	return ItemDataClass.Type.UTILITY

static func _array_has_tag(tags: Array[String], tag: String) -> bool:
	for value in tags:
		if value.to_lower() == tag.to_lower():
			return true
	return false

static func _get_spec_start_rarity(spec: Dictionary) -> int:
	match str(spec.get("starting_tier", "Bronze")):
		"Silver":
			return RARITY_SILVER
		"Gold":
			return RARITY_GOLD
		"Diamond":
			return RARITY_DIAMOND
	return RARITY_BRONZE

static func _get_rarity_array_index(values: Array, rarity: int, start_rarity: int) -> int:
	if values.is_empty():
		return 0
	var normalized_start: int = clampi(start_rarity, RARITY_BRONZE, RARITY_DIAMOND)
	var index: int = rarity - normalized_start
	return clampi(index, 0, values.size() - 1)

static func _get_int_for_rarity(values: Variant, rarity: int, fallback: int, start_rarity: int = RARITY_BRONZE) -> int:
	if values is int or values is float:
		return int(values)
	if not values is Array or (values as Array).is_empty():
		return fallback
	var array_values: Array = values as Array
	var index: int = _get_rarity_array_index(array_values, rarity, start_rarity)
	return int(array_values[index])

static func _get_float_for_rarity(values: Variant, rarity: int, fallback: float, start_rarity: int = RARITY_BRONZE) -> float:
	if values is int or values is float:
		return float(values)
	if not values is Array or (values as Array).is_empty():
		return fallback
	var array_values: Array = values as Array
	var index: int = _get_rarity_array_index(array_values, rarity, start_rarity)
	return float(array_values[index])

static func _default_tempo_duration(count: int) -> float:
	return 1.0 if count > 0 else 0.0

static func _monster_tier_to_enum(tier_text: String) -> MonsterDataClass.MonsterTier:
	match tier_text:
		"Silver":
			return MonsterDataClass.MonsterTier.TIER_2
		"Gold", "Diamond", "Legendary":
			return MonsterDataClass.MonsterTier.TIER_3
	return MonsterDataClass.MonsterTier.TIER_1

static func _get_monster_burn_bonus(skills: Array) -> int:
	return _get_monster_numeric_bonus(skills, "burn_bonus")

static func _get_monster_numeric_bonus(skills: Array, key: String) -> int:
	var bonus: int = 0
	for skill in skills:
		if skill is Dictionary:
			bonus += int((skill as Dictionary).get(key, 0))
	return bonus
