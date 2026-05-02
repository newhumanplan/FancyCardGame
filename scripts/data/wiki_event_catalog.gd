class_name WikiEventCatalog
extends RefCounted

# Generated-style catalog from https://thebazaar.wiki.gg/wiki/Category:Event.
# Keep entries data-only: gameplay effects remain in EventManager when implemented.

const SOURCE_URL: String = "https://thebazaar.wiki.gg/wiki/Category:Event"

const EVENT_SPECS: Array[Dictionary] = [
	{"id": "a_strange_mushroom", "name": "A Strange Mushroom", "rarity": "Bronze", "hero": "", "occurrence": "Day 1-2 (3?)", "min_day": 1, "max_day": 3, "summary": "Mak can brew a small Silver-tier Potion."},
	{"id": "abandoned_property", "name": "Abandoned Property", "rarity": "Gold", "hero": "Pygmalien", "occurrence": "Day ?-2+", "min_day": 2, "max_day": 0, "summary": "Pygmalien-specific property event."},
	{"id": "aerodrome", "name": "Aerodrome", "rarity": "Gold", "hero": "", "occurrence": "Day 3+", "min_day": 3, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "aldric", "name": "Aldric", "rarity": "Diamond", "hero": "Mak, Pygmalien", "occurrence": "Day ?-8+", "min_day": 8, "max_day": 0, "summary": "Mak/Pygmalien-specific event."},
	{"id": "armory", "name": "Armory", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a free Weapon."},
	{"id": "artisan_dunes", "name": "Artisan Dunes", "rarity": "Gold", "hero": "", "occurrence": "Day 3+", "min_day": 3, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "b1_b2", "name": "B1&B2", "rarity": "Silver", "hero": "", "occurrence": "Day 1, Hour 4 - Day 6", "min_day": 1, "max_day": 6, "summary": "Upgrade 1 Bronze-tier item."},
	{"id": "battlefield", "name": "Battlefield", "rarity": "Bronze", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a free small Weapon."},
	{"id": "bazaarcon", "name": "BazaarCON", "rarity": "Gold", "hero": "", "occurrence": "Day 6+", "min_day": 6, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "bladeborn_badlands", "name": "Bladeborn Badlands", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "block_party", "name": "Block Party", "rarity": "Gold", "hero": "", "occurrence": "Day 2+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "borrow", "name": "Borrow", "rarity": "Silver", "hero": "", "occurrence": "Day 1-2 / 3-4 / 5-6", "min_day": 1, "max_day": 6, "summary": "Lose 1 Income and gain Gold."},
	{"id": "botanical_gardens", "name": "Botanical Gardens", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a free Poison item."},
	{"id": "botul", "name": "Botul", "rarity": "Diamond", "hero": "Vanessa, Dooley, Mak", "occurrence": "Day ?", "min_day": 1, "max_day": 0, "summary": "Hero-specific event with uncertain timing."},
	{"id": "bounty_hunters_event", "name": "Bounty Hunters", "rarity": "Diamond", "hero": "Vanessa", "occurrence": "Day 8+", "min_day": 8, "max_day": 0, "summary": "Vanessa-specific event."},
	{"id": "burning_caldera", "name": "Burning Caldera", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "cabin_fishing", "name": "Cabin Fishing", "rarity": "Silver", "hero": "Vanessa", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Vanessa-specific event."},
	{"id": "cache_of_riches", "name": "Cache of Riches", "rarity": "Bronze", "hero": "", "occurrence": "Day 1-2 / 3-4 / 5+", "min_day": 1, "max_day": 0, "summary": "Gain Gold."},
	{"id": "candy_stash", "name": "Candy Stash", "rarity": "Bronze / Silver / Gold / Diamond", "hero": "", "occurrence": "Day 1-3 / 4-6 / 7-9 / 10+", "min_day": 1, "max_day": 0, "summary": "Get 3 Chocolate Bars."},
	{"id": "celestial_conduit", "name": "Celestial Conduit", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "cinder_chase", "name": "Cinder Chase", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get Cinders."},
	{"id": "dabora", "name": "Dabora", "rarity": "", "hero": "", "occurrence": "Day 1-10 (Currently disabled)", "min_day": 1, "max_day": 10, "enabled": false, "summary": "Currently disabled per wiki table."},
	{"id": "deadly_duel", "name": "Deadly Duel", "rarity": "Gold", "hero": "", "occurrence": "Day 5-7", "min_day": 5, "max_day": 7, "summary": "Confirmed wiki event."},
	{"id": "deep_sea_fishing", "name": "Deep Sea Fishing", "rarity": "Gold", "hero": "Vanessa", "occurrence": "Day ?-4-8-?", "min_day": 4, "max_day": 8, "summary": "Vanessa-specific event."},
	{"id": "dfleck", "name": "D'fleck", "rarity": "Diamond", "hero": "Dooley, Pygmalien", "occurrence": "Day ?", "min_day": 1, "max_day": 0, "summary": "Dooley/Pygmalien-specific event."},
	{"id": "dooleys_workshop", "name": "Dooley's Workshop", "rarity": "Diamond", "hero": "Dooley", "occurrence": "Day 6-10", "min_day": 6, "max_day": 10, "summary": "Dooley-specific event."},
	{"id": "eating_contest", "name": "Eating Contest", "rarity": "Bronze", "hero": "", "occurrence": "Day 3+", "min_day": 3, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "economic_seminar", "name": "Economic Seminar", "rarity": "Gold", "hero": "Pygmalien", "occurrence": "Day 3-5", "min_day": 3, "max_day": 5, "summary": "Pygmalien-specific event."},
	{"id": "epic_battle", "name": "Epic Battle", "rarity": "Gold", "hero": "", "occurrence": "Day 8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "extract_extract", "name": "Extract Extract", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get an Extract."},
	{"id": "finns_big_bite", "name": "Finn's Big Bite", "rarity": "Gold", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Eat at Finn's to get max Health."},
	{"id": "flambe", "name": "Flambe", "rarity": "Diamond", "hero": "", "occurrence": "Day ?", "min_day": 1, "max_day": 0, "summary": "Confirmed wiki event with uncertain timing."},
	{"id": "forja", "name": "Forja", "rarity": "Diamond", "hero": "", "occurrence": "Day ?-6+", "min_day": 6, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "form", "name": "Form", "rarity": "Diamond", "hero": "", "occurrence": "Day 7+", "min_day": 7, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "freezer", "name": "Freezer", "rarity": "Gold", "hero": "Non-Vanessa", "occurrence": "Day 2+", "min_day": 2, "max_day": 0, "summary": "Non-Vanessa event."},
	{"id": "frozen_tomb", "name": "Frozen Tomb", "rarity": "Legendary", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "furnace", "name": "Furnace", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a small Burn item."},
	{"id": "futura", "name": "Futura", "rarity": "Legendary", "hero": "", "occurrence": "Prestige reaches 0 the first time.", "min_day": 1, "max_day": 0, "summary": "Special prestige-loss event."},
	{"id": "genie_lamp_event", "name": "Genie Lamp", "rarity": "Diamond", "hero": "", "occurrence": "Drops on Lord of the Wastes or Treasure Turtle", "min_day": 1, "max_day": 0, "summary": "Drop-triggered event."},
	{"id": "guard_locker", "name": "Guard Locker", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a small Shield item."},
	{"id": "guardians_gorge", "name": "Guardian's Gorge", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "gumball_machine_event", "name": "Gumball Machine", "rarity": "Bronze", "hero": "", "occurrence": "3+", "min_day": 3, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "haddy", "name": "Haddy", "rarity": "Diamond", "hero": "", "occurrence": "Day 8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "hospital", "name": "Hospital", "rarity": "Gold", "hero": "", "occurrence": "Day ?-5+", "min_day": 5, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "house_party", "name": "House Party", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a small Friend."},
	{"id": "invest_in_yourself", "name": "Invest in Yourself", "rarity": "Silver", "hero": "", "occurrence": "Day 1-3 / 3-6", "min_day": 1, "max_day": 6, "summary": "Gain Income."},
	{"id": "investment_pitch", "name": "Investment Pitch", "rarity": "Gold", "hero": "Pygmalien", "occurrence": "Day 6-10", "min_day": 6, "max_day": 10, "summary": "Pygmalien-specific event."},
	{"id": "jules_cafe", "name": "Jules' Cafe", "rarity": "Silver", "hero": "", "occurrence": "Day ?-5+", "min_day": 5, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "jungle_ruins", "name": "Jungle Ruins", "rarity": "Bronze", "hero": "", "occurrence": "Day 1-2", "min_day": 1, "max_day": 2, "summary": "Mak can hunt for a Silver-tier Reagent."},
	{"id": "languid_dunes", "name": "Languid Dunes", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "likit", "name": "Likit", "rarity": "Silver", "hero": "", "occurrence": "Day 2", "min_day": 2, "max_day": 2, "summary": "Confirmed wiki event."},
	{"id": "look_for_spare_change", "name": "Look for Spare Change", "rarity": "Bronze", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get 3 Spare Change."},
	{"id": "lost_and_found", "name": "Lost and Found", "rarity": "Bronze", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a small non-Weapon item."},
	{"id": "mad_maddie", "name": "Mad Maddie", "rarity": "Diamond", "hero": "Vanessa, Mak", "occurrence": "Day 7+?", "min_day": 7, "max_day": 0, "summary": "Vanessa/Mak-specific event."},
	{"id": "mandala", "name": "Mandala", "rarity": "Bronze", "hero": "", "occurrence": "Day ?", "min_day": 1, "max_day": 0, "summary": "Transform your items into something new."},
	{"id": "medicine_cabinet", "name": "Medicine Cabinet", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a small Heal or Regeneration item."},
	{"id": "monster_ranch", "name": "Monster Ranch", "rarity": "Gold", "hero": "", "occurrence": "Day 8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "mountain_pass", "name": "Mountain Pass", "rarity": "Silver", "hero": "", "occurrence": "Day 4-7", "min_day": 4, "max_day": 7, "summary": "Confirmed wiki event."},
	{"id": "murkwood_bayou", "name": "Murkwood Bayou", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "mysterious_portal", "name": "Mysterious Portal", "rarity": "Gold", "hero": "", "occurrence": "Day 4+", "min_day": 4, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "obstacle_course", "name": "Obstacle Course", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a Slow item."},
	{"id": "pearls_dig_site", "name": "Pearl's Dig Site", "rarity": "Gold", "hero": "", "occurrence": "Day ?-5+", "min_day": 5, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "procure_medkit", "name": "Procure Medkit", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a Med Kit."},
	{"id": "pyre", "name": "Pyre", "rarity": "Gold", "hero": "", "occurrence": "Day ?-2+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "racetrack", "name": "Racetrack", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a Haste item."},
	{"id": "recycling_center", "name": "Recycling Center", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a non-Weapon item."},
	{"id": "regenerative_tincture", "name": "Regenerative Tincture", "rarity": "Bronze", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Gain Regeneration equal to your level."},
	{"id": "relax", "name": "Relax", "rarity": "Bronze", "hero": "", "occurrence": "Day ?-3+", "min_day": 1, "max_day": 0, "summary": "Start your next fight with 100 Shield per Level."},
	{"id": "sanguine_valley", "name": "Sanguine Valley", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "scrap_salvage", "name": "Scrap Salvage", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a Scrap."},
	{"id": "security_center", "name": "Security Center", "rarity": "Gold", "hero": "", "occurrence": "Day ?-2+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "sharpening_kit", "name": "Sharpening Kit", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get a Sharpening Stone."},
	{"id": "shrouded_figure", "name": "Shrouded Figure", "rarity": "Gold", "hero": "", "occurrence": "Day ?-8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "sirocco_steppe", "name": "Sirocco Steppe", "rarity": "Diamond", "hero": "", "occurrence": "Day ?", "min_day": 1, "max_day": 0, "summary": "Confirmed wiki event with uncertain timing."},
	{"id": "snack_time", "name": "Snack Time", "rarity": "Silver", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Gain 20 Max Health per level."},
	{"id": "start_of_run", "name": "Start of Run", "rarity": "", "hero": "", "occurrence": "First event", "min_day": 1, "max_day": 1, "summary": "Start each run with Gold/Income, an enchanted item, or a Gold-tier skill."},
	{"id": "street_festival", "name": "Street Festival", "rarity": "Gold", "hero": "", "occurrence": "Day 8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "study", "name": "Study", "rarity": "Silver", "hero": "", "occurrence": "Day 2, 4+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "the_artist", "name": "The Artist", "rarity": "Diamond", "hero": "", "occurrence": "Day ?-8+", "min_day": 8, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "the_cult", "name": "The Cult", "rarity": "Diamond", "hero": "", "occurrence": "Day 6+", "min_day": 6, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "the_docks", "name": "The Docks", "rarity": "Silver", "hero": "", "occurrence": "Day 4-7", "min_day": 4, "max_day": 7, "summary": "Work at the Docks to earn coin and an item."},
	{"id": "the_lost_crate", "name": "The Lost Crate", "rarity": "Bronze", "hero": "", "occurrence": "Day 1-5", "min_day": 1, "max_day": 5, "summary": "Open it for a Medium item or return it for a Skill."},
	{"id": "thieves_guild", "name": "Thieves Guild", "rarity": "Diamond", "hero": "", "occurrence": "Sell Thieves Guild Medallion / Mysterious Portal", "min_day": 1, "max_day": 0, "summary": "Special trigger event."},
	{"id": "tiny_furry_monster", "name": "Tiny Furry Monster", "rarity": "Bronze", "hero": "", "occurrence": "Day 1, Hour 4 - Day 2", "min_day": 1, "max_day": 2, "summary": "Pet it for 25 Max Health."},
	{"id": "tranquil_spring", "name": "Tranquil Spring", "rarity": "Diamond", "hero": "", "occurrence": "Day 10+", "min_day": 10, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "treasure_chest", "name": "Treasure Chest", "rarity": "Bronze", "hero": "", "occurrence": "Day 1+", "min_day": 1, "max_day": 0, "summary": "Get an item."},
	{"id": "utility_box", "name": "Utility Box", "rarity": "Silver", "hero": "", "occurrence": "Day 2+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
	{"id": "workshop", "name": "Workshop", "rarity": "Gold", "hero": "", "occurrence": "Day ?-2+", "min_day": 2, "max_day": 0, "summary": "Confirmed wiki event."},
]

static func get_event_specs() -> Array[Dictionary]:
	return EVENT_SPECS.duplicate(true)

static func get_event_specs_for_day(day: int, include_disabled: bool = false) -> Array[Dictionary]:
	var safe_day: int = maxi(day, 1)
	var specs: Array[Dictionary] = []
	for spec in EVENT_SPECS:
		if not include_disabled and spec.has("enabled") and not bool(spec.get("enabled")):
			continue
		var min_day: int = int(spec.get("min_day", 1))
		var max_day: int = int(spec.get("max_day", 0))
		if safe_day < min_day:
			continue
		if max_day > 0 and safe_day > max_day:
			continue
		specs.append(spec.duplicate(true))
	return specs

static func find_event_spec(event_id: String) -> Dictionary:
	for spec in EVENT_SPECS:
		if str(spec.get("id", "")) == event_id:
			return spec.duplicate(true)
	return {}
