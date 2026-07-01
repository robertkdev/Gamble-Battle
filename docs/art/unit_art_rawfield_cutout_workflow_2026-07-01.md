# Unit Art Raw-Field Cutout Workflow 2026-07-01

This is the current accepted cutout workflow after the Paisley inside-hole failure and the follow-up zoom-review batch. Use it for premium orange-backed unit art until a newer human-approved workflow replaces it.

## Default Cutout Command

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input <raw.png> --output <cutout.png> --mask-output <mask.png> --review-output <review.png> --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange --edge-orange-clean
```

## Existing-Cutout Post-Clean

Use this when the full BiRefNet cutout shape already looks good and only the final background residue needs cleanup.

```powershell
python tools\art\clean_unit_cutout_orange_edge.py --input <cutout.png> --raw-source <raw.png> --output <cutout_rawfieldclean.png> --review-output <cutout_rawfieldclean_review.png>
```

## Perfect Exit

Every sent or accepted transparent PNG must pass:

```powershell
python tools\art\audit_unit_cutout_orange_fringe.py --no-include-proof-matrix --cutout <cutout_rawfieldclean.png> --raw-source <raw.png> --strict-zero --fail-on-any-fail --output-dir <audit_dir>
```

The audit must report `flagged=0`, and the row must have:

- `edge_orange_pixels == 0`
- `soft_orange_pixels == 0`
- `raw_key_visible_pixels == 0`
- `visual_fringe_pixels == 0`

`raw_key_visible_pixels` means exact raw `#f84401` family pixels plus the border-connected raw orange background field. This is what catches internal holes between fingers, hair, jewelry, bubbles, sleeves, props, and thin silhouette gaps.

## Human Review Packet

For user zoom review, send:

- A black-background contact sheet for fast scanning.
- Each full-size transparent PNG as a Telegram document, not a photo, so alpha and resolution survive.
- Do not replace `assets/units/*.png` until the user explicitly approves the specific unit swap.

## Current Evidence

The accepted-for-now review batch lives at:

`outputs/art_pipeline/style_validation/unit_cutout_zoom_batch_2026_07_01/`

Strict batch audit:

`outputs/art_pipeline/style_validation/unit_cutout_zoom_batch_2026_07_01/strict_batch_audit/unit_art_cutout_orange_fringe_audit.md`

Result: `rows=7`, `flagged=0`.

Telegram review messages:

- Contact sheet: `163`
- Creep: `164`
- Kythera: `165`
- Sari: `166`
- Morrak: `167`
- Teller: `168`
- Hexeon: `169`
- Korath: `170`
