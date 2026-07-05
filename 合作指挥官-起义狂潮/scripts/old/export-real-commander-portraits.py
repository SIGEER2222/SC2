from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "web-launcher" / "exported-real-commander-images"
MANIFEST_PATH = OUTPUT_DIR / "manifest.json"

SOURCE_ROOTS = [
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\tools\launcher_mpq\Assets\Textures"),
    Path(r"C:\Users\22448\Downloads\重生虫心0.71汉化版（新）\reborn_workrepo\整理输出\合作指挥官-起义狂潮\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
    Path(r"C:\Users\22448\Downloads\合作指挥官版起义狂潮0.81\Mods\XM\XMCore.SC2Mod\Assets\Textures"),
]

COMMANDER_SPECS = [
    {"runtime": "ZergAbathur", "name": "阿巴瑟", "source": "ui_btn_commanderportrait_abathur.dds", "output": "ZergAbathur.png"},
    {"runtime": "ProtossAlarak", "name": "阿拉纳克", "source": "ui_btn_commanderportrait_alarak.dds", "output": "ProtossAlarak.png"},
    {"runtime": "ProtossArtanis", "name": "阿塔尼斯", "source": "ui_btn_commanderportrait_artanis.dds", "output": "ProtossArtanis.png"},
    {"runtime": "ZergDehaka", "name": "德哈卡", "source": "ui_btn_commanderportrait_dehaka.dds", "output": "ZergDehaka.png"},
    {"runtime": "ProtossFenix", "name": "菲尼克斯", "source": "ui_btn_commanderportrait_fenix.dds", "output": "ProtossFenix.png"},
    {"runtime": "TerranHorner", "name": "汉与霍纳", "source": "ui_btn_commanderportrait_hanandhorner.dds", "output": "TerranHorner.png"},
    {"runtime": "ProtossKarax", "name": "凯拉克斯", "source": "ui_btn_commanderportrait_karax.dds", "output": "ProtossKarax.png"},
    {"runtime": "ZergKerrigan", "name": "凯瑞甘", "source": "ui_btn_commanderportrait_kerrigan.dds", "output": "ZergKerrigan.png"},
    {"runtime": "TerranMengsk", "name": "蒙斯克", "source": "ui_btn_commanderportrait_mengsk.dds", "output": "TerranMengsk.png"},
    {"runtime": "TerranNova", "name": "诺娃", "source": "ui_btn_commanderportrait_nova.dds", "output": "TerranNova.png"},
    {"runtime": "TerranRaynor", "name": "雷诺", "source": "ui_btn_commanderportrait_raynor.dds", "output": "TerranRaynor.png"},
    {"runtime": "ZergStetmann", "name": "斯台特曼", "source": "ui_btn_commanderportrait_stetmann.dds", "output": "ZergStetmann.png"},
    {"runtime": "ZergStukov", "name": "斯托科夫", "source": "ui_btn_commanderportrait_stukov.dds", "output": "ZergStukov.png"},
    {"runtime": "TerranSwann", "name": "斯旺", "source": "ui_btn_commanderportrait_swann.dds", "output": "TerranSwann.png"},
    {"runtime": "TerranTychus", "name": "泰凯斯", "source": "ui_btn_commanderportrait_tychus.dds", "output": "TerranTychus.png"},
    {"runtime": "ProtossVorazun", "name": "沃拉尊", "source": "ui_btn_commanderportrait_vorazun.dds", "output": "ProtossVorazun.png"},
    {"runtime": "ZergZagara", "name": "扎加拉", "source": "ui_btn_commanderportrait_zagara.dds", "output": "ZergZagara.png"},
    {"runtime": "ProtossZeratul", "name": "泽拉图", "source": "ui_btn_commanderportrait_zeratul.dds", "output": "ProtossZeratul.png"},
]


def resolve_source(filename: str) -> Path | None:
    for root in SOURCE_ROOTS:
        candidate = root / filename
        if candidate.exists():
            return candidate
    return None


def convert_dds(source: Path, target: Path) -> dict[str, object]:
    with Image.open(source) as image:
        target.parent.mkdir(parents=True, exist_ok=True)
        image.save(target)
        return {
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "format": image.format,
        }


def main() -> int:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, object] = {
        "generated_at": None,
        "output_dir": str(OUTPUT_DIR),
        "source_roots": [str(path) for path in SOURCE_ROOTS],
        "commanders": [],
        "missing": [],
    }

    generated: list[dict[str, object]] = []
    missing: list[dict[str, str]] = []

    for spec in COMMANDER_SPECS:
        source = resolve_source(spec["source"])
        if source is None:
            missing.append({
                "runtime": spec["runtime"],
                "name": spec["name"],
                "source": spec["source"],
            })
            continue

        target = OUTPUT_DIR / spec["output"]
        image_info = convert_dds(source, target)
        generated.append({
            "runtime": spec["runtime"],
            "name": spec["name"],
            "source_file": spec["source"],
            "source_path": str(source),
            "output_file": spec["output"],
            "output_path": str(target),
            **image_info,
        })

    from datetime import datetime, timezone

    manifest["generated_at"] = datetime.now(timezone.utc).astimezone().isoformat()
    manifest["commanders"] = generated
    manifest["missing"] = missing
    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print(json.dumps({
        "generated": len(generated),
        "missing": len(missing),
        "manifest": str(MANIFEST_PATH),
        "output_dir": str(OUTPUT_DIR),
    }, ensure_ascii=False))
    return 0 if not missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
