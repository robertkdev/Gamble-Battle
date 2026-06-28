# Unit Art Pipeline - 2026-06-28

## Current roster image findings

- All 22 playable unit textures in `assets/units/` are 1024 x 1024 PNGs.
- The game displays the full texture in unit slots, so transparent padding and baked backgrounds directly affect board readability.
- Most units are transparent cutouts. `assets/units/morrak.png` is the main technical outlier because it has a baked square background.
- Narrow units including Cashmere, Kythera, Korath, Totem, and Veyra read smaller in 96 px board tiles than the wider roster members.
- Active filenames still include odd generated names: `assets/units/korath (1).png` and `assets/units/sari (3).png`.
- Temporary analysis sheets from the first pass were written under `%LOCALAPPDATA%\Temp\gamble_battle_unit_image_analysis\`.

## Local generation setup

- ComfyUI Desktop is installed at `C:\Users\Flipm\AppData\Local\Programs\ComfyUI`.
- The restored runtime folder is `C:\Users\Flipm\Documents\ComfyUI`.
- API server command uses port `8188` to avoid the Godot AI MCP port:
  - `C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe`
  - `C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\main.py`
  - `--base-directory C:\Users\Flipm\Documents\ComfyUI`
  - `--front-end-root C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\web_custom_versions\desktop_app`
  - `--listen 127.0.0.1 --port 8188 --lowvram --reserve-vram 1.0`
- The desktop-pinned CUDA 12.9 Torch wheel did not support the GTX 1080 Ti (`sm_61`). The working install uses `torch==2.8.0+cu126`, `torchvision==0.23.0+cu126`, and `torchaudio==2.8.0+cu126`.
- `stabilityai/sdxl-turbo` is linked into `C:\Users\Flipm\Documents\ComfyUI\models\diffusers\sdxl-turbo`.

## Repeatable commands

Start ComfyUI headless:

```powershell
$base='C:\Users\Flipm\Documents\ComfyUI'
$py="$base\.venv\Scripts\python.exe"
$main='C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\main.py'
$front='C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\web_custom_versions\desktop_app'
$extra='C:\Users\Flipm\AppData\Roaming\ComfyUI\extra_models_config.yaml'
& $py $main --base-directory $base --user-directory "$base\user" --input-directory "$base\input" --output-directory "$base\output" --extra-model-paths-config $extra --front-end-root $front --listen 127.0.0.1 --port 8188 --lowvram --reserve-vram 1.0 --disable-auto-launch --log-stdout
```

Submit a unit-art prompt:

```powershell
.\tools\art\comfy_unit_prompt.ps1 -FilenamePrefix gamble_battle_unit_art_test -Seed 2606281010
```

Post-process a green-screen output into a 1024 x 1024 transparent unit texture:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\postprocess_unit_sprite.py C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_solo_muted_00001_.png outputs\art_pipeline\gamble_battle_unit_art_solo_muted_clean.png --preview outputs\art_pipeline\gamble_battle_unit_art_solo_muted_clean_preview.png --min-alpha-island-area 1600 --solid-keep-radius 28 --solid-alpha-threshold 176
```

## Verified proof

- ComfyUI API responded at `http://127.0.0.1:8188/system_stats`.
- Test prompt id: `f1f9d573-60d5-4cd3-9ac3-9c4bf327dd58`.
- ComfyUI output: `C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_test_00001_.png`.
- Runtime log reported `Prompt executed in 39.57 seconds`.
- Accepted usable local proof:
  - Raw ComfyUI output: `C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_solo_muted_00001_.png`.
  - Transparent 1024 px texture: `outputs/art_pipeline/gamble_battle_unit_art_solo_muted_clean.png`.
  - Tile readability preview: `outputs/art_pipeline/gamble_battle_unit_art_solo_muted_clean_preview.png`.

## Quality notes

- The local SDXL Turbo path is fast enough and works on the 1080 Ti. It is good for concept thumbnails, silhouettes, and quick sprite drafts.
- The first sample matched the dark gothic/autobattler direction but leaned too neon and line-art heavy compared with the current roster.
- For final-quality character edits, the best current target remains a stronger edit model such as Qwen-Image-Edit-2509 or FLUX.1 Kontext, ideally in a quantized Comfy workflow for this GPU. The restored Comfy runtime is now ready for that next model pass, but the available local cache did not contain the Qwen weights.
