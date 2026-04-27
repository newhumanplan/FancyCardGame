#!/usr/bin/env python3
"""Fetch Bazaar wiki monster/item/skill data into generated Godot catalogs.

The Bazaar wiki does not expose a Cargo table for monsters. Monster pages do,
however, share a stable `{{Monster ...}}` template and embedded Cargo queries
for their items and skills. This script keeps that parsing in one place so the
game data can be regenerated and reviewed instead of hand-maintained.
"""

import argparse
import html
import json
import os
import re
import ssl
import sys
import time
import urllib.parse
import urllib.request


API_URL = "https://thebazaar.wiki.gg/api.php"
SOURCE_URL = "https://thebazaar.wiki.gg/wiki/Category:Monsters"
RARITY_ORDER = ["Bronze", "Silver", "Gold", "Diamond"]


def api_request(params):
	params = dict(params)
	params["format"] = "json"
	url = API_URL + "?" + urllib.parse.urlencode(params)
	request = urllib.request.Request(url, headers={"User-Agent": "FancyCardGame wiki catalog generator"})
	context = ssl._create_unverified_context()
	last_error = None
	for attempt in range(4):
		try:
			with urllib.request.urlopen(request, timeout=45, context=context) as response:
				return json.load(response)
		except Exception as exc:
			last_error = exc
			time.sleep(0.75 * (attempt + 1))
	raise last_error


def chunked(values, size):
	for index in range(0, len(values), size):
		yield values[index:index + size]


def idify(name):
	text = html.unescape(name).replace(" (Monster)", "")
	text = text.replace("&", " and ")
	text = re.sub(r"[^a-zA-Z0-9]+", "_", text.lower()).strip("_")
	return text


def scalar_field(wikitext, name):
	pattern = re.compile(r"^[ \t]*\|[ \t]*" + re.escape(name) + r"[ \t]*=[ \t]*(.*)$", re.MULTILINE)
	match = pattern.search(wikitext)
	if not match:
		return ""
	return match.group(1).strip()


def first_int(text, default=0):
	text = text or ""
	if "∞" in text:
		return 999999
	match = re.search(r"\d+", text)
	return int(match.group(0)) if match else default


def normalize_tier(text):
	text = text or ""
	match = re.search(r"\{\{\s*([A-Za-z]+)(?:-Rarity)?\s*\}\}", text)
	if match:
		value = match.group(1).capitalize()
		return value if value in RARITY_ORDER else "Bronze"
	value = re.sub(r"[^A-Za-z]", "", text).capitalize()
	return value if value in RARITY_ORDER else "Bronze"


def parse_page_names(wikitext, table_name):
	results = []
	seen = set()
	for block_match in re.finditer(r"\{\{#cargo_query:(.*?)\}\}", wikitext, re.IGNORECASE | re.DOTALL):
		block = block_match.group(1)
		if not re.search(r"(^|\n)\s*table\s*=\s*" + re.escape(table_name) + r"\b", block, re.IGNORECASE):
			continue
		names = []
		for in_match in re.finditer(r"_pageName\s+IN\s*\((.*?)\)", block, re.IGNORECASE | re.DOTALL):
			names.extend(re.findall(r"'([^']+)'", in_match.group(1)))
		for equals_match in re.finditer(r"_pageName\s*=\s*'([^']+)'", block, re.IGNORECASE):
			names.append(equals_match.group(1))
		for name in names:
			clean = html.unescape(name).strip()
			if clean and clean.lower() != "none" and clean not in seen:
				results.append(clean)
				seen.add(clean)
	return results


def clean_effect_text(text):
	text = html.unescape(text or "")
	text = re.sub(r"<br\s*/?>", ". ", text, flags=re.IGNORECASE)
	text = re.sub(r"\[\[File:[^\]]+\]\]", "", text, flags=re.IGNORECASE)
	text = re.sub(r"<[^>]+>", "", text)
	text = text.replace("'''", "")
	text = re.sub(r"\[\[[^|\]]+\|([^\]]+)\]\]", r"\1", text)
	text = re.sub(r"\[\[([^\]]+)\]\]", r"\1", text)
	text = re.sub(r"\s+", " ", text)
	text = text.replace(" .", ".").strip()
	return text


def parse_number_series(raw_text):
	text = clean_effect_text(raw_text)
	values = []
	for part in re.split(r"\s*/\s*", text):
		match = re.search(r"-?\d+(?:\.\d+)?", part)
		if not match:
			continue
		value = float(match.group(0))
		if value.is_integer():
			value = int(value)
		values.append(value)
	return values


def parse_slash_field(raw_text, prefer_float=False):
	text = clean_effect_text(raw_text)
	if not text:
		return []
	values = parse_number_series(text)
	if prefer_float:
		return [float(value) for value in values]
	return [int(value) for value in values]


def first_series_after_keyword(effect, keyword, suffix=None):
	if suffix:
		pattern = re.compile(
			re.escape(keyword) + r"\s+((?:-?\d+(?:\.\d+)?\s*/\s*)*-?\d+(?:\.\d+)?)\s+" + suffix,
			re.IGNORECASE,
		)
	else:
		pattern = re.compile(
			re.escape(keyword) + r"\s+((?:-?\d+(?:\.\d+)?\s*/\s*)*-?\d+(?:\.\d+)?)",
			re.IGNORECASE,
		)
	match = pattern.search(effect)
	return parse_number_series(match.group(1)) if match else []


def parse_deal_damage(effect):
	match = re.search(r"Deal\s+((?:\d+(?:\.\d+)?\s*/\s*)*\d+(?:\.\d+)?)\s+Damage", effect, re.IGNORECASE)
	return parse_number_series(match.group(1)) if match else []


def parse_gain_regen(effect):
	match = re.search(
		r"(?:Gain|have)\s+((?:\d+(?:\.\d+)?\s*/\s*)*\d+(?:\.\d+)?)\s+(?:Regen|Regeneration)",
		effect,
		re.IGNORECASE,
	)
	return parse_number_series(match.group(1)) if match else []


def parse_tempo(effect, keyword):
	match = re.search(
		re.escape(keyword) + r"\s+(all|an|a|the|your|enemy|(?:\d+(?:\.\d+)?\s*/\s*)*\d+(?:\.\d+)?)"
		r"(?:[^.]{0,80}?)for\s+((?:\d+(?:\.\d+)?\s*/\s*)*\d+(?:\.\d+)?)\s+second",
		effect,
		re.IGNORECASE,
	)
	if not match:
		return [], []
	raw_count = match.group(1).lower()
	if raw_count in ["all"]:
		count = [99]
	elif raw_count in ["an", "a", "the", "your", "enemy"]:
		count = [1]
	else:
		count = parse_number_series(raw_count)
	duration = parse_number_series(match.group(2))
	return count, duration


def parse_item_mechanics(row):
	effect = clean_effect_text(row.get("effects", ""))
	mechanics = {}
	for key, values in [
		("damage", parse_deal_damage(effect)),
		("shield", first_series_after_keyword(effect, "Shield")),
		("heal", first_series_after_keyword(effect, "Heal")),
		("burn", first_series_after_keyword(effect, "Burn")),
		("poison", first_series_after_keyword(effect, "Poison")),
		("regen", parse_gain_regen(effect)),
	]:
		if values:
			mechanics[key] = values
	slow_count, slow_duration = parse_tempo(effect, "Slow")
	freeze_count, freeze_duration = parse_tempo(effect, "Freeze")
	haste_count, haste_duration = parse_tempo(effect, "Haste")
	if slow_count:
		mechanics["slow"] = slow_count
		mechanics["slow_duration"] = slow_duration or [1]
	if freeze_count:
		mechanics["freeze"] = freeze_count
		mechanics["freeze_duration"] = freeze_duration or [1]
	if haste_count:
		mechanics["haste"] = haste_count
		mechanics["haste_duration"] = haste_duration or [1]
	crit = first_series_after_keyword(effect, "Crit Chance")
	if not crit:
		match = re.search(r"((?:\d+(?:\.\d+)?\s*/\s*)*\d+(?:\.\d+)?)\s*%\s+Crit", effect, re.IGNORECASE)
		if match:
			crit = parse_number_series(match.group(1))
	if crit:
		mechanics["crit"] = crit
	return mechanics


def first_series_value(values):
	if not values:
		return 0
	return int(values[0])


def parse_skill_mechanics(row):
	effect = clean_effect_text(row.get("effects", ""))
	mechanics = {}
	match = re.search(r"At the start of each fight,\s*Poison\s+((?:\d+\s*/\s*)*\d+)", effect, re.IGNORECASE)
	if match:
		mechanics["start_poison"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"At the start of each fight,\s*Burn\s+((?:\d+\s*/\s*)*\d+)", effect, re.IGNORECASE)
	if match:
		mechanics["start_burn"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"At the start of each fight,\s*Shield\s+((?:\d+\s*/\s*)*\d+)", effect, re.IGNORECASE)
	if match:
		mechanics["start_shield"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"Burn items have \+((?:\d+\s*/\s*)*\d+)\s+Burn", effect, re.IGNORECASE)
	if match:
		mechanics["burn_bonus"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"Poison items have \+((?:\d+\s*/\s*)*\d+)\s+Poison", effect, re.IGNORECASE)
	if match:
		mechanics["poison_bonus"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"Shield items have \+((?:\d+\s*/\s*)*\d+)\s+Shield", effect, re.IGNORECASE)
	if match:
		mechanics["shield_bonus"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"Weapons have \+((?:\d+\s*/\s*)*\d+)\s+Damage", effect, re.IGNORECASE)
	if match:
		mechanics["damage_bonus"] = first_series_value(parse_number_series(match.group(1)))
	match = re.search(r"Weapons have \+((?:\d+\s*/\s*)*\d+)\s*%\s+Crit", effect, re.IGNORECASE)
	if match:
		mechanics["crit_bonus"] = first_series_value(parse_number_series(match.group(1)))
	return mechanics


def cargo_query_all(table, fields, where):
	rows = []
	offset = 0
	while True:
		data = api_request({
			"action": "cargoquery",
			"tables": table,
			"fields": fields,
			"where": where,
			"limit": 500,
			"offset": offset,
		})
		batch = [entry.get("title", {}) for entry in data.get("cargoquery", [])]
		rows.extend(batch)
		if len(batch) < 500:
			break
		offset += 500
	return rows


def cargo_query_titles(table, fields, titles):
	rows = []
	seen = set()
	for batch in chunked(sorted(titles), 35):
		quoted = []
		for title in batch:
			quoted.append("'" + title.replace("'", "\\'") + "'")
		where = "%s._pageName IN (%s)" % (table, ",".join(quoted))
		data = api_request({
			"action": "cargoquery",
			"tables": table,
			"fields": fields,
			"where": where,
			"limit": 500,
		})
		for entry in data.get("cargoquery", []):
			row = entry.get("title", {})
			title = html.unescape(row.get("title", ""))
			if title and title not in seen:
				rows.append(row)
				seen.add(title)
		time.sleep(0.05)
	return rows


def fetch_monster_pages():
	members = []
	cmcontinue = None
	while True:
		params = {
			"action": "query",
			"list": "categorymembers",
			"cmtitle": "Category:Monsters",
			"cmlimit": 500,
		}
		if cmcontinue:
			params["cmcontinue"] = cmcontinue
		data = api_request(params)
		members.extend([m for m in data.get("query", {}).get("categorymembers", []) if m.get("ns") == 0])
		if "continue" not in data:
			break
		cmcontinue = data["continue"]["cmcontinue"]
	titles = [m["title"] for m in members]
	pages = {}
	for batch in chunked(titles, 45):
		data = api_request({
			"action": "query",
			"prop": "revisions",
			"rvprop": "content",
			"rvslots": "main",
			"titles": "|".join(batch),
			"formatversion": "2",
		})
		for page in data.get("query", {}).get("pages", []):
			if "revisions" in page:
				pages[page["title"]] = page["revisions"][0]["slots"]["main"]["content"]
		time.sleep(0.05)
	return pages


def parse_monsters(pages):
	monsters = []
	for page, wikitext in pages.items():
		name = scalar_field(wikitext, "title") or page
		name = name.replace("{{PAGENAME}}", page).replace(" (Monster)", "").strip()
		item_names = parse_page_names(wikitext, "items")
		skill_names = parse_page_names(wikitext, "skills")
		monsters.append({
			"id": idify(name),
			"page": page,
			"name": name,
			"level": first_int(scalar_field(wikitext, "level"), 0),
			"health": first_int(scalar_field(wikitext, "health"), 100),
			"gold": first_int(scalar_field(wikitext, "gold"), 0),
			"xp": first_int(scalar_field(wikitext, "exp"), 0),
			"tier": normalize_tier(scalar_field(wikitext, "tier")),
			"image_file": scalar_field(wikitext, "image").replace("File:", "").strip(),
			"layout_image_file": scalar_field(wikitext, "layoutimg").replace("File:", "").strip(),
			"skill_names": skill_names,
			"item_names": item_names,
		})
	monsters.sort(key=lambda entry: (entry["level"] if entry["level"] > 0 else 999, entry["name"]))
	return monsters


def normalize_item_row(row):
	name = html.unescape(row.get("title", "")).strip()
	effect = clean_effect_text(row.get("effects", ""))
	spec = {
		"id": idify(name),
		"name": name,
		"image_file": html.unescape(row.get("image", "")).replace("File:", "").strip(),
		"size": html.unescape(row.get("size", "Small") or "Small").strip() or "Small",
		"starting_tier": normalize_tier(row.get("starting tier", row.get("starting_tier", "Bronze"))),
		"cost": parse_slash_field(row.get("cost", "")),
		"cooldown": parse_slash_field(row.get("cooldown", ""), True),
		"ammo": parse_slash_field(row.get("ammo", "")),
		"tags": [part.strip() for part in html.unescape(row.get("type", "")).split(",") if part.strip()],
		"collection": html.unescape(row.get("collection", "")).strip(),
		"effect": effect,
	}
	spec.update(parse_item_mechanics(row))
	return spec


def normalize_skill_row(row):
	name = html.unescape(row.get("title", "")).strip()
	spec = {
		"id": idify(name),
		"name": name,
		"image_file": html.unescape(row.get("image", "")).replace("File:", "").strip(),
		"starting_tier": normalize_tier(row.get("starting tier", row.get("starting_tier", "Bronze"))),
		"tags": [part.strip() for part in html.unescape(row.get("type", "")).split(",") if part.strip()],
		"collection": html.unescape(row.get("collection", "")).strip(),
		"effect": clean_effect_text(row.get("effects", "")),
	}
	spec.update(parse_skill_mechanics(row))
	return spec


def gd_string(value):
	return json.dumps(value, ensure_ascii=False)


def gd_variant(value):
	if isinstance(value, dict):
		parts = []
		for key in sorted(value.keys()):
			parts.append("%s: %s" % (gd_string(key), gd_variant(value[key])))
		return "{%s}" % ", ".join(parts)
	if isinstance(value, list):
		return "[%s]" % ", ".join(gd_variant(item) for item in value)
	if isinstance(value, str):
		return gd_string(value)
	if isinstance(value, bool):
		return "true" if value else "false"
	if value is None:
		return "null"
	return str(value)


def render_gd(monsters, item_specs, skill_specs):
	lines = [
		"class_name WikiMonsterCatalog",
		"extends RefCounted",
		"",
		"# Generated by tools/fetch_bazaar_wiki_catalog.py from %s" % SOURCE_URL,
		"# Do not hand-edit large data arrays; regenerate them from the wiki source.",
		"",
		"const SOURCE_URL: String = %s" % gd_string(SOURCE_URL),
		"",
		"const MONSTER_SPECS: Array[Dictionary] = [",
	]
	for spec in monsters:
		entry = {
			"id": spec["id"],
			"page": spec["page"],
			"name": spec["name"],
			"level": spec["level"],
			"health": spec["health"],
			"gold": spec["gold"],
			"xp": spec["xp"],
			"tier": spec["tier"],
			"image_file": spec["image_file"],
			"layout_image_file": spec["layout_image_file"],
			"item_ids": [idify(name) for name in spec["item_names"] if idify(name)],
			"skill_ids": [idify(name) for name in spec["skill_names"] if idify(name)],
		}
		lines.append("\t%s," % gd_variant(entry))
	lines += [
		"]",
		"",
		"const MONSTER_ITEM_SPECS: Array[Dictionary] = [",
	]
	for spec in item_specs:
		lines.append("\t%s," % gd_variant(spec))
	lines += [
		"]",
		"",
		"const MONSTER_SKILL_SPECS: Array[Dictionary] = [",
	]
	for spec in skill_specs:
		lines.append("\t%s," % gd_variant(spec))
	lines += [
		"]",
		"",
		"static func get_monster_specs() -> Array[Dictionary]:",
		"\treturn MONSTER_SPECS.duplicate(true)",
		"",
		"static func get_item_specs() -> Array[Dictionary]:",
		"\treturn MONSTER_ITEM_SPECS.duplicate(true)",
		"",
		"static func get_skill_specs() -> Array[Dictionary]:",
		"\treturn MONSTER_SKILL_SPECS.duplicate(true)",
		"",
		"static func find_item_spec(item_id: String) -> Dictionary:",
		"\tfor spec in MONSTER_ITEM_SPECS:",
		"\t\tif str(spec.get(\"id\", \"\")) == item_id:",
		"\t\t\treturn spec.duplicate(true)",
		"\treturn {}",
		"",
		"static func find_skill_spec(skill_id: String) -> Dictionary:",
		"\tfor spec in MONSTER_SKILL_SPECS:",
		"\t\tif str(spec.get(\"id\", \"\")) == skill_id:",
		"\t\t\treturn spec.duplicate(true)",
		"\treturn {}",
		"",
		"static func find_monster_spec(monster_id: String) -> Dictionary:",
		"\tfor spec in MONSTER_SPECS:",
		"\t\tif str(spec.get(\"id\", \"\")) == monster_id:",
		"\t\t\treturn spec.duplicate(true)",
		"\treturn {}",
		"",
		"static func get_monster_specs_for_level(level: int) -> Array[Dictionary]:",
		"\tvar specs: Array[Dictionary] = []",
		"\tfor spec in MONSTER_SPECS:",
		"\t\tif int(spec.get(\"level\", 0)) == level:",
		"\t\t\tspecs.append(spec.duplicate(true))",
		"\treturn specs",
		"",
	]
	return "\n".join(lines)


def file_url(filename):
	if not filename or "{{" in filename:
		return ""
	title = "File:" + filename.replace("File:", "").strip()
	data = api_request({
		"action": "query",
		"titles": title,
		"prop": "imageinfo",
		"iiprop": "url",
		"formatversion": "2",
	})
	pages = data.get("query", {}).get("pages", [])
	if not pages or "imageinfo" not in pages[0]:
		return ""
	return pages[0]["imageinfo"][0].get("url", "")


def download_asset(filename, target_path):
	if os.path.exists(target_path):
		return False
	url = file_url(filename)
	if not url:
		return False
	request = urllib.request.Request(url, headers={"User-Agent": "FancyCardGame wiki asset downloader"})
	context = ssl._create_unverified_context()
	with urllib.request.urlopen(request, timeout=45, context=context) as response:
		data = response.read()
	with open(target_path, "wb") as output:
		output.write(data)
	return True


def download_assets(monsters, item_specs, skill_specs, project_root, asset_kind):
	targets = []
	if asset_kind in ["all", "monsters"]:
		for monster in monsters:
			targets.append(("assets/art/monsters/wiki", monster["id"], monster.get("image_file", "")))
	if asset_kind in ["all", "items"]:
		for item in item_specs:
			targets.append(("assets/art/items/wiki", item["id"], item.get("image_file", "")))
	if asset_kind in ["all", "skills"]:
		for skill in skill_specs:
			targets.append(("assets/art/skills/wiki", skill["id"], skill.get("image_file", "")))
	downloaded = 0
	for directory, source_id, filename in targets:
		if not filename or "{{" in filename or filename.lower() == "none":
			continue
		extension = os.path.splitext(filename)[1].lower() or ".png"
		if extension not in [".png", ".jpg", ".jpeg", ".webp"]:
			extension = ".png"
		output_dir = os.path.join(project_root, directory)
		os.makedirs(output_dir, exist_ok=True)
		target_path = os.path.join(output_dir, source_id + extension)
		try:
			if download_asset(filename, target_path):
				downloaded += 1
		except Exception as exc:
			print("asset download failed: %s -> %s" % (filename, exc), file=sys.stderr)
		time.sleep(0.03)
	return downloaded


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("--project-root", default=os.getcwd())
	parser.add_argument("--download-assets", action="store_true")
	parser.add_argument("--asset-kind", choices=["all", "monsters", "items", "skills"], default="all")
	args = parser.parse_args()
	project_root = os.path.abspath(args.project_root)

	pages = fetch_monster_pages()
	monsters = parse_monsters(pages)
	referenced_item_names = set()
	referenced_skill_names = set()
	for monster in monsters:
		referenced_item_names.update(monster["item_names"])
		referenced_skill_names.update(monster["skill_names"])

	item_fields = "items._pageName=title,image,effects,cooldown,ammo,type,size,cost,starting_tier,collection"
	skill_fields = "skills._pageName=title,image,effects,type,cost,starting_tier,collection"
	item_rows = cargo_query_all("items", item_fields, 'collection HOLDS "Monster"')
	skill_rows = cargo_query_all("skills", skill_fields, 'collection HOLDS "Monster"')
	item_rows.extend(cargo_query_titles("items", item_fields, referenced_item_names))
	skill_rows.extend(cargo_query_titles("skills", skill_fields, referenced_skill_names))

	item_seen = set()
	item_specs = []
	for row in item_rows:
		spec = normalize_item_row(row)
		if spec["id"] and spec["id"] not in item_seen:
			item_specs.append(spec)
			item_seen.add(spec["id"])
	item_specs.sort(key=lambda spec: spec["name"])

	skill_seen = set()
	skill_specs = []
	for row in skill_rows:
		spec = normalize_skill_row(row)
		if spec["id"] and spec["id"] not in skill_seen:
			skill_specs.append(spec)
			skill_seen.add(spec["id"])
	skill_specs.sort(key=lambda spec: spec["name"])

	output_path = os.path.join(project_root, "scripts/data/wiki_monster_catalog.gd")
	with open(output_path, "w", encoding="utf-8") as output:
		output.write(render_gd(monsters, item_specs, skill_specs))
	print("generated %s" % output_path, flush=True)
	print("monsters=%d items=%d skills=%d" % (len(monsters), len(item_specs), len(skill_specs)), flush=True)
	if args.download_assets:
		downloaded = download_assets(monsters, item_specs, skill_specs, project_root, args.asset_kind)
		print("downloaded_assets=%d" % downloaded, flush=True)


if __name__ == "__main__":
	main()
