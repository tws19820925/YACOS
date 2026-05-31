from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from PIL import Image


DISPLAY_WATERMARK_TEXT = "\u00a9arcadia-labs"
TAROT_WIDTH = 360
OMIKUJI_WIDTH = 320


@dataclass(frozen=True)
class GalleryItem:
    name: str
    source_file: str
    group: str


MAJOR_TAROT = [
    ("愚者", "fool"),
    ("魔術師", "magician"),
    ("女教皇", "high_priestess"),
    ("女帝", "empress"),
    ("皇帝", "emperor"),
    ("教皇", "hierophant"),
    ("恋人", "lovers"),
    ("戦車", "chariot"),
    ("力", "strength"),
    ("隠者", "hermit"),
    ("運命の輪", "wheel_of_fortune"),
    ("正義", "justice"),
    ("吊るされた男", "hanged_man"),
    ("死神", "death"),
    ("節制", "temperance"),
    ("悪魔", "devil"),
    ("塔", "tower"),
    ("星", "star"),
    ("月", "moon"),
    ("太陽", "sun"),
    ("審判", "judgement"),
    ("世界", "world"),
]

SUITS = [
    ("ワンド", "wands"),
    ("カップ", "cups"),
    ("ソード", "swords"),
    ("ペンタクル", "pentacles"),
]

RANKS = [
    ("A", "ace"),
    ("2", "two"),
    ("3", "three"),
    ("4", "four"),
    ("5", "five"),
    ("6", "six"),
    ("7", "seven"),
    ("8", "eight"),
    ("9", "nine"),
    ("10", "ten"),
    ("ペイジ", "page"),
    ("ナイト", "knight"),
    ("クイーン", "queen"),
    ("キング", "king"),
]

OMIKUJI = [
    ("大吉", "daikichi"),
    ("吉", "kichi"),
    ("中吉", "chukichi"),
    ("小吉", "shokichi"),
    ("末吉", "suekichi"),
    ("凶", "kyo"),
    ("だいたい吉", "yacos_kichi"),
]


def tarot_items() -> list[GalleryItem]:
    items: list[GalleryItem] = [
        GalleryItem(name, f"tarot_card_{key}.webp", "大アルカナ")
        for name, key in MAJOR_TAROT
    ]
    for suit_name, suit_key in SUITS:
        for rank_name, rank_key in RANKS:
            items.append(
                GalleryItem(
                    f"{suit_name}{rank_name}",
                    f"tarot_card_{suit_key}_{rank_key}.webp",
                    suit_name,
                )
            )
    return items


def omikuji_items() -> list[GalleryItem]:
    return [
        GalleryItem(name, f"omikuji_paper_{key}.webp", "おみくじ")
        for name, key in OMIKUJI
    ]


def resize_to_width(image: Image.Image, width: int) -> Image.Image:
    ratio = width / image.width
    height = round(image.height * ratio)
    return image.resize((width, height), Image.Resampling.LANCZOS)


def process_item(
    item: GalleryItem,
    source_dir: Path,
    output_dir: Path,
    collection: str,
    width: int,
    quality: int,
) -> dict[str, object]:
    source_path = source_dir / item.source_file
    if not source_path.exists():
        raise FileNotFoundError(f"Missing source image: {source_path}")

    output_path = output_dir / collection / item.source_file
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with Image.open(source_path) as source:
        resized = resize_to_width(source, width)
        if resized.mode not in ("RGB", "RGBA"):
            resized = resized.convert("RGBA")
        resized.save(output_path, "WEBP", quality=quality, method=4)

    repo_root = output_dir.parent.parent
    return {
        "name": item.name,
        "group": item.group,
        "file": output_path.relative_to(repo_root).as_posix(),
        "sourceFile": item.source_file,
        "width": resized.width,
        "height": resized.height,
        "bytes": output_path.stat().st_size,
    }


def parse_args() -> argparse.Namespace:
    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parent
    default_source = repo_root.parent / "yacos_fortune_telling" / "app" / "src" / "main" / "res" / "drawable-nodpi"
    default_output = repo_root / "assets" / "ritual"

    parser = argparse.ArgumentParser(description="Build resized public tarot and omikuji gallery assets.")
    parser.add_argument("--source-dir", type=Path, default=default_source)
    parser.add_argument("--output-dir", type=Path, default=default_output)
    parser.add_argument("--quality", type=int, default=82)
    parser.add_argument("--updated-at", default=date.today().isoformat())
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    source_dir = args.source_dir.resolve()
    output_dir = args.output_dir.resolve()

    tarot = [
        process_item(item, source_dir, output_dir, "tarot", TAROT_WIDTH, args.quality)
        for item in tarot_items()
    ]
    omikuji = [
        process_item(item, source_dir, output_dir, "omikuji", OMIKUJI_WIDTH, args.quality)
        for item in omikuji_items()
    ]

    manifest = {
        "updatedAt": args.updated_at,
        "displayWatermark": DISPLAY_WATERMARK_TEXT,
        "watermarkMode": "html-overlay",
        "sourceDir": source_dir.as_posix(),
        "collections": {
            "tarot": {
                "expectedCount": 78,
                "items": tarot,
            },
            "omikuji": {
                "expectedCount": 7,
                "items": omikuji,
            },
        },
    }
    manifest_path = output_dir / "gallery_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"Generated {len(tarot)} tarot previews and {len(omikuji)} omikuji previews.")
    print("Display watermark mode: HTML overlay (copyright arcadia-labs).")
    print(f"Wrote {manifest_path}")


if __name__ == "__main__":
    main()
