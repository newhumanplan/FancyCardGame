#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Optional
from urllib.parse import urlparse

import requests
from PIL import Image


REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "scripts/data/content_image_manifest.json"
MOBALYTICS_API_URL = "https://mobalytics.gg/api/the-bazaar/v1/graphql/query"
MOBALYTICS_QUERY = """
query StaticData($itemsFilter: TheBazaarItemsFilter, $skillsFilter: TheBazaarSkillsFilter) {
  game: theBazaar {
    theBazaarStaticData {
      theBazaarItems(filter: $itemsFilter) {
        data {
          slug
          name
          icon
        }
      }
      theBazaarSkills(filter: $skillsFilter) {
        data {
          slug
          name
          icon
        }
      }
    }
  }
}
"""
USER_AGENT = "Mozilla/5.0 (compatible; Codex FancyCardGame asset localizer)"
PNG_EXT = ".png"

ITEM_ALIAS_MAP: dict[str, dict[str, Any]] = {
    "nargile": {
        "source_type": "mobalytics_item",
        "slug": "zoot-flute",
        "source_note": (
            "Legacy repo supplemental item name. Current Bazaar-related databases expose the same "
            "effect profile as Zoot Flute on Mythkeeper."
        ),
    },
    "powder_flask": {
        "source_type": "mobalytics_item",
        "slug": "powder-horn",
        "source_note": (
            "Legacy repo item id. Current Bazaar-related databases expose the same item as Powder Horn."
        ),
    },
    "precision_callipers": {
        "source_type": "mobalytics_item",
        "slug": "precision-calipers",
        "source_note": "Localized from the current Precision Calipers spelling used by Bazaar-related sources.",
    },
    "red_piggles_x": {
        "source_type": "mobalytics_item",
        "slug": "red-piggles-r",
        "source_note": (
            "Legacy repo id shares the recorded wiki file Red_Piggles.png with red_piggles_r, so the "
            "confirmed Red Piggles R art is reused to preserve that shared source file."
        ),
    },
    "silencer": {
        "source_type": "direct_url",
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/g0cqnc4fzgb8y9c01d030skqq/Suppressor",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/02b9afaa89628a4b41b5a73d315f28dea13175c9@400S.webp",
        "resolved_from_id": "suppressor",
        "resolved_from_name": "Suppressor",
        "source_note": "Current Bazaar DB canonical name is Suppressor; localized into the legacy silencer repo id.",
    },
    "uzi": {
        "source_type": "mobalytics_item",
        "slug": "smg",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related databases expose the matching "
            "monster-board item as SMG."
        ),
    },
    "captain": {
        "source_type": "mobalytics_item",
        "slug": "captains-wheel",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related monster boards expose the matching "
            "Bloodreef Captain item as Captain's Wheel."
        ),
    },
    "clockwork_blade": {
        "source_type": "mobalytics_item",
        "slug": "clockwork-blades",
        "source_note": "Localized from the current Clockwork Blades canonical item entry.",
    },
    "crow": {
        "source_type": "mobalytics_item",
        "slug": "crows-nest",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related monster boards expose the matching "
            "Bloodreef Raider item as Crow's Nest."
        ),
    },
    "cryomastery": {
        "source_type": "mobalytics_skill",
        "slug": "cryomastery",
        "source_note": (
            "Repo supplemental item id is stale; current Bazaar-related monster boards expose Cryomastery "
            "only as a skill, so the canonical skill icon is reused for local display compatibility."
        ),
    },
    "fossilized_femur": {
        "source_type": "mobalytics_item",
        "slug": "magnus-femur",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related monster boards expose the matching "
            "Oasis Guardian drop as Magnus' Femur."
        ),
    },
    "hakurvian_launcher": {
        "source_type": "mobalytics_item",
        "slug": "harkuvian-launcher",
        "source_note": (
            "Localized from the current Harkuvian Launcher spelling used by Bazaar-related sources."
        ),
    },
    "ouroborus_statue": {
        "source_type": "mobalytics_item",
        "slug": "ouroboros-statue",
        "source_note": (
            "Localized from the current Ouroboros Statue spelling used by Bazaar-related sources."
        ),
    },
    "s_nest": {
        "source_type": "mobalytics_item",
        "slug": "crows-nest",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related monster boards expose the matching "
            "Bloodreef Captain item as Crow's Nest."
        ),
    },
    "s_ring": {
        "source_type": "mobalytics_item",
        "slug": "arkens-ring",
        "source_note": (
            "Legacy repo supplemental item id. Current Bazaar-related monster boards expose the matching "
            "Lord Arken item as Arken's Ring."
        ),
    },
}

SKILL_ALIAS_MAP: dict[str, dict[str, Any]] = {
    "heavy_weaponry": {
        "source_type": "mobalytics_skill",
        "slug": "heavy-firepower",
        "source_note": (
            "Legacy repo supplemental skill id. Current Bazaar-related sources expose the matching skill "
            "as Heavy Firepower."
        ),
    },
}

EVENT_LOCALIZE_MAP: dict[str, dict[str, Any]] = {
    "haddy": {
        "source_type": "direct_url",
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/10fv8k7xlqs9mhgpgscjkk2m6b8/Haddy",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/291d34bc2cfde21d1c9f30e3e3ab02613be49432_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Haddy event art.",
    },
    "flambe": {
        "source_type": "direct_url",
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/1899ty28g9xtd3205wmdpf6hzf9/Flambe",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/e40c88fb54e3c74c74a5ba3c47e21593957d8c78_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Flambe event art.",
    },
}

EVENT_UNAVAILABLE_MAP: dict[str, dict[str, Any]] = {
    "jules_cafe": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/1fwes2ti61nbpwscjf3k8u4fx/Jules%27-Cafe",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/39127b43b1ccc38733cc7197508d368ce18095ef_p@400.webp?v=6",
        "unavailable_reason": "reachable_bazaardb_asset_is_fully_transparent",
        "source_note": (
            "Bazaar DB serves a fully transparent Jules' Cafe event asset from this URL, so it remains "
            "explicitly unresolved instead of faking a usable localization."
        ),
    },
    "dooleys_workshop": {
        "source_name": "AFKHub",
        "source_page": "https://afkhub.com/the-bazaar/encounters/dooleys-workshop",
        "source_url": "https://afkhub.com/the-bazaar/_ipx/q_70%26s_150x150/Encounters/Event_DooleysWorkshop_PortraitBG.png",
        "unavailable_reason": "afkhub_timeout_from_executor_network",
        "source_note": (
            "AFKHub exposes the expected Dooley's Workshop encounter art, but repeated direct fetches "
            "from the executor network timed out."
        ),
    },
    "start_of_run": {
        "source_name": "The Bazaar Wiki",
        "source_page": "https://thebazaar.wiki.gg/wiki/Start_of_Run",
        "source_url": "https://thebazaar.wiki.gg/wiki/File:ENC_Event_VanessasQuarters_BG.png",
        "unavailable_reason": "wiki_image_host_blocked_from_executor_network",
        "source_note": (
            "The Start of Run page points at ENC Event VanessasQuarters BG art on the wiki image host, "
            "but the executor network cannot fetch wiki-hosted image binaries directly."
        ),
    },
}


MONSTER_LOCALIZE_MAP: dict[str, dict[str, Any]] = {
    "ventriloquist": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/3w6jcf0q5vxg3p0jufveo2q29/Ventriloquist",
        "source_url": "https://s.bazaardb.gg/v1/z11.0/c944bdfe7485aea389d2141ff2c468ae54d6e5f7_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Ventriloquist monster portrait.",
    },
    "greenheart_guardian": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/12xnhh8tx5zb66gy28329x0844v/Greenheart-Guardian",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/e8f77662d5e8b98f7cf1597599752edea6a051a5_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Greenheart Guardian monster portrait.",
    },
    "awakened_primordial": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/15y57m9q9qm7g7h6l06wxbms76t/Awakened-Primordial",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/72e92b216050cf29c33df312819f2da2c4bfd399_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Awakened Primordial monster portrait.",
    },
    "blowguns_trap": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/d1xxf87l420n68m5hg9nx0tshs/Mythkeeper",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/ae1d72739fc24e4b0b7f05bd9a872c276de3ac2f_p@256.webp?v=6",
        "source_note": "Localized from Bazaar DB Temple Expedition Blowguns Trap encounter art.",
    },
    "boulder_trap": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/d1xxf87l420n68m5hg9nx0tshs/Mythkeeper",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/bc07b69529f94c8a8da26be87286d7fd2a5f947a_p@256.webp?v=6",
        "source_note": "Localized from Bazaar DB Temple Expedition Boulder Trap encounter art.",
    },
    "cloudtop_admiral": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/ehlr6f8ulet3qgs68y9nvpqu5/Cloudtop-Admiral",
        "source_url": "https://s.bazaardb.gg/v0/z9.0a/encounter/4f1ab562b5afdad7a73c81a551e989ed232f566a@400.webp?v=2",
        "source_note": "Localized from the Bazaar DB Cloudtop Admiral monster portrait.",
    },
    "grandfather_klok": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/14v4tkc45vb1x4f8qx39gx7xyqm/Grandfather-Klok",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/7592400bb1d7905d52560cb31eb504ef0d8e7129_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Grandfather Klok monster portrait.",
    },
    "morguloth": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/53252nyjtm5ggjllpy51c1g8sz/Morguloth",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/547cb0f6d97e587b25d88a0cfc54e38eeb7af267_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Morguloth monster portrait.",
    },
    "mythkeeper": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/d1xxf87l420n68m5hg9nx0tshs/Mythkeeper",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/a2ca510f219d350b3bc161863c06b51517a26242_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Mythkeeper monster portrait.",
    },
    "product_demonstrator": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/8fcgxx4zq4zg0vbzpy7jwkzn6f/Product-Demonstrator",
        "source_url": "https://s.bazaardb.gg/v1/z13.0/0116cd2cbf8cbe6b389359e84c9f702b9619417a_p@400.webp?v=6",
        "source_note": "Localized from the current Bazaar DB Product Demonstrator monster portrait.",
    },
    "terrorform": {
        "source_name": "Bazaar DB",
        "source_page": "https://bazaardb.gg/card/3p7nwl8ed650uevb5uevb6csn/Terrorform",
        "source_url": "https://s.bazaardb.gg/v0/z10.0/encounter/d8f6df48bdebd8733429b5e6ea6aef3974cbebac@400.webp?v=2",
        "source_note": "Localized from the Bazaar DB Terrorform monster portrait.",
    },
}


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--status-dir", required=True)
    return parser.parse_args()


def _read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _normalize_name(value: str) -> str:
    filtered = []
    for char in value.lower():
        if char.isalnum():
            filtered.append(char)
    return "".join(filtered)


def _build_mobalytics_maps() -> dict[str, dict[str, dict[str, Any]]]:
    response = requests.post(
        MOBALYTICS_API_URL,
        json={
            "query": MOBALYTICS_QUERY,
            "variables": {
                "itemsFilter": {"page": {"all": True}},
                "skillsFilter": {"page": {"all": True}},
            },
        },
        headers={"User-Agent": USER_AGENT},
        timeout=120,
    )
    response.raise_for_status()
    payload = response.json()["data"]["game"]["theBazaarStaticData"]

    def build_maps(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
        by_slug: dict[str, dict[str, Any]] = {}
        by_name: dict[str, dict[str, Any]] = {}
        for row in rows:
            slug = str(row.get("slug", "")).strip()
            name = str(row.get("name", "")).strip()
            if slug:
                by_slug[slug] = row
            if name:
                by_name[_normalize_name(name)] = row
        return {"by_slug": by_slug, "by_name": by_name}

    return {
        "items": build_maps(payload["theBazaarItems"]["data"]),
        "skills": build_maps(payload["theBazaarSkills"]["data"]),
    }


def _infer_domain(url_or_page: str) -> str:
    parsed = urlparse(url_or_page)
    return parsed.netloc


def _download_file(url: str, suffix: str) -> Path:
    last_error: Optional[Exception] = None
    for _attempt in range(3):
        try:
            response = requests.get(url, headers={"User-Agent": USER_AGENT}, timeout=(15, 180))
            response.raise_for_status()
            handle, raw_path = tempfile.mkstemp(suffix=suffix)
            os.close(handle)
            temp_path = Path(raw_path)
            temp_path.write_bytes(response.content)
            return temp_path
        except requests.RequestException as exc:
            last_error = exc
    raise RuntimeError("download failed for %s: %s" % (url, last_error))


def _convert_to_png(source_path: Path, destination_path: Path) -> None:
    destination_path.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["sips", "-s", "format", "png", str(source_path), "--out", str(destination_path)],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "sips conversion failed for %s: %s %s"
            % (source_path, result.stdout.strip(), result.stderr.strip())
        )


def _is_nonempty_image(path: Path) -> bool:
    image = Image.open(path).convert("RGBA")
    for red, green, blue, alpha in image.getdata():
        if alpha and (red or green or blue):
            return True
    return False


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _local_res_path(local_path: str) -> Path:
    return REPO_ROOT / local_path


def _preserve_recorded_source(entry: dict[str, Any]) -> None:
    if "recorded_source_name" not in entry and entry.get("source_name"):
        entry["recorded_source_name"] = entry.get("source_name")
    if "recorded_source_page" not in entry and entry.get("source_page"):
        entry["recorded_source_page"] = entry.get("source_page")
    if "recorded_source_url" not in entry and entry.get("source_url"):
        entry["recorded_source_url"] = entry.get("source_url")
    if "recorded_source_domain" not in entry and entry.get("source_domain"):
        entry["recorded_source_domain"] = entry.get("source_domain")


def _update_localized_entry(
    entry: dict[str, Any],
    destination_local_path: str,
    source_name: str,
    source_page: str,
    source_url: str,
    source_note: str,
    resolved_from_id: str = "",
    resolved_from_name: str = "",
) -> None:
    destination = _local_res_path(destination_local_path)
    entry["status"] = "confirmed_local"
    entry["before_local_path"] = destination_local_path
    entry["local_path"] = destination_local_path
    entry["bytes"] = destination.stat().st_size
    entry["sha256"] = _sha256(destination)
    _preserve_recorded_source(entry)
    entry["source_name"] = source_name
    entry["source_page"] = source_page
    entry["source_url"] = source_url
    entry["source_domain"] = _infer_domain(source_url or source_page)
    entry["source_resolution_note"] = source_note
    if resolved_from_id:
        entry["resolved_from_id"] = resolved_from_id
    if resolved_from_name:
        entry["resolved_from_name"] = resolved_from_name
    entry.pop("unavailable_reason", None)


def _mark_unavailable(
    entry: dict[str, Any],
    source_name: str,
    source_page: str,
    source_url: str,
    reason: str,
    note: str,
) -> None:
    _preserve_recorded_source(entry)
    entry["status"] = "unavailable_after_research"
    entry["source_name"] = source_name
    entry["source_page"] = source_page
    entry["source_url"] = source_url
    entry["source_domain"] = _infer_domain(source_url or source_page)
    entry["unavailable_reason"] = reason
    entry["source_resolution_note"] = note
    entry["local_path"] = ""
    entry.pop("bytes", None)
    entry.pop("sha256", None)


def _suffix_from_url(url: str, fallback: str) -> str:
    parsed = urlparse(url)
    path = parsed.path
    ext = Path(path).suffix.lower()
    return ext if ext else fallback


def _resolve_mobalytics_row(
    entry: dict[str, Any],
    manifest_maps: dict[str, dict[str, Any]],
    mobalytics_maps: dict[str, dict[str, dict[str, Any]]],
) -> tuple[dict[str, Any], str]:
    kind = entry["kind"]
    if kind == "item_icon":
        alias = ITEM_ALIAS_MAP.get(entry["id"])
        if alias:
            source_type = alias["source_type"]
            if source_type == "mobalytics_item":
                return mobalytics_maps["items"]["by_slug"][alias["slug"]], alias["source_note"]
            if source_type == "mobalytics_skill":
                return mobalytics_maps["skills"]["by_slug"][alias["slug"]], alias["source_note"]
        row = mobalytics_maps["items"]["by_slug"].get(entry["id"])
        if row is None:
            row = mobalytics_maps["items"]["by_name"].get(_normalize_name(entry["name"]))
        if row is None:
            raise KeyError("No Mobalytics item source for %s" % entry["id"])
        return row, "Localized from current Mobalytics Bazaar item data."

    if kind == "skill_icon":
        alias = SKILL_ALIAS_MAP.get(entry["id"])
        if alias:
            return mobalytics_maps["skills"]["by_slug"][alias["slug"]], alias["source_note"]
        row = mobalytics_maps["skills"]["by_slug"].get(entry["id"])
        if row is None:
            row = mobalytics_maps["skills"]["by_name"].get(_normalize_name(entry["name"]))
        if row is None:
            raise KeyError("No Mobalytics skill source for %s" % entry["id"])
        return row, "Localized from current Mobalytics Bazaar skill data."

    raise KeyError("Unsupported kind for Mobalytics resolution: %s" % kind)


def _direct_source_for_item(entry_id: str) -> dict[str, Any]:
    alias = ITEM_ALIAS_MAP.get(entry_id)
    if alias is None or alias["source_type"] != "direct_url":
        raise KeyError(entry_id)
    return alias


def _target_local_path(entry: dict[str, Any]) -> str:
    if entry["kind"] == "monster_portrait":
        return "assets/art/monsters/wiki/%s%s" % (entry["id"], PNG_EXT)
    return "assets/art/%s/wiki/%s%s" % (
        "events" if entry["kind"] == "event_art" else ("items" if entry["kind"] == "item_icon" else "skills"),
        entry["id"],
        PNG_EXT,
    )


def _download_and_convert(url: str, destination_local_path: str) -> None:
    destination = _local_res_path(destination_local_path)
    suffix = _suffix_from_url(url, ".bin")
    temp_source = _download_file(url, suffix=suffix)
    try:
        _convert_to_png(temp_source, destination)
    finally:
        if temp_source.exists():
            temp_source.unlink()


def _rebuild_summary(entries: list[dict[str, Any]]) -> dict[str, Any]:
    counts: Counter[str] = Counter()
    by_kind: dict[str, Counter[str]] = defaultdict(Counter)
    for entry in entries:
        status = str(entry.get("status", ""))
        kind = str(entry.get("kind", ""))
        counts[status] += 1
        by_kind[kind][status] += 1
    return {
        "total": len(entries),
        "counts": dict(sorted(counts.items())),
        "by_kind": {kind: dict(sorted(counter.items())) for kind, counter in sorted(by_kind.items())},
    }


def main() -> None:
    args = _parse_args()
    status_dir = REPO_ROOT / args.status_dir
    status_dir.mkdir(parents=True, exist_ok=True)

    manifest = _read_json(MANIFEST_PATH)
    entries: list[dict[str, Any]] = manifest["entries"]
    before_summary = json.loads(json.dumps(manifest.get("summary", {})))
    entry_by_key = {(entry["kind"], entry["id"]): entry for entry in entries}
    mobalytics_maps = _build_mobalytics_maps()

    localized_assets: list[dict[str, Any]] = []
    unavailable_assets: list[dict[str, Any]] = []

    in_scope_remote = [
        entry
        for entry in entries
        if entry.get("kind") in {"item_icon", "skill_icon", "event_art"}
        and entry.get("status") == "confirmed_remote_only"
    ]

    # Localize standard item and skill icons, plus alias-driven repo ids.
    for entry in in_scope_remote:
        if entry["kind"] not in {"item_icon", "skill_icon"}:
            continue

        destination_local_path = _target_local_path(entry)
        alias = ITEM_ALIAS_MAP.get(entry["id"]) if entry["kind"] == "item_icon" else SKILL_ALIAS_MAP.get(entry["id"])

        if alias and alias["source_type"] == "direct_url":
            source_name = str(alias["source_name"])
            source_page = str(alias["source_page"])
            source_url = str(alias["source_url"])
            source_note = str(alias["source_note"])
            _download_and_convert(source_url, destination_local_path)
            _update_localized_entry(
                entry,
                destination_local_path,
                source_name=source_name,
                source_page=source_page,
                source_url=source_url,
                source_note=source_note,
                resolved_from_id=str(alias.get("resolved_from_id", "")),
                resolved_from_name=str(alias.get("resolved_from_name", "")),
            )
        else:
            row, source_note = _resolve_mobalytics_row(entry, entry_by_key, mobalytics_maps)
            source_url = str(row["icon"])
            source_name = "Mobalytics Bazaar GraphQL"
            source_page = MOBALYTICS_API_URL
            _download_and_convert(source_url, destination_local_path)
            _update_localized_entry(
                entry,
                destination_local_path,
                source_name=source_name,
                source_page=source_page,
                source_url=source_url,
                source_note=source_note,
                resolved_from_id=str(row.get("slug", "")),
                resolved_from_name=str(row.get("name", "")),
            )

        localized_assets.append(
            {
                "kind": entry["kind"],
                "id": entry["id"],
                "name": entry["name"],
                "local_path": entry["local_path"],
                "source_name": entry["source_name"],
                "source_page": entry["source_page"],
                "source_url": entry["source_url"],
            }
        )

    # Localize event art with confirmed usable direct assets.
    for event_id, source_info in EVENT_LOCALIZE_MAP.items():
        entry = entry_by_key[("event_art", event_id)]
        if str(entry.get("status", "")) == "confirmed_local" and str(entry.get("local_path", "")):
            continue
        destination_local_path = _target_local_path(entry)
        _download_and_convert(str(source_info["source_url"]), destination_local_path)
        if not _is_nonempty_image(_local_res_path(destination_local_path)):
            _mark_unavailable(
                entry,
                source_name=str(source_info["source_name"]),
                source_page=str(source_info["source_page"]),
                source_url=str(source_info["source_url"]),
                reason="downloaded_asset_is_visually_empty",
                note="Downloaded asset converted successfully but contains no visible non-transparent pixels.",
            )
            unavailable_assets.append(
                {
                    "kind": entry["kind"],
                    "id": entry["id"],
                    "name": entry["name"],
                    "reason": entry["unavailable_reason"],
                    "source_name": entry["source_name"],
                    "source_page": entry["source_page"],
                    "source_url": entry["source_url"],
                }
            )
            continue
        _update_localized_entry(
            entry,
            destination_local_path,
            source_name=str(source_info["source_name"]),
            source_page=str(source_info["source_page"]),
            source_url=str(source_info["source_url"]),
            source_note=str(source_info["source_note"]),
        )
        localized_assets.append(
            {
                "kind": entry["kind"],
                "id": entry["id"],
                "name": entry["name"],
                "local_path": entry["local_path"],
                "source_name": entry["source_name"],
                "source_page": entry["source_page"],
                "source_url": entry["source_url"],
            }
        )

    # Localize monster portraits with confirmed direct source assets.
    for monster_id, source_info in MONSTER_LOCALIZE_MAP.items():
        entry = entry_by_key[("monster_portrait", monster_id)]
        if str(entry.get("status", "")) == "confirmed_local" and str(entry.get("local_path", "")):
            continue
        destination_local_path = _target_local_path(entry)
        destination = _local_res_path(destination_local_path)
        if not destination.exists() or not _is_nonempty_image(destination):
            try:
                _download_and_convert(str(source_info["source_url"]), destination_local_path)
            except Exception as exc:
                _mark_unavailable(
                    entry,
                    source_name=str(source_info["source_name"]),
                    source_page=str(source_info["source_page"]),
                    source_url=str(source_info["source_url"]),
                    reason="source_download_failed",
                    note="Confirmed source URL could not be downloaded from executor network: %s" % exc,
                )
                unavailable_assets.append(
                    {
                        "kind": entry["kind"],
                        "id": entry["id"],
                        "name": entry["name"],
                        "reason": entry["unavailable_reason"],
                        "source_name": entry["source_name"],
                        "source_page": entry["source_page"],
                        "source_url": entry["source_url"],
                    }
                )
                continue
        if not _is_nonempty_image(destination):
            _mark_unavailable(
                entry,
                source_name=str(source_info["source_name"]),
                source_page=str(source_info["source_page"]),
                source_url=str(source_info["source_url"]),
                reason="downloaded_asset_is_visually_empty",
                note="Downloaded monster portrait converted successfully but contains no visible non-transparent pixels.",
            )
            unavailable_assets.append(
                {
                    "kind": entry["kind"],
                    "id": entry["id"],
                    "name": entry["name"],
                    "reason": entry["unavailable_reason"],
                    "source_name": entry["source_name"],
                    "source_page": entry["source_page"],
                    "source_url": entry["source_url"],
                }
            )
            continue
        _update_localized_entry(
            entry,
            destination_local_path,
            source_name=str(source_info["source_name"]),
            source_page=str(source_info["source_page"]),
            source_url=str(source_info["source_url"]),
            source_note=str(source_info["source_note"]),
        )
        localized_assets.append(
            {
                "kind": entry["kind"],
                "id": entry["id"],
                "name": entry["name"],
                "local_path": entry["local_path"],
                "source_name": entry["source_name"],
                "source_page": entry["source_page"],
                "source_url": entry["source_url"],
            }
        )

    # Explicitly preserve unresolved event art instead of faking completion.
    for event_id, source_info in EVENT_UNAVAILABLE_MAP.items():
        entry = entry_by_key[("event_art", event_id)]
        _mark_unavailable(
            entry,
            source_name=str(source_info["source_name"]),
            source_page=str(source_info["source_page"]),
            source_url=str(source_info["source_url"]),
            reason=str(source_info["unavailable_reason"]),
            note=str(source_info["source_note"]),
        )
        unavailable_assets.append(
            {
                "kind": entry["kind"],
                "id": entry["id"],
                "name": entry["name"],
                "reason": entry["unavailable_reason"],
                "source_name": entry["source_name"],
                "source_page": entry["source_page"],
                "source_url": entry["source_url"],
            }
        )

    manifest["summary"] = _rebuild_summary(entries)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    report_payload = {
        "before_summary": before_summary,
        "after_summary": manifest["summary"],
        "localized_assets": localized_assets,
        "unavailable_assets": unavailable_assets,
    }
    _write_json(status_dir / "downloaded_assets.json", report_payload)
    _write_json(status_dir / "source_manifest.json", manifest)


if __name__ == "__main__":
    main()
