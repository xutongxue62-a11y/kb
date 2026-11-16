"""Read current evidence, preserve latest player files, and record v13 changes."""
from pathlib import Path
from datetime import datetime
import hashlib
import json
import re
import shutil

root = Path(__file__).resolve().parents[1]
baseline = root.parent / "原始人大作战_快照" / "character_loot_baseline_20261115_210401"
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
runner = (root / "tools/run_tests.ps1").read_text(encoding="utf-8-sig")
names = re.findall(r"'([a-z0-9_]+)'", runner.split("foreach ($testName in @(")[1].split("))")[0])
groups = []
for name in names:
    log = root / "logs" / f"v06_{name}.log"
    text = log.read_text(encoding="utf-8-sig")
    result = re.search(r"RESULT: (\d+) checks, (\d+) failures", text)
    assert result and int(result[2]) == 0 and not re.search(r"ERROR:|SCRIPT ERROR|FAIL:", text), name
    groups.append({"group": name, "checks": int(result[1]), "failures": 0, "log_sha256": sha(log)})

native_dir = root / "previews/character_loot_v13_v4"
native = json.loads((native_dir / "timeline.json").read_text(encoding="utf-8"))
assert native["failures"] == 0 and len(native["screenshots"]) == 16
assert all(any(s["name"] == f"{id}_02_combat" for s in native["screenshots"]) for id in ["caveman", "chief", "barbarian"])
native_log = (root / "logs/character_loot_native_v4.log").read_text(encoding="utf-8-sig")
assert not re.search(r"ERROR:|SCRIPT ERROR|FAIL:", native_log)
native_warnings = re.findall(r"^WARNING: (.+)$", native_log, re.M)
assert all(w.startswith("This control can't grab focus.") for w in native_warnings)
performance = json.loads((native_dir / "performance.json").read_text(encoding="utf-8"))
assert performance["count"] == performance["visible"] == 5000 and performance["uncollected_intact"]

old_assets = [f for f in (baseline / "assets").rglob("*") if f.is_file()]
assert all(sha(f) == sha(root / f.relative_to(baseline)) for f in old_assets), "An old asset changed"
ui = [f for f in (baseline / "src").glob("*.gd") if f.name.startswith("ui_") or f.name in ["hud.gd", "music_controller.gd", "loot_rules.gd", "armory.gd", "expanded_weapons.gd", "rules.gd", "effects.gd", "dino_view.gd"]]
assert all(sha(f) == sha(root / f.relative_to(baseline)) for f in ui), "Protected UI/music/gameplay source changed"

latest_dir = baseline.parent / datetime.now().strftime("character_loot_latest_player_%Y%m%d_%H%M%S")
latest_dir.mkdir()
player = []
for f in (root / "runtime/Godot/app_userdata").rglob("*.json"):
    if "saves" not in f.parts:
        continue
    target = latest_dir / f.relative_to(root)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(f, target)
    original = baseline / f.relative_to(root)
    player.append({"path": str(f.relative_to(root)), "sha256": sha(f), "backup": str(target), "same_as_baseline": original.exists() and sha(f) == sha(original)})
    assert sha(f) == sha(target)

manifest = json.loads((root / "assets/characters/v13/portrait_manifest.json").read_text(encoding="utf-8"))
for item in manifest["characters"].values():
    assert sha(root / item["body"].removeprefix("res://")) == item["body_sha256"]
    assert sha(root / item["portrait"].removeprefix("res://")) == item["portrait_sha256"]

report = {"verified_at": datetime.now().astimezone().isoformat(), "baseline": str(baseline), "groups": groups, "total_checks": sum(g["checks"] for g in groups), "native": native, "native_fixture_focus_warnings": {"count":len(native_warnings),"note":"The v4 capture helper attempted grab_focus on FOCUS_NONE buttons. Native interactions and all 49 assertions passed. The redundant helper call was removed; product UI code is unchanged."}, "performance": performance, "unchanged_old_asset_files": len(old_assets), "unchanged_ui_music_and_gameplay_files": len(ui), "player_files": player, "source_sha256": {str(f.relative_to(root)): sha(f) for f in (root / "src").glob("*.gd")}, "review": {"independent_read_only": True, "fixed_p2": "Portrait right-hand clipping; 560x560 export, transparent margins tested", "remaining_p1_p2": 0}, "user_visual_acceptance_verified": False, "subjective_listening_verified": False, "save_limits": "50000 physical pickups / 8MiB file safety validation; no runtime auto-credit cap"}
(root / "docs/character_loot_v13_verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
(latest_dir / "manifest.json").write_text(json.dumps(player, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"groups": len(groups), "checks": report["total_checks"], "native_checks": native["checks"], "old_assets_unchanged": len(old_assets), "protected_source_unchanged": len(ui), "latest_player_files": len(player), "player_unchanged": all(f["same_as_baseline"] for f in player), "review_p1_p2": 0}))
