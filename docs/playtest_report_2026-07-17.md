# Full playtest repair — 2026-07-18

## Outcome

The reported source-build blockers were integrated and finished on `codex/019f7639-37d-playtest`. CombatView and its shop/item/trait scene dependencies load, the Bonko betting and deterministic mid-run paths reach live combat, automatic capacity floors are asserted at stages 7/12/17/22, and the 144-sample odds calibration probe has zero timeouts.

The stale visual and interaction harnesses now follow `TitlePage`, control the forced opener before auto-start, match price-bearing progression button labels, respect live board capacity, and use an authoritative 1920x1080 SubViewport for arena geometry. Exit/loss tests now return truthful failure codes and explicitly tear down runtime state.

Combat Terms renders a recoverable `Nothing Found` card with `Clear Search`. Settings now persist 100%, 125%, and 150% UI scale choices and expose conflict-aware keyboard remapping for Confirm and Menu / Back, with cancel and reset behavior.

The real all-starter input path no longer inherits the manual first-shop opener from its quality-test subclass, so all 14 starters now reach and resolve the second combat. The post-fight result banner is also cleared when intermission ends instead of obscuring the planning/shop state.

## Fresh validation

- `TitleMenuSmoke`: OK, empty Godot error array.
- `AccessibilitySettingsSmoke`: OK; scale persistence, key persistence, conflict rejection, Escape cancel, reset, and non-key event preservation.
- `TitleMenuStateCapture`: OK, seven diagnostic state captures including the unmatched Combat Terms result and accessibility settings.
- `BettingEconomySmoke`: OK; CombatView opens and betting state locks/resolves correctly.
- `MidRunProgressionSmoke`: OK; five real post-opener battles reach Chapter 2 Stage 1.
- `NaturalRepresentativeMultiStageMainFlowSmoke`: OK; all six representative starters and seeds load CombatView and advance through the Chapter 1 multi-stage runway.
- `NaturalInputMainFlowSmoke`: PASS; all 14 starters reached the first shop and resolved the second combat with zero retries.
- `FirstShopChoiceQualitySmoke`: PASS, 41/45 choices advanced across nine starters.
- `ProductionRapidShopPressureSmoke`: OK; five purchases and capacity-correct deployment.
- `EndlessRuntimeIntegrationProbe`: PASS; exact capacity floors 6/7/8/9 at stages 7/12/17/22.
- `TeamOddsCalibrationProbe`: PASS, 144 samples, predicted 50.0%, observed 50.7%, aggregate gap 0.7%, Brier 0.136, zero timeouts; largest reported bucket gap 17.7 points.
- `CombatArenaBoundsSmoke`: OK at an authoritative 1920x1080 viewport.
- `CompactViewportVisualAuditSmoke`: OK, five diagnostic captures, no ObjectDB leak warning.
- `ExitFlowSmoke` and `LossScreenSmoke`: OK behaviorally with empty Godot error arrays.
- `RoleMatrixProbe6v6`: PASS for Bonko's role, goal, sustain, and ramp contracts; empty Godot error array.
- `RGATesting`: PASS, 48 rows, no failed/skipped/error metrics and an empty Godot error array.
- `Perf6v6`: PASS across neutral, burst, and peel cases; total runtime 8387 ms with stable frame-time distributions.
- `VisionCaptureSmoke`: PASS, six fresh 1920x1080 player-facing states: title, unit select, opening planning, system menu, post-fight shop, and scrolled unit detail.
- Visual Debug Harness run `main-vision-1df6d5a339`: evidence staging passed and an independent image review accepted all six states without findings.

## Evidence limits

The final `VisionCaptureSmoke` evidence uses the exact task editor's live game viewport at 1920x1080 and is suitable for player-facing layout review. Windows physical-window capture still fails before input with `0x80004002`, so OS-compositor fidelity remains externally unaccepted; gameplay input itself is covered by the 14-starter natural-input smoke.

Framebuffer capture remains unavailable inside the legacy `ExitFlowSmoke` and `LossScreenSmoke` runners; their behavior is accepted, their screenshots are not. Raw `outputs/` captures remain intentionally ignored, while this reviewed report and the test contracts are normal Git evidence.

## Packaged Windows acceptance

With explicit user approval, the official Godot 4.5 stable export templates were hash-verified and installed without restarting Godot, Codex, or Windows. The final Windows export completed with exit code 0, zero export warnings/errors, and no `res://outputs/` evidence accidentally embedded.

The first packaged run exposed a systemic PCK discovery defect: exported resource directories enumerate imported resources as `.tres.remap` (and audio imports as `.wav.import`), while runtime catalogs only accepted source extensions. That left creeps, identity definitions, playable units, shop offers, items, audio, and endless-generation unit data undiscoverable in release builds. Runtime catalogs and their packaged probes now normalize remapped/imported entries back to loadable resource paths.

- Packaged `VisionCaptureSmoke`: PASS, six states at 1920x1080; the first shop contains purchasable unit offers and the planning timer reads `1:59`.
- Packaged `CompactViewportVisualAuditSmoke`: PASS, five 1280x720 states with all layout/overflow assertions green.
- Packaged `ItemTraitSystemsProbe`: PASS, 22 traits, 36 recipes, and 36 completed items.
- Packaged `AudioCatalogPackageProbe`: PASS, six discoverable streams.
- Packaged endless generation/runtime probes: PASS across 240 generated chapters and the first procedural transition.
- Packaged `Perf6v6`: PASS, all three deterministic cases consistent; final total runtime 5531 ms.
- Visible launch, close, relaunch, and second close: PASS; both close requests exited normally with no forced cleanup.
- Distribution roundtrip: the one-file ZIP extracts to a byte-identical EXE and the extracted build passes its audio probe.

Final local artifacts (intentionally ignored): `outputs/packaged_playtest/2026-07-18/dist/GambleBattle.exe` (SHA-256 `0C5A1007A1D504C59EF265860B176D5F591D306CB806819D2AA803902C44EA73`) and `GambleBattle-windows-x86_64.zip` (SHA-256 `661CF50D2F7D418FAED26EEFFD9D337C57C30F3B56C25AE2D1DFCD9B7006FF38`).

The packaged headless captures are diagnostic control maps, not final framebuffers. Actual visual fidelity is supported by the six editor-game framebuffer captures; packaged OS-compositor capture remains unavailable because Windows Graphics Capture returns `0x80004002` before input. This is an evidence limitation, not a known packaged gameplay failure.
