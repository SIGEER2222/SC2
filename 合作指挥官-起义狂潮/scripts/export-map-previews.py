from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
MAPS_ROOT = ROOT / "Maps"
OUTPUT_DIR = ROOT / "web-launcher" / "exported-map-images"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"


def iter_maps() -> list[Path]:
    return sorted([path for path in MAPS_ROOT.glob("*_7vs1.SC2Map") if path.is_dir()], key=lambda path: path.name.lower())


def convert_preview(map_dir: Path) -> dict[str, object] | None:
    source = map_dir / "Minimap.tga"
    if not source.exists():
        return None

    output = OUTPUT_DIR / f"{map_dir.name}.png"
    with Image.open(source) as image:
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output)
        return {
            "id": map_dir.name,
            "source_path": str(source),
            "output_path": str(output),
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "format": image.format,
        }


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    converted: list[dict[str, object]] = []
    missing: list[str] = []

    for map_dir in iter_maps():
        result = convert_preview(map_dir)
        if result is None:
            missing.append(map_dir.name)
            continue
        converted.append(result)

    manifest = {
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(),
        "maps_root": str(MAPS_ROOT),
        "output_dir": str(OUTPUT_DIR),
        "maps": converted,
        "missing": missing,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps({
        "generated": len(converted),
        "missing": len(missing),
        "manifest": str(MANIFEST_PATH),
        "output_dir": str(OUTPUT_DIR),
    }, ensure_ascii=False))
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
