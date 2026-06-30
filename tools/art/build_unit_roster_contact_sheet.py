from __future__ import annotations

import argparse
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]


def parse_unit_resource(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    unit_id = path.stem
    display_name = unit_id.title()
    traits = ""
    sprite_path = ""
    id_match = re.search(r'^id\s*=\s*"([^"]+)"', text, re.MULTILINE)
    name_match = re.search(r'^name\s*=\s*"([^"]+)"', text, re.MULTILINE)
    traits_match = re.search(r"^traits\s*=\s*(.+)$", text, re.MULTILINE)
    sprite_match = re.search(r'^sprite_path\s*=\s*"([^"]*)"', text, re.MULTILINE)
    if id_match:
        unit_id = id_match.group(1)
    if name_match:
        display_name = name_match.group(1)
    if traits_match:
        traits = traits_match.group(1).replace("Array[String](", "").rstrip(")")
    if sprite_match:
        sprite_path = sprite_match.group(1)
    return {"id": unit_id, "name": display_name, "traits": traits, "sprite_path": sprite_path}


def find_asset(unit_id: str, assets_dir: Path) -> Path | None:
    # Most current playable units use conventional filenames; other units may
    # carry their source path directly in the UnitProfile sprite_path field.
    direct = assets_dir / f"{unit_id}.png"
    if direct.exists():
        return direct
    candidates = sorted(assets_dir.glob(f"{unit_id}*.png"))
    return candidates[0] if candidates else None


def draw_fit_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fill: tuple[int, int, int]) -> None:
    draw.text(xy, text[:52], fill=fill, font=ImageFont.load_default())


def make_tile(info: dict[str, str], asset_path: Path | None, tile_size: int) -> Image.Image:
    label_h = 62
    out = Image.new("RGBA", (tile_size, tile_size + label_h), (16, 17, 22, 255))
    draw = ImageDraw.Draw(out)
    if asset_path and asset_path.exists():
        image = Image.open(asset_path).convert("RGBA")
        image.thumbnail((tile_size - 20, tile_size - 20), Image.Resampling.LANCZOS)
        x = (tile_size - image.width) // 2
        y = (tile_size - image.height) // 2
        out.alpha_composite(image, (x, y))
    else:
        draw.rectangle((10, 10, tile_size - 10, tile_size - 10), outline=(220, 70, 70, 255), width=3)
        draw_fit_text(draw, (18, tile_size // 2 - 8), "missing asset", (240, 190, 190))

    draw.rectangle((0, tile_size, tile_size, tile_size + label_h), fill=(10, 11, 15, 255))
    draw_fit_text(draw, (10, tile_size + 8), f"{info['id']} - {info['name']}", (238, 239, 244))
    draw_fit_text(draw, (10, tile_size + 28), info.get("traits", ""), (185, 188, 198))
    if asset_path is not None:
        draw_fit_text(draw, (10, tile_size + 46), asset_path.name, (135, 140, 152))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--units-dir", type=Path, default=ROOT / "data" / "units")
    parser.add_argument("--other-units-dir", type=Path, default=ROOT / "data" / "other_units" / "other")
    parser.add_argument("--assets-dir", type=Path, default=ROOT / "assets" / "units")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--tile-size", type=int, default=190)
    parser.add_argument("--columns", type=int, default=6)
    args = parser.parse_args()

    unit_infos = [parse_unit_resource(path) for path in sorted(args.units_dir.glob("*.tres"))]
    other_unit_infos = []
    for path in sorted(args.other_units_dir.glob("*.tres")):
        info = parse_unit_resource(path) | {"other_unit": "true"}
        if not info.get("sprite_path"):
            continue
        other_unit_infos.append(info)
    tiles = []
    for info in unit_infos:
        tiles.append(make_tile(info, find_asset(info["id"], args.assets_dir), args.tile_size))
    for info in other_unit_infos:
        info["traits"] = f"other unit {info.get('traits', '')}".strip()
        tiles.append(make_tile(info, find_asset(info["id"], args.assets_dir), args.tile_size))

    extra_assets = []
    known_names = {Path(find_asset(info["id"], args.assets_dir) or "").name for info in unit_infos + other_unit_infos}
    for path in sorted(args.assets_dir.glob("*.png")):
        if path.name not in known_names and not path.name.endswith(".import"):
            extra_assets.append(path)
    for path in extra_assets:
        tiles.append(make_tile({"id": path.stem, "name": "extra texture", "traits": "not in data/units"}, path, args.tile_size))

    if not tiles:
        print("No unit tiles found.")
        return 1

    width = args.columns * args.tile_size
    rows = (len(tiles) + args.columns - 1) // args.columns
    height = rows * tiles[0].height
    sheet = Image.new("RGBA", (width, height), (16, 17, 22, 255))
    for index, tile in enumerate(tiles):
        x = (index % args.columns) * args.tile_size
        y = (index // args.columns) * tile.height
        sheet.alpha_composite(tile, (x, y))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output)
    print(args.output)
    print(f"playable_units={len(unit_infos)} other_units={len(other_unit_infos)} extras={len(extra_assets)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
