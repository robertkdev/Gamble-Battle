from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageDraw, ImageFilter
from torchvision import transforms
from transformers import AutoModelForImageSegmentation


def extract_prediction(output: object) -> torch.Tensor:
    if isinstance(output, torch.Tensor):
        return output
    if isinstance(output, dict):
        for value in reversed(list(output.values())):
            try:
                return extract_prediction(value)
            except TypeError:
                continue
    if isinstance(output, (list, tuple)):
        for value in reversed(output):
            try:
                return extract_prediction(value)
            except TypeError:
                continue
    raise TypeError(f"Could not find tensor prediction in output type {type(output)!r}")


def fit_for_model(image: Image.Image, size: int) -> tuple[Image.Image, tuple[int, int]]:
    rgb = image.convert("RGB")
    return rgb.resize((size, size), Image.Resampling.BICUBIC), rgb.size


def checker(size: tuple[int, int], tile: int = 32) -> Image.Image:
    width, height = size
    out = Image.new("RGBA", size, (46, 50, 60, 255))
    draw = ImageDraw.Draw(out)
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            if (x // tile + y // tile) % 2 == 0:
                draw.rectangle((x, y, x + tile - 1, y + tile - 1), fill=(25, 28, 36, 255))
    return out


def defringe_orange_edges(source: Image.Image, mask: Image.Image) -> Image.Image:
    rgb = np.asarray(source.convert("RGB")).astype(np.int16)
    alpha = np.asarray(mask).astype(np.int16)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]

    orange_spill = (
        (red > 185)
        & (green > 55)
        & (green < 175)
        & (blue < 90)
        & ((red - green) > 55)
        & ((green - blue) > 25)
    )
    soft_edge = (alpha > 0) & (alpha < 245)
    alpha = np.where(orange_spill & soft_edge, np.minimum(alpha, 8), alpha)
    return Image.fromarray(np.clip(alpha, 0, 255).astype(np.uint8), "L")


def focused_orange_spill(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)

    bright = (
        (red > 175)
        & (green > 50)
        & (green < 150)
        & (blue < 95)
        & ((red - green) > 50)
        & ((green - blue) > 18)
    )
    dark = (
        (red > 85)
        & (green > 25)
        & (green < 118)
        & (blue < 78)
        & ((red - green) > 32)
        & ((green - blue) > 8)
    )
    saturated = ((red.astype(np.float32) - blue.astype(np.float32)) / np.maximum(red.astype(np.float32), 1.0)) > 0.42
    return (bright | dark) & saturated


def safety_orange_residue(rgb: np.ndarray) -> np.ndarray:
    red = rgb[:, :, 0].astype(np.int16)
    green = rgb[:, :, 1].astype(np.int16)
    blue = rgb[:, :, 2].astype(np.int16)

    safety_orange_like = (
        (red > 175)
        & (green > 35)
        & (green < 170)
        & (blue < 115)
        & ((red - green) > 42)
        & ((green - blue) > 10)
    )
    saturated = ((red.astype(np.float32) - blue.astype(np.float32)) / np.maximum(red.astype(np.float32), 1.0)) > 0.35
    return safety_orange_like & saturated


def alpha_edge_band(mask: Image.Image, radius: int) -> np.ndarray:
    alpha = np.asarray(mask).astype(np.uint8)
    foreground = Image.fromarray(np.where(alpha > 8, 255, 0).astype(np.uint8), "L")
    filter_size = max(3, radius * 2 + 1)
    if filter_size % 2 == 0:
        filter_size += 1
    dilated = np.asarray(foreground.filter(ImageFilter.MaxFilter(filter_size))) > 0
    eroded = np.asarray(foreground.filter(ImageFilter.MinFilter(filter_size))) > 0
    return dilated & ~eroded


def estimate_foreground_rgb(source: Image.Image, mask: Image.Image) -> np.ndarray:
    from pymatting import estimate_foreground_ml

    rgb = np.asarray(source.convert("RGB")).astype(np.float64) / 255.0
    alpha = np.asarray(mask).astype(np.float64) / 255.0
    foreground = estimate_foreground_ml(
        rgb,
        alpha,
        regularization=1e-5,
        n_small_iterations=10,
        n_big_iterations=2,
    )
    return np.clip(foreground * 255.0, 0, 255).astype(np.uint8)


def despill_orange_rgb(rgb: np.ndarray, source: Image.Image, mask: Image.Image) -> np.ndarray:
    raw_rgb = np.asarray(source.convert("RGB")).astype(np.uint8)
    alpha = np.asarray(mask).astype(np.uint8)
    near_background = Image.fromarray(np.where(alpha < 64, 255, 0).astype(np.uint8), "L")
    near_background = near_background.filter(ImageFilter.MaxFilter(13))

    target = focused_orange_spill(raw_rgb) & (np.asarray(near_background) > 0) & (alpha > 0)
    target |= focused_orange_spill(raw_rgb) & (alpha > 0) & (alpha < 220)

    out = rgb.copy().astype(np.float32)
    gray = out[:, :, 0] * 0.22 + out[:, :, 1] * 0.46 + out[:, :, 2] * 0.32
    out[target, 0] = gray[target] * 0.25
    out[target, 1] = gray[target] * 0.34
    out[target, 2] = np.maximum(out[target, 2], gray[target] * 0.85)
    return np.clip(out, 0, 255).astype(np.uint8)


def clean_edge_orange_rgb(rgb: np.ndarray, mask: Image.Image, radius: int) -> tuple[np.ndarray, int]:
    alpha = np.asarray(mask).astype(np.uint8)
    edge_band = alpha_edge_band(mask, radius)
    target = safety_orange_residue(rgb) & edge_band & (alpha > 0)

    out = rgb.copy().astype(np.float32)
    gray = out[:, :, 0] * 0.22 + out[:, :, 1] * 0.46 + out[:, :, 2] * 0.32
    out[target, 0] = gray[target] * 0.24
    out[target, 1] = gray[target] * 0.34
    out[target, 2] = np.maximum(out[target, 2], gray[target] * 0.86)
    return np.clip(out, 0, 255).astype(np.uint8), int(np.count_nonzero(target))


def preview_tile(cutout: Image.Image, background: Image.Image, label: str, tile_size: int) -> Image.Image:
    tile = Image.new("RGBA", (tile_size, tile_size + 46), (18, 19, 24, 255))
    bg = background.resize((tile_size, tile_size), Image.Resampling.BICUBIC).convert("RGBA")
    fg = cutout.resize((tile_size, tile_size), Image.Resampling.LANCZOS)
    bg.alpha_composite(fg)
    tile.alpha_composite(bg, (0, 0))
    draw = ImageDraw.Draw(tile)
    draw.rectangle((0, tile_size, tile_size, tile_size + 46), fill=(12, 13, 17, 255))
    draw.text((14, tile_size + 14), label, fill=(235, 236, 240, 255))
    return tile


def make_review_sheet(raw: Image.Image, mask: Image.Image, cutout: Image.Image, output: Path) -> None:
    tile_size = 384
    raw_tile = Image.new("RGBA", (tile_size, tile_size + 46), (18, 19, 24, 255))
    raw_tile.alpha_composite(raw.convert("RGBA").resize((tile_size, tile_size), Image.Resampling.LANCZOS))
    draw = ImageDraw.Draw(raw_tile)
    draw.rectangle((0, tile_size, tile_size, tile_size + 46), fill=(12, 13, 17, 255))
    draw.text((14, tile_size + 14), "raw", fill=(235, 236, 240, 255))

    mask_rgba = Image.merge("RGBA", (mask, mask, mask, Image.new("L", mask.size, 255)))
    mask_tile = Image.new("RGBA", (tile_size, tile_size + 46), (18, 19, 24, 255))
    mask_tile.alpha_composite(mask_rgba.resize((tile_size, tile_size), Image.Resampling.LANCZOS))
    draw = ImageDraw.Draw(mask_tile)
    draw.rectangle((0, tile_size, tile_size, tile_size + 46), fill=(12, 13, 17, 255))
    draw.text((14, tile_size + 14), "BiRefNet alpha", fill=(235, 236, 240, 255))

    tiles = [
        raw_tile,
        mask_tile,
        preview_tile(cutout, checker(cutout.size), "checker preview", tile_size),
        preview_tile(cutout, Image.new("RGBA", cutout.size, (0, 0, 0, 255)), "black preview", tile_size),
        preview_tile(cutout, Image.new("RGBA", cutout.size, (255, 255, 255, 255)), "white preview", tile_size),
    ]
    sheet = Image.new("RGBA", (tile_size * len(tiles), tile_size + 46), (18, 19, 24, 255))
    for index, tile in enumerate(tiles):
        sheet.alpha_composite(tile, (index * tile_size, 0))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--mask-output", required=True, type=Path)
    parser.add_argument("--review-output", required=True, type=Path)
    parser.add_argument("--model", default="ZhengPeng7/BiRefNet")
    parser.add_argument("--input-size", type=int, default=1024)
    parser.add_argument("--device", default="auto", choices=["auto", "cuda", "cpu"])
    parser.add_argument("--threshold", type=int, default=0)
    parser.add_argument("--feather", type=float, default=0.0)
    parser.add_argument("--defringe-orange", action="store_true")
    parser.add_argument("--foreground-ml", action="store_true")
    parser.add_argument("--despill-orange", action="store_true")
    parser.add_argument("--edge-orange-clean", action="store_true")
    parser.add_argument("--edge-clean-radius", type=int, default=4)
    args = parser.parse_args()

    raw = Image.open(args.input).convert("RGBA")
    model_image, original_size = fit_for_model(raw, args.input_size)

    device = "cuda" if args.device == "auto" and torch.cuda.is_available() else args.device
    if device == "auto":
        device = "cpu"

    model = AutoModelForImageSegmentation.from_pretrained(args.model, trust_remote_code=True)
    model.to(device)
    model.eval()

    transform = transforms.Compose(
        [
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
        ]
    )
    tensor = transform(model_image).unsqueeze(0).to(device)
    with torch.no_grad():
        pred = extract_prediction(model(tensor)).sigmoid().detach().cpu()[0].squeeze()

    arr = pred.numpy()
    while arr.ndim > 2:
        if arr.shape[0] == 1:
            arr = arr[0]
        elif arr.shape[-1] == 1:
            arr = arr[..., 0]
        else:
            arr = np.max(arr, axis=0)
    arr = (arr - arr.min()) / max(float(arr.max() - arr.min()), 1e-6)
    mask = Image.fromarray((arr * 255).astype(np.uint8), "L").resize(original_size, Image.Resampling.LANCZOS)
    if args.threshold > 0:
        mask = mask.point(lambda value: 255 if value >= args.threshold else 0)
    if args.feather > 0:
        mask = mask.filter(ImageFilter.GaussianBlur(args.feather))
    if args.defringe_orange:
        mask = defringe_orange_edges(raw, mask)

    rgb = estimate_foreground_rgb(raw, mask) if args.foreground_ml else np.asarray(raw.convert("RGB")).astype(np.uint8)
    if args.despill_orange:
        rgb = despill_orange_rgb(rgb, raw, mask)
    edge_orange_cleaned = 0
    if args.edge_orange_clean:
        rgb, edge_orange_cleaned = clean_edge_orange_rgb(rgb, mask, args.edge_clean_radius)

    cutout = Image.fromarray(rgb, "RGB").convert("RGBA")
    cutout.putalpha(mask)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.mask_output.parent.mkdir(parents=True, exist_ok=True)
    cutout.save(args.output)
    mask.save(args.mask_output)
    make_review_sheet(raw, mask, cutout, args.review_output)

    print(f"device={device}")
    print(f"model={args.model}")
    if args.edge_orange_clean:
        print(f"edge_orange_cleaned={edge_orange_cleaned}")
    print(args.output)
    print(args.mask_output)
    print(args.review_output)


if __name__ == "__main__":
    main()
