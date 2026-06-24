# Audio System (Sound Autoload)

This project provides a simple, modular audio system for playing SFX and other one‑shots from code, with support for:

- Concurrent playback (multiple sounds at once)
- Looping (stream loop flag or software fallback)
- Per‑play options (volume, pitch, bus, start position)
- Directory scanning of `res://assets/audio/**`

The audio system is available as a global autoload named `Sound`.

## Quick Start

Assets: drop `*.ogg`/`*.wav`/`*.mp3` under `res://assets/audio/…`. Subfolders are supported.

At runtime, the catalog scans this tree and exposes ids based on relative path (without extension), lowercased.

Example mapping:

- `res://assets/audio/ui/click.ogg` → id: `ui/click`
- `res://assets/audio/effects/explosion.wav` → id: `effects/explosion`

### Play a sound

```gdscript
# Simple play (Master bus)
var handle: int = Sound.play("ui/click")

# With options
Sound.play("effects/explosion", {
	"bus": "SFX",
	"volume_db": -6.0,
	"pitch_scale": 1.1,
})

# Convenience wrappers
Sound.play_id("ui/click", -3.0)         # volume_db only
Sound.play_loop("ambience/forest", -10.0, "Ambience")
```

### Stop / Adjust

```gdscript
var id := Sound.play("ui/click")
Sound.set_volume(id, -12.0)
Sound.stop(id)

Sound.stop_all() # emergency stop
```

### Bus routing by prefix

You can route whole folders to a bus without repeating options:

```gdscript
# Route everything under ui/* to the "UI" bus
Sound.set_bus_for_prefix("ui", "UI")

# Route effects/* to SFX by default
Sound.set_bus_for_prefix("effects", "SFX")

# Now this picks the bus automatically unless you override it in options
Sound.play("ui/click")
Sound.play("effects/explosion")
```

## API

All methods below are available on the `Sound` autoload:

- `play(key_or_path: String, options := {}) -> int`
  - `key_or_path`: `"folder/name"` or a full `res://` path.
  - `options` (optional): `{ bus: String, volume_db: float, pitch_scale: float, loop: bool, from_position: float }`.
  - Returns a handle (`int > 0`) if successful, `-1` otherwise.

- `play_id(key: String, volume_db := 0.0, loop := false, bus := "") -> int`
- `play_loop(key: String, volume_db := 0.0, bus := "") -> int`
- `stop(handle: int) -> void`
- `stop_all() -> void`
- `set_volume(handle: int, db: float) -> void`
- `set_default_bus(bus: String) -> void`
- `set_bus_for_prefix(prefix: String, bus: String) -> void`
- `list_ids() -> PackedStringArray`
- `has(key: String) -> bool`
- `reload() -> void` (re-scan assets)

Signals:

- `sound_started(id: int, key: String)`
- `sound_finished(id: int, key: String)` (reserved for future use)

## Design

- Catalog (`scripts/game/audio/audio_catalog.gd`): scans `res://assets/audio` recursively and keeps an id→`AudioStream` map.
- Player pool (`scripts/game/audio/sound_player_pool.gd`): creates `AudioStreamPlayer` nodes under the `Sound` autoload to allow overlapping playback. If a stream lacks a loop flag, a software loop is performed by restarting playback on the `finished` signal.
- Manager (`scripts/game/audio/sound_manager.gd`): small façade with a stable API.

## Conventions & Tips

- Use lowercase ids with forward slashes: `ui/click`, `effects/explosion`, `ambience/forest`.
- Prefer `.ogg` for SFX and `.wav` for very short UI cues only if size is acceptable.
- If you reorganize the `assets/audio` tree, call `Sound.reload()` or restart to refresh the catalog.
- For global mixing, create buses (e.g., UI/SFX/Ambience) and route by prefix.

## Troubleshooting

- Missing sound: ensure the file is under `res://assets/audio/…` and has a supported extension. Check `Sound.list_ids()`.
- No audio: confirm project has an active `Master` bus, and the target bus exists.
- Looping issues: some streams do not expose a `loop` property; the system falls back to software loop (restarting on finish).
