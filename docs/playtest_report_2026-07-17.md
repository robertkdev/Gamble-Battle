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

A checked-in Windows Desktop export preset now targets `build/windows/GambleBattle.exe`, and `/build/` is ignored. No packaged executable was produced because export templates are not installed and the approved Godot MCP surfaces do not expose an export operation. Packaged startup, performance, distribution, and OS scaling therefore remain an environment/tooling gate rather than source-build acceptance.

The canonical vault validator is currently green; the three previously reported vault failures were stale, unrelated evidence and were not converted into project changes.
