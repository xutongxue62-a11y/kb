"""Record actual v0.11 regression, capture and pre-relaunch preservation evidence."""
from pathlib import Path
import hashlib
import json
import re
from datetime import datetime

root = Path(__file__).resolve().parents[1]
baseline = json.loads((root / "docs/v11_baseline.json").read_text(encoding="utf-8-sig"))
manifest = json.loads((Path(baseline["snapshot"]) / "manifest.json").read_text(encoding="utf-8-sig"))
groups = "rules scene controls attack_links growth feedback impact progression armory save_store hud_navigation campaign frontend ui_motion ui_audio home_v09 chest_pickup sprite_edges dodge music world_camera battle_ui_v10 map_chunks terrain_physics growth_v11 supports_v11 ui_v11".split()
report = {"version":"0.11", "recorded_at":datetime.now().astimezone().isoformat(), "baseline":baseline["snapshot"], "groups":[]}
for group in groups:
    path = root / "logs" / ("v06_" + group + ".log")
    log = path.read_text(encoding="utf-8-sig")
    result = re.search(r"RESULT: (\d+) checks, (\d+) failures", log)
    assert result and int(result[2]) == 0 and not re.search(r"ERROR:|SCRIPT ERROR|FAIL:",log), group
    report["groups"].append({"group":group,"checks":int(result[1]),"failures":int(result[2]),"log":str(path.relative_to(root))})
report["total_checks"] = sum(row["checks"] for row in report["groups"])
report["native"] = json.loads((root / "previews/v11_native_v3/timeline.json").read_text(encoding="utf-8"))
native_log = (root / "logs/v11_native_v3.log").read_text(encoding="utf-8")
assert not re.search(r"ERROR:|SCRIPT ERROR|WARNING:|FAIL:",native_log)
assert report["native"]["failures"] == 0
report["native"]["log_clean"] = True
report["media"] = json.loads((root / "previews/v11_native_v3_metadata.json").read_text(encoding="utf-8"))
report["listening_verified"] = False
report["player_acceptance_verified"] = False
report["review"] = {"independent_read_only":True,"initial_p2":"Music context did not refresh on home/pause navigation","fixed_and_regression_tested":True,"final_incremental_p1_p2":0}
report["preservation_before_normal_relaunch"] = {"assets":[],"player_json":[]}
for relative, old in manifest.items():
    category = "assets" if relative.startswith("assets\\") else ("player_json" if relative.startswith("runtime\\") else None)
    if category is None: continue
    current = root / relative
    digest = hashlib.sha256(current.read_bytes()).hexdigest()
    assert digest == old["sha256"], "Preservation mismatch: " + relative
    report["preservation_before_normal_relaunch"][category].append({"file":relative,"sha256":digest})
report["source_sha256"] = {str(path.relative_to(root)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((root / "src").glob("*.gd"))}
report["art_prompts"] = "assets/supports/v11/generation_prompts.json"
report["art_qc"] = "assets/supports/v11/asset_qc.json"
report["music_manifest"] = "assets/music/v11/manifest.json"
target = root / "docs/v11_verification.json"
target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"groups":len(groups),"checks":report["total_checks"],"native_checks":report["native"]["checks"],"preserved_assets":len(report["preservation_before_normal_relaunch"]["assets"]),"preserved_player_json":len(report["preservation_before_normal_relaunch"]["player_json"]),"video_seconds":report["media"]["seconds"]}))
