# Gamble Battle Starter Playtest Audit - 2026-06-24

Status: complete for the original 21-unit manual starter surface, with follow-up revalidation against the current branch. The current cost-tier branch exposes 12 level-1 starter-selectable units; the 9 cost-2 premium units and cost-3 Hexeon are no longer starter-visible at level 1. This document records real MCP-launched/manual UI play, external screenshot evidence captured from the MCP-launched debug window, supporting starter runner data, and later MCP validation after fixes landed. No gameplay code changes were made during the original manual audit.

## Evidence
- Manual MCP/Godot-AI UI screenshots: `outputs/audit_playtest/manual_runs/`
- External no-import screenshots after Godot editor import churn became suspect: `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\manual_runs\`
- Current live editor/debug screenshots after the cost-tier recheck: `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs\`
- Earlier manual screenshots and runner output: `outputs/audit_playtest/`
- Current live editor framebuffer captures: `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png`, `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png`, `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`
- Real-run populated loss overlay capture: `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.png` and `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.json`
- Current run-total loss modal screenshot and notes: `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png`, `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_summary.json`, and `outputs/audit_playtest/current_loss_modal_visual/notes.md`
- Supporting all-starter data: `outputs/audit_playtest/starter_audit_results.json`
- Supporting all-starter Main-flow replay data: `outputs/audit_playtest/all_starter_main_flow_audit/all_starter_main_flow_results.json`
- Supporting current shop/premium data: `outputs/audit_playtest/current_shop_audit_results.json`
- Supporting rapid rendered-shop input data: `outputs/audit_playtest/rapid_shop_input_audit/rapid_shop_input_results.json`
- Fresh live Main-flow screenshots and notes: `outputs/audit_playtest/live_flow_recheck_2026_06_25/`
- Fresh live cost-1 post-buy/deploy screenshots: `outputs/audit_playtest/live_deploy_recheck_2026_06_25/`
- Fresh live cost-2 Buy XP/deploy attempt screenshots and notes: `outputs/audit_playtest/live_cost2_recheck_2026_06_25/`
- Live-window fallback diagnostics: `outputs/audit_playtest/window_capture_2026_06_25/`
- Fresh shop spacing and first-fight placeholder screenshots: `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/`
- Current real-window deploy drag release recheck: `outputs/audit_playtest/current_deploy_drag_recheck/`
- Current system menu lighter-backdrop screenshot and notes: `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png`, `outputs/audit_playtest/current_system_menu_visual/current_system_menu_summary.json`, and `outputs/audit_playtest/current_system_menu_visual/notes.md`
- Debug audit QA exports: `user://audit_exports/audit_state_*.json`; `F8` opens the debug-only in-game Audit QA panel for state export, screenshot attempt, timer hold, restart, and speed controls.
- Live Audit QA panel screenshot proof: `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/01_panel_open.png`, `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/02_after_screenshot_click.png`, and `user://audit_exports/audit_shot_1782371342_158480.png`
- Duplicate scoreboard disambiguation validation: `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn`
- Current RoleMatrix detail data: `user://identity_reports/*.json`, `user://rga_smoke/<unit>/...`, and `C:\Users\Flipm\AppData\Roaming\Godot\app_userdata\Gamble Battle\logs\godot.log`
- Current RoleMatrix accepted-miss artifact: `outputs/audit_playtest/rga_accepted_misses_2026_06_25/`

## Current Revalidation After Follow-Up Fixes

Current branch snapshot: 2026-06-25 local audit branch after the Unit Select, deploy-assist/watchdog, and shop-spacing follow-ups; use `git log` / `git status` for the exact current commit and ahead count.

MCP validation run on 2026-06-24:
- `tests/visual/ActualRunLoopSmoke.tscn`: `ActualRunLoopSmoke: OK`; rerun on 2026-06-25 with `errors: []`, including first-deploy bench highlight and post-deploy highlight clearing assertions.
- `tests/rga_testing/ci/CostBalanceSmoke.tscn`: `CostBalanceSmoke: PASS units=22 tiers=1:12 2:9 3:1`
- `tests/rga_testing/ci/RoleMatrixSmoke.tscn`: `RoleMatrixSmoke: PASS (22 units)`; rerun on 2026-06-25 with `errors: []`
- `tests/rga_testing/validation/UnitStatAudit.tscn`: `UnitStatAudit: OK`
- `tests/visual/CombatWatchdogSmoke.tscn`: `CombatWatchdogSmoke: OK`; rerun on 2026-06-25 with `errors: []`
- `tests/visual/CombatResolvingFeedbackSmoke.tscn`: `CombatResolvingFeedbackSmoke: OK`; validates the immediate resolving label, elapsed resolving text, long-wait warning text, and watchdog fallback text.
- `tests/visual/PostCombatPlanningBeatSmoke.tscn`: `PostCombatPlanningBeatSmoke: OK`; validates that a post-win intermission beat appears before planning returns, then restores `Start Battle`, a full shop, and at least 55 seconds of planning time.
- `tests/visual/AxiomRetryEconomySmoke.tscn`: `AxiomRetryEconomySmoke: OK`; rerun on 2026-06-25 with `errors: []`, validating the support-starter retry economy after a forced opener defeat, helper purchase/deploy guidance, bench highlight clearing, and retry-fight progression back into a full Stage 2 planning shop.
- `tests/visual/DragGlobalReleaseSmoke.tscn`: `DragGlobalReleaseSmoke: OK` with `errors: []`; validates that a drag started on one control ends and emits a drop after global mouse release over a different tile.
- `tests/visual/UnitSelectSmoke.tscn`: `UnitSelectSmoke: OK`
- `tests/visual/UIThemeSmoke.tscn`: `UIThemeSmoke: OK`
- `tests/visual/UIThemeSmoke.tscn`: rerun on 2026-06-25 with `errors: []`, including shop-card gutter, command-strip spacing, first-fight placeholder prominence, and locked-placeholder click feedback assertions.
- `tests/visual/DevStarterInventorySmoke.tscn`: `DevStarterInventorySmoke: OK`; validates normal run inventory starts clean and starter item seeding only happens when `Items.DEV_STARTER_INVENTORY_ENABLED` is explicitly enabled.
- `tests/visual/LossScreenSmoke.tscn`: `LossScreenSmoke: OK`; later live editor run saved `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png`. Rerun on 2026-06-25 with `errors: []` now also covers run-total damage/kills surviving a later final-battle stats reset.
- `tests/visual/ExitFlowSmoke.tscn`: `ExitFlowSmoke: OK`; later live editor run saved `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png` and `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`.
- `tests/rga_testing/validation/StageProgressionProbe.tscn`: `StageProgressionProbe: PASS`
- `tests/rga_testing/validation/RewardsKillProbe.tscn`: `RewardsKillProbe: PASS`
- `tests/rga_testing/validation/RewardsActionsProbe.tscn`: `[RewardsTest] PASS`
- `tests/rga_testing/validation/CreepsProbe.tscn`: `CreepsProbe: PASS (spawned 4)`
- `tests/visual/AuditPanelSmoke.tscn`: `AuditPanelSmoke: OK`; rerun on 2026-06-25 with `errors: []`
- `git diff --check`: clean

Confirmed current fixes/coverage:
- Normal new runs start with clean item inventory; `Items.DEV_STARTER_INVENTORY_ENABLED` is currently false and `ActualRunLoopSmoke` asserts an empty starting inventory.
- The forced first fight now has an explicit `FIRST FIGHT` / `Win to open shop` placeholder, disabled opening shop buttons, and click/keyboard feedback on the locked placeholder.
- The actual run loop now covers repeated New Game resets, all-in loss cycles, first-board-unit drag repositioning, post-fight shop purchase, first-purchase deploy prompt, first-purchase bench-slot highlight, planning-time assist, bench-to-board drag, highlight clearing after deploy, and second-fight resolution.
- Real-window deploy recheck exposed and fixed a drag-release edge case: after an OS mouse drag began from a bench unit, releasing outside the source `UnitView` could leave a drag ghost stuck and the bought unit on the bench. `DragAndDroppable` now listens for global mouse motion/release only while a drag is active, and the patched OS-window pass moves Cashmere from bench to board.
- Combat no-progress and absolute timeout handling are covered by `CombatWatchdogSmoke`.
- Lower Unit Select stale-preview behavior is covered by `UnitSelectSmoke`.
- The new cost tiering pass is mechanically covered: 12 cost-1 units, 9 cost-2 units, and Hexeon as the single cost-3 unit. Level 1 shops sample only cost-1 units, and higher levels sample the intended tier mix.
- Targeted current Main-flow premium and natural-economy runners now cover the cost-2 path after leveling: Buy XP reserve-floor feedback at 4 gold, natural level 2 at Stage 1 Round 3 after a cost-1 helper and max-bet win, a level-2 cost-2 shop-card purchase, first-purchase deploy prompt, and bench-to-board drag.
- A targeted current Main-flow rapid-input runner now covers a same-frame burst across five rendered shop cards, five resulting bench units, five bench-to-board deploy attempts, and the next fight resolving. A follow-up audit-assisted OS-window pass now covers real mouse-coordinate burst buying across five visible shop cards in the debug window.
- Unit stats still come from role baselines rather than playable unit resources, as verified by `UnitStatAudit`.
- Stage progression, creep spawning, and creep reward actions now have focused pass signals.
- A debug-only `F8` Audit QA panel now provides in-game state JSON export, screenshot capture attempt with explicit headless/dummy skip reasons, planning-timer hold, New Run restart, and 1x/4x speed controls. `AuditPanelSmoke` verifies the panel stays hidden by default, exports parseable state, reports screenshot status safely, controls speed, holds the planning timer, and returns to Unit Select through New Run.
- The bottom shop/command band now has wider card gutters and command-control separation, covered by `UIThemeSmoke` assertions. The forced first-fight shop placeholder now uses a brighter border, larger `FIRST FIGHT` label, clearer `Win to open shop` hint, and direct feedback when clicked or activated from keyboard; fresh OS-window captures under `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/` confirm the locked opener and first real shop still fit the 1080p debug window.
- The Start Battle button still changes immediately to disabled `Combat Resolving...`; if combat keeps running past the short delay it now shows elapsed resolving seconds, then a `Still resolving` warning after 10 seconds. If the engine watchdog fires, the button switches to `Resolving fallback...` while the existing post-combat recovery finishes.
- The system menu pause overlay now uses a lighter backdrop alpha so the underlying Unit Select or combat state remains readable enough for resume/new-run context; `ExitFlowSmoke` asserts the backdrop stays in the intended alpha range.
- A non-broke Chapter 1 Stage 1 defeat now receives opening retry recovery up to 2 gold. `AxiomRetryEconomySmoke` proves Axiom's forced opener loss returns to a same-stage retry shop with 2 gold, buys a 1-cost helper while preserving 1 gold, shows deploy guidance, deploys the helper to board, clears the first-deploy highlight, wins the retry fight, and returns to a full Stage 2 planning shop.
- The defeat modal now separates run summary from final-battle ledger: summary lines use run totals (`Run Damage`, `Run Healing`, `Run Kills`, `Top Run Damage`), while the embedded player-only scoreboard is titled `Final Battle Damage`. `LossScreenSmoke` verifies previous-battle player damage remains visible after the current battle tracker resets.

Remaining audit gaps:
- The current validation now includes an automated Main-flow replay for all 12 current starters after the cost-tier and stage/reward changes, but not a fresh human real-window/screenshot replay of every starter.
- The previous dummy-renderer run could not capture loss/exit framebuffers, but later live editor and OS-window runs did. Current modal blockers are covered: the defeat modal screenshot is refreshed after the player-only loss scoreboard and Menu-behind-defeat fixes, and the separate system menu overlay now has fresh OS-window visual proof with the lighter backdrop over Unit Select.
- RoleMatrixSmoke passes all 22 units, but the fresh 2026-06-25 detail recheck found accepted lower-level `FAIL` spans inside aggregate passes. After subject-side filtering, goal-level ramp-applicability cleanup, live counterplay scenario generation, and hard-peel applicability filtering, 21 of 22 reports still contain 80 subject-side accepted spans, with zero non-ramp identities carrying `goal_*_ramp_*` diagnostics.
- Long manual play still has real-window fragility around timing/session capture, but first-purchase physical bench-to-board drag now has a targeted accepted OS-window pass after the global drag-release fix. Cost-1 post-buy bench/deploy, audit-assisted cost-2 buy/deploy, and audit-assisted rapid shop-card buying now have accepted OS-window evidence. Buy XP now has automated Main-flow proof for both the natural successful level-up and the 4-gold reserve-floor denial message. The debug Audit QA panel reduces the repeated-eval/session-capture dependency by moving state export, timer hold, restart, and speed controls into the running game.
- A follow-up `tests/visual/MainFlowVisualCapture.tscn` attempt could not produce fresh framebuffer screenshots under the MCP dummy renderer; the scene skipped all captures and emitted `texture_2d_get` null-parameter errors. Later live editor/debug-window runs did capture fresh Bonko and modal screenshots, but live capture remains session-sensitive. The Audit QA screenshot control skips safely with an explicit reason under dummy/headless renderers, and a 2026-06-25 real debug-window run verified the non-dummy save path by producing `user://audit_exports/audit_shot_1782371342_158480.png`.

## Current Audit Closure Matrix

This matrix reflects the current audit state after the 2026-06-25 live cost-2, Buy XP, and Start Battle transition follow-ups. It separates completed behavioral proof, audit-assisted live-window proof, and natural live-window proof, because those are not interchangeable.

| Audit surface | Current strongest evidence | Status | Remaining proof needed |
| --- | --- | --- | --- |
| Starter-select surface | Unit Select live screenshots and `UnitSelectSmoke` cover the current 12 cost-1 starter grid. | Covered for current cost-tier branch | None unless starter roster changes again. |
| Forced first fight and opening shop lockout | Live screenshots plus `ActualRunLoopSmoke` cover disabled opening shop controls and `Start Forced Fight`. `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/06_forced_first_fight_retry.png` refreshes the locked shop strip after the placeholder contrast pass. `UIThemeSmoke` now proves the locked placeholder is clickable/focusable and shows `First fight is forced. Win to open the shop.` | Covered behaviorally and visually | Preserve the explicit placeholder, tooltip, and click/keyboard feedback. |
| All current starters through first Main-flow loop | `AllStarterMainFlowAudit` covers 12 starters: Axiom retry plus 11 first-shop buy/deploy/second-fight paths. `AxiomRetryEconomySmoke` now covers the former outlier by proving the retry shop can buy/deploy a helper and then progress through the retry fight into a full Stage 2 planning shop after the nonlethal opening loss. | Covered behaviorally | Fresh human real-window replay of every starter remains optional but not mechanically required for current blockers. |
| Dev starter item inventory | `DevStarterInventorySmoke` proves `Items.DEV_STARTER_INVENTORY_ENABLED` defaults false, `reset_run()` keeps normal inventory and visible slots empty, and the starter inventory seeds only when that dev flag is explicitly enabled. `ActualRunLoopSmoke` also asserts new real Main-flow runs start with empty item inventory. | Covered behaviorally | Preserve the default-off dev inventory flag so normal playtests stay item-clean. |
| Cost-1 post-buy bench/deploy | Live Bonko-to-Brute run confirms purchase-to-bench and OS-level bench-to-board drag. `outputs/audit_playtest/current_deploy_drag_recheck/` adds a fresh real-window pass: the pre-fix OS drag left a ghost stuck while the unit stayed on bench; after the global release fix, an OS click bought Cashmere, the prompt appeared, and an OS drag moved Cashmere from bench to board with `completion_reported=true`. `ActualRunLoopSmoke` asserts the first-purchase prompt, bought bench-slot highlight, timer extension, bench-to-board drag, and highlight clearing after deploy. | Covered visually and behaviorally | Preserve global drag-release handling, board-cell guidance, and bench-slot guidance. Future manual passes can focus on speed/pressure polish rather than known drop correctness. |
| Cost-2 premium behavior after leveling | `PremiumDeployAuditRunner` repeatedly covers reserve-floor denial, level 2, cost-2 purchase, deploy prompt, and final board. `NaturalBuyXPAudit` proves a normal Bonko + cost-1 helper line can naturally reach `Gold: 6` at Stage 1 Round 3 and level to `Lvl 2 (2/6)`. `outputs/audit_playtest/live_cost2_recheck_2026_06_25/` includes audit-assisted live-window screenshots where OS clicks level to 2, reroll into 2g offers, buy Teller, and drag Teller to board. | Covered behaviorally and audit-assisted visually | Natural real-window screenshot of the Stage 1 Round 3 Buy XP success remains optional; the mechanical progression is now proven. |
| Buy XP live-window affordance | The first live attempt exposed stale UI after a raw `Economy.gold` write. The follow-up assist used `Economy.add_gold(...)`, visibly updated to `Gold: 5`, and a real OS Buy XP click updated to `Lvl 2 (2/6)`. `NaturalBuyXPAudit` confirms the same model path succeeds naturally at `Gold: 6`, and the 4-gold denial now shows `Need +1 gold to buy XP and keep 1 health.` | Input path covered under valid visible preconditions; natural behavior and reserve-floor denial feedback covered mechanically | Natural real-window screenshot of the Stage 1 Round 3 Buy XP success remains optional; preserve the explicit denial message in future shop UI passes. |
| Rapid shop input | `RapidShopInputAudit` covers same-frame rendered-card burst and deployment fallback. `outputs/audit_playtest/rapid_shop_os_burst/` adds audit-assisted real-window OS-coordinate evidence: before/after screenshots, preserved card centers, click coordinates, five bench additions, five sold placeholders, and no shop errors. `UIThemeSmoke` now asserts wider shop-card gutters and command-strip spacing; `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/08_round2_shop_wait.png` refreshes the first real shop view. | Covered behaviorally and audit-assisted visually/input-wise | Natural full-run rapid human-speed buying remains optional; preserve hit clarity, purchase feedback, deployment guidance, and the widened bottom-band spacing. |
| Start Battle transition | `StartBattleFeedbackAudit` covers stages 2-4 switching immediately to disabled `Combat Resolving...`; `CombatResolvingFeedbackSmoke` covers elapsed `Resolving Ns...`, `Still resolving Ns...`, and watchdog `Resolving fallback...` labels; `outputs/audit_playtest/live_start_battle_transition_2026_06_25/` provides real-window screenshots from Round 2 planning, immediate post-click resolving, mid-combat resolving, and restored planning. | Covered behaviorally and visually for immediate transition; elapsed/fallback labels covered by smoke | Optional real-window screenshot refresh if a future manual pass catches a naturally long/stalled fight. |
| Post-win planning beat | `PostCombatPlanningBeatSmoke` covers a Bonko forced-opener win returning through the visible gothic intermission bar before `PREVIEW`, then restoring a full shop, enabled `Start Battle`, and at least 55 seconds of planning time. | Covered behaviorally | Preserve the intermission beat and full timer reset so combat resolution cannot silently consume the next shop decision. |
| Duplicate scoreboard rows | `DuplicateScoreboardVisualAudit` exposed the ambiguity, and `ScoreboardDuplicateDisambiguationSmoke` now covers duplicate-copy labels in the model and rendered row scene. | Covered behaviorally | Optional real-window screenshot refresh only; preserve copy suffixes for duplicate display names. |
| Loss and system modals | `LossScreenSmoke`, `ExitFlowSmoke`, and real Axiom loss capture provide current framebuffer evidence. `LossScreenSmoke` proves the defeat modal keeps run-total summary stats after a later final-battle reset, uses an explicit `Final Battle Damage` player-only ledger, and does not keep hidden enemy row labels in the tree. `ExitFlowSmoke` proves the system Menu hides and cannot open while `LossOverlayLayer` is active, and asserts the pause backdrop alpha stays context-readable. `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png` refreshes the loss modal after the run-total title change; `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png` refreshes the system menu over Unit Select. | Covered behaviorally and visually for current labels/backdrop | No current modal blocker remains from the audit. |
| RGA identity reports | `RoleMatrixSmoke` passes all 22 current units; the 2026-06-25 saved report parser found 80 subject-side accepted lower-level `FAIL` spans across 21/22 reports after filtering opponent-side aggregate labels, suppressing non-applicable goal ramp and soft-peel hard-peel diagnostics, and adding live counterplay scenario rows. | Covered as smoke; tuning remains open | Treat accepted misses as balance/instrumentation backlog, not starter/shop-flow blocker. |
| Tooling reliability | Multiple runs reproduced Godot-AI session drops, missing game helper registration, and dummy framebuffer capture failures. `AuditPanelSmoke` covers a debug-only in-game Audit QA panel for state export, screenshot status, timer hold, restart, and speed controls. A real debug-window OS click on the panel's Screenshot button saved `user://audit_exports/audit_shot_1782371342_158480.png`; `02_after_screenshot_click.png` shows the panel confirming the save path. | Covered for in-game audit controls; Godot-AI helper remains fragile | Keep fallback OS screenshots for visual evidence when `_mcp_game_helper` does not register; continue using the panel for state/screenshot/timer control during manual audits. |

## Current Audit QA Panel Live Screenshot Recheck

Fresh real-window evidence was generated on 2026-06-25 from the running `Gamble Battle (DEBUG)` window after `godot-ai editor_screenshot(source="game")` failed with `_mcp_game_helper` registration timeout.

Accepted files:
- `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/01_panel_open.png`: OS-window capture showing the debug-only Audit QA panel open over the title screen after pressing `F8`.
- `outputs/audit_playtest/audit_panel_live_capture_2026_06_25/02_after_screenshot_click.png`: OS-window capture after clicking the panel's Screenshot button; the panel reports a saved path under `C:/Users/Flipm/AppData/Roaming/Godot/app_userdata/Gamble Battle/audit_exports/`.
- `user://audit_exports/audit_shot_1782371342_158480.png`: the PNG written by the panel's own viewport screenshot path. It opens correctly and shows the title screen plus Audit QA panel.

Result:
- The panel's non-dummy screenshot save path is verified in a live debug window.
- The remaining infrastructure caveat is not the panel; it is the Godot-AI game helper sometimes failing to register debugger capture/eval for the running game.

## Current System Menu Visual Recheck

Fresh OS-window evidence was generated on 2026-06-25 with the ignored hold scene `outputs/audit_playtest/CurrentSystemMenuVisualHold.tscn`.

Generated files:
- `outputs/audit_playtest/current_system_menu_visual/unit_select_system_menu_lighter_backdrop.png`
- `outputs/audit_playtest/current_system_menu_visual/current_system_menu_summary.json`
- `outputs/audit_playtest/current_system_menu_visual/notes.md`

Result:
- The accepted screenshot shows the System panel centered over the Unit Select screen. The underlying roster, detail panel, and disabled Start Game action remain visible enough for context while the modal remains the focal layer.
- The summary confirms `overlay_visible=true`, `unit_select_visible=true`, `tree_paused=true`, `system_menu_button_visible=false`, and `backdrop_alpha=0.54`.
- `godot-ai game_capture_ready` stayed false again, so accepted visual proof came from OS-window capture of the visible `Gamble Battle (DEBUG)` process.
- This refresh closes the older lighter-backdrop visual caveat for the Unit Select system-menu state; `ExitFlowSmoke` remains the behavioral proof for Unit Select, CombatView, resume, new-run, return-title, and loss-overlay menu-blocking behavior.

## Current Shop Spacing And First-Fight Placeholder Recheck

Fresh evidence was generated on 2026-06-25 after the bottom-band spacing pass:
- `tests/visual/UIThemeSmoke.tscn` printed `UIThemeSmoke: OK` with `errors: []`. The smoke now asserts shop-card horizontal gutters of at least 16 px, command-strip separation of at least 16 px, BottomStorageArea separation of at least 14 px, a single wide forced-first-fight placeholder with a stronger border, larger `FIRST FIGHT` label, larger `Win to open shop` hint, interactive cursor/focus behavior, and a visible explanatory message when the locked placeholder is clicked.
- `tests/visual/ActualRunLoopSmoke.tscn` printed `ActualRunLoopSmoke: OK` with `errors: []`, preserving starter selection, first-board drag, repeated loss/New Game resets, forced opener, first shop purchase, deploy prompt, bench-to-board movement, and second-fight resolution.
- `outputs/audit_playtest/RapidShopInputAudit.tscn` printed `RapidShopInputAudit: OK findings=0` with `errors: []`, preserving same-frame rendered-card burst buying, sealed placeholders, deployment guidance, five bench-to-board deploys, and post-burst fight resolution.
- Godot-AI game screenshots were still blocked by `_mcp_game_helper` registration timeout, so accepted visual proof came from the OS-window capture helper, matching the earlier live-window fallback path.

Accepted live-window files:
- `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/06_forced_first_fight_retry.png`: Bonko forced opener at 1920x1080 after the pass. The shop strip now reads as a deliberate locked state: prominent orange border, larger `FIRST FIGHT`, and readable `Win to open shop`.
- `outputs/audit_playtest/shop_spacing_recheck_2026_06_25/08_round2_shop_wait.png`: first real Round 2 shop after the opener. The command strip still fits above the shop, with wider shop-card gutters and clearer spacing around `Start Battle`, gold, level, and betting.

Implication:
- The older "shop/start hit targets need more breathing room" finding is no longer a pure missing-fix item. Current behavior and visual evidence support a narrower preservation note: keep the wider gutters, command spacing, and explicit forced-first-fight placeholder during future shop/UI passes.
- The remaining manual-play risk is physical drag/click feel under pressure, not known transaction corruption or an unreadable opener placeholder.

## Current Real-Window Deploy Drag Release Recheck

Fresh ignored hold-scene evidence was generated on 2026-06-25 under `outputs/audit_playtest/current_deploy_drag_recheck/` using `outputs/audit_playtest/CurrentDeployDragHold.tscn` and `outputs/audit_playtest/current_deploy_drag_actions.ps1`.

Diagnostic files:
- `01_round2_shop_before_buy.png`: real debug-window shop before purchase, with Bonko on board, a populated level-1 shop, and `Start Battle`.
- `02_after_os_shop_click.png`: OS-coordinate click bought Morrak, put it on bench, showed `Bought Morrak. Drag it from bench to board.`, and left the board as `["bonko"]`.
- `03_after_os_bench_to_board_drag.png`: first OS drag attempt did not deploy; summary still had bench `["morrak"]`, board `["bonko"]`, and `completion_reported=false`.
- `05_focus_reset_after_failed_drag.png`: after an explicit-move retry and focus reset, the screenshot showed the drag ghost stuck over the board while the bought unit remained on bench. This narrowed the bug to drag release/end handling rather than shop purchase or board target geometry.

Fix and accepted files:
- Root cause: `DragAndDroppable` only ended an active drag from source `gui_input`; a real OS release over a different control could miss the source release path and leave the drag ghost alive.
- Fix: `DragAndDroppable` now enables global `_input` handling only while `_dragging`, updates the ghost on global mouse motion, and ends the drop on global left-button release before disabling that listener.
- `06_after_patch_shop_before_buy.png`: patched run reached Stage 1 Round 2/6 with 3 gold, Bonko on board, and visible cost-1 shop offers.
- `07_after_patch_os_shop_click.png`: OS click bought Cashmere to bench, lowered gold to 2, and showed the deploy prompt.
- `08_after_patch_os_bench_to_board_drag.png`: OS drag moved Cashmere from bench to board; summary confirms `board_after=["bonko","cashmere"]`, `bench_after=[]`, `completion_reported=true`, no shop errors, and `Start Battle` still visible.

Validation:
- `tests/visual/DragGlobalReleaseSmoke.tscn`: `DragGlobalReleaseSmoke: OK`, `errors: []` via MCP `get_debug_output()`.
- `tests/visual/AxiomRetryEconomySmoke.tscn`: `AxiomRetryEconomySmoke: OK` in the current `godot.log`.
- `tests/visual/ActualRunLoopSmoke.tscn`: first post-fix attempt failed before the deploy portion with `shop cycle did not open a post-fight shop` after five loss-reset cycles, but a legacy MCP rerun immediately afterward completed with `ActualRunLoopSmoke: OK` and `errors: []`. Treat the first result as transient, not evidence against the drag-release fix.

Audit implication: first-purchase bench deployment is now covered by both behavioral smoke and physical OS-window evidence. Future drag work should preserve the global-release lifecycle and focus on pressure polish, not the core drop correctness.

## Current RoleMatrix Accepted-Miss Recheck

Fresh RoleMatrix evidence was regenerated again on 2026-06-25 with `tests/rga_testing/ci/RoleMatrixSmoke.tscn`. The MCP debug run completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`. The current run occupies `godot.log` lines 4-1139, report files were written under `user://identity_reports/*.json`, and one stale `faeling.json` from 2026-06-23 was ignored. The refreshed parser output is stored in `outputs/audit_playtest/rga_accepted_misses_2026_06_25/` and can be regenerated from current report JSON with `tests/rga_testing/tools/Export-AcceptedMisses.ps1`.

Follow-up instrumentation on 2026-06-25 moved the accepted-miss detail into the saved report JSON itself. `ProbeReportCompiler` now writes `diagnostics.lower_level_fail_span_count`, `diagnostics.lower_level_fail_spans`, and per-verdict `failed_span_count` / `span_details` fields under `user://identity_reports/<unit>.json`. A fresh MCP `RoleMatrixSmoke` rerun again completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`.

A second 2026-06-25 report-compiler pass filtered side-aggregate diagnostics to the audited unit's side. This removed opponent-side/control noise such as `b_unit_pass_count` and suffix labels such as `magic_share_med_b` from saved per-unit reports while preserving raw console visibility. That pass found 22 current reports, 0 reports missing diagnostics, 0 reports with `b_unit_pass_count` in diagnostics, 0 reports with side-B suffix labels in diagnostics, and 105 subject-side accepted lower-level fail spans.

A third 2026-06-25 goal-primary instrumentation pass tightened ramp diagnostics to identities that explicitly carry the `ramp` approach. Non-ramp attrition or marksman identities can still pass their goals through frontline damage share, sustain, survival, range, and uptime evidence, but they no longer inflate the accepted-miss backlog with non-applicable `goal_*_ramp_*` failed spans. `GoalPrimaryRampApplicabilitySmoke` covers both sides: a non-ramp attrition identity emits no goal ramp spans, while a ramp-tagged identity still reports direct ramp evidence.

A fourth 2026-06-25 RoleMatrix scenario pass added live counterplay response rows for debuff/lockdown identities. Quick probes now add a `counterplay` pack when requested, full 6v6 probes force a Totem/Veyra response shell for that label, and non-counterplay quick metrics are evaluated against baseline rows while `approach_debuff`/`approach_lockdown` still see the combined baseline-plus-counterplay rows for scenario deltas. The MCP `RoleMatrixSmoke.tscn` rerun completed with `RoleMatrixSmoke: PASS (22 units)` and `errors: []`; Brute and Grint now exercise live `counterplay` scenarios, and Grint's prior counterplay accepted-miss group is closed.

Aggregate result:
- Every current unit role verdict is still `PASS`, and all assigned primary goals and approaches passed in the smoke run.
- Raw console output still includes lower-level `-> FAIL` spans accepted by aggregate verdicts, including opponent-side aggregate/control spans that are still printed for visibility.
- The saved report JSON now records the subject-side backlog directly: 80 lower-level fail spans, split as 20 role spans, 42 approach spans, and 18 goal spans. Future accepted-miss audits should prefer this JSON field over parsing console text or `godot.log`.
- 21 of 22 current units have at least one subject-side accepted lower-level fail span in saved reports. Bonko is currently the only unit without a saved lower-level accepted miss.
- `tests/rga_testing/tools/Export-AcceptedMisses.ps1` now exports the ignored audit CSV and summary from `user://identity_reports/*.json`, keeping the saved artifact aligned with the subject-side report semantics instead of stale raw console counts. The export includes `topic`, `audit_gap_kind`, and `audit_next_action` for every recognized accepted span, plus `support_peel_triage`, `support_peel_gap_kind`, and `support_peel_next_action` fields for the support/peel bucket.
- Lowest role pass rates: Hexeon assassin 0.33; Berebell, Bo, Luna, Mortem, Paisley, Volt, and Vykos at 0.50; Axiom support at 0.55.
- Role-family averages from the fresh reports: assassin 0.33, brawler 0.58, support 0.59, mage 0.63, marksman 0.64, and tank 0.67.

Recurring accepted-miss buckets from the refreshed subject-side report evidence, using the primary topic classification in `rga_accepted_misses_summary.json`:
- Support/peel/cleanse/CC is still the largest bucket at 20 spans in the refreshed report diagnostics. Soft-peel identities no longer persist missing hard-peel cleanse/CC-immunity subspans unless their identity claims `support.peel_carry` or `cc_immunity`; Axiom and Paisley now remain only as team peel-save scenario attribution gaps. `PeelTeamSaveProxyProbe.tscn` proves the shared team-save proxy can pass `approach_peel`, `role_support_identity`, and `support.peel_carry` from one derived peel save, and `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves real Axiom/Paisley soft-peel rows can pass from team-save evidence while aggregate ally-protection controls keep the rows passing with team-save spans below target. The current Axiom/Paisley/Totem team-save rows are all-unit scenario attribution debt rather than missing metric support. `TotemPeelCarryAcceptedMissProbe.tscn` now proves real Totem `support.peel_carry` rows can pass all support/peel consumers with team-save, EHP, CC-prevention, interrupt, and cooldown evidence, while aggregate direct-protection controls preserve the current lower-level miss shape. The new live counterplay rows remove Grint from the debuff/lockdown response group, but add fresh counterplay-delta evidence rows for remaining content/scenario tuning.
- Marksman positioning and damage-share misses account for 10 spans. The exporter now separates three auxiliary candidate/team-side role share diagnostics on Nyxa/Sari/Teller, two auxiliary subject-owned role share diagnostics on Sari/Teller, and two sustained-DPS goal damage-share gaps on Sari/Teller; the remaining three are backline-pressure role spans. `MarksmanPositioningRoleProbe.tscn` now proves `role_marksman_identity` can pass through sustained DPS leadership plus direct backline/ranged presence, while candidate and subject damage-share rows remain auxiliary diagnostics. `MarksmanSustainedDpsGoalProbe.tscn` now proves real Sari/Teller `marksman.sustained_dps` goal rows can consume direct team damage share, range/time-on-target, survival, and Sari ramp-state evidence; its aggregate-pass controls preserve the current Sari/Teller low-damage-share rows as live output/scenario debt rather than missing metric support. This keeps "low team share" from implying the role or goal metric failed when sustained leadership plus ranged/backline presence already proved marksman identity, and classifies the current Nyxa/Sari/Teller marksman rows as live positioning/output debt rather than missing metric support.
- Tank/frontline semantics still have 9 direct redirect/body-block/taunt/frontline/engage misses plus related counterplay and cleanse-pressure misses. Brute/Repo body-block misses are now split between missing direct body-block events and missing prevented-damage magnitude, while Korath's redirect misses are split into target-swap, explicit threat-swap, and taunt-command evidence gaps. `FrontlineBodyBlockGoalProbe.tscn` now proves real redirect-kernel telemetry feeds Brute's `tank.frontline_absorb` body-block event and prevented-damage goal spans, while event-only, damage-only, and weak-prevention controls fail; the Brute/Repo body-block rows are live scenario/tuning debt rather than missing metric support. `BruteFrontlineShareGoalProbe.tscn` now proves Brute's frontline damage-taken-share span can pass from direct incoming-share evidence, while prevention plus frontline-position aggregate evidence preserves the current low-share accepted-miss shape. `KorathRedirectAcceptedMissProbe.tscn` now proves Korath's target-swap, explicit threat-swap, and taunt spans can pass from direct redirect evidence, while body-block aggregate evidence preserves the current missing-submode accepted-miss shape. `GrintEngageSuccessGoalProbe.tscn` now proves Grint's initiate-fight success-target span can pass from direct multi-target engage evidence, while distance plus first-action evidence preserves the current low-success-target accepted-miss shape. Brute, Korath, Repo, Kythera, Veyra, and Grint pass tank through aggregate thresholds while direct body-block, damage-share, redirect, or engage-success semantics are often absent.
- Burst/execute/kill accounts for 9 primary spans and AoE/wombo targeting accounts for 5 primary spans. Cashmere and Volt pass pick-burst while kill count is 0; Luna and Paisley pass wombo/mage identity despite single-target median AoE hits or low magic share; Hexeon passes aggregate assassin identity while backline-fraction and execute/burst subspans still miss. `AssassinOpeningRoleProbe.tscn` now proves real `BacklineAccessKernel` position telemetry can feed Hexeon's side-level `a_first_frac` and subject-level `subject_first_backline_frac` assassin role spans, while a late/access-losing control fails; the Hexeon opening-presence row is live opening-access scenario debt rather than missing metric support. `BurstWindowKernelProbe.tscn` now proves concentrated combat-pattern hits record peak 1s share, peak DPS, overkill, and counterplay-window telemetry and pass `approach_burst`, so the Berebell/Hexeon/Mortem/Vykos peak-share rows are burst-window output/timing debt rather than missing metric support. `PickBurstKillGoalProbe.tscn` now proves lethal combat-pattern telemetry feeds `goal_pick_burst_kill_count` for the real Cashmere `mage.pick_burst` goal, while a nonlethal aggregate pass keeps the kill-count span failing; the Cashmere/Volt kill-count rows are live kill-securing/scenario debt rather than missing metric support. `ExecuteBonusApproachProbe.tscn` now proves real Hexeon/Morrak `execute` approach rows can consume direct execute-bonus events, bonus damage share, low-HP kill conversion, and overkill guardrails; its aggregate-pass controls preserve the current accepted-miss shape where Hexeon/Morrak still pass `approach_execute` while `subject_execute_bonus_damage_share` is below target. `WomboComboGoalProbe.tscn` now proves real Luna/Paisley `mage.wombo_combo_burst` goal rows can consume direct combat-pattern peak-share and multi-target evidence plus control-mobility CC event evidence. Its aggregate-pass controls preserve the current accepted-miss shapes: Luna can pass through peak+targets while CC-sync proxy fails, and Paisley can pass through targets+CC while peak-share is below target.
- `AoeTargetingKernelProbe.tscn` now guards the AoE evidence path directly: grouped same-time hits record targets-hit median, max targets hit, multi-target group count, and AoE DPS, and `approach_aoe` passes on that telemetry. `AoeMultiTargetApproachProbe.tscn` adds the real-identity accepted-miss guard for Luna/Morrak/Nyxa/Paisley/Teller: clustered same-time groups pass the target-median span, while low-median aggregate controls keep `approach_aoe` passing through max-target evidence with `subject_targets_hit_median` below target. The remaining multi-target rows are therefore live clustered-target scenario/tuning debt rather than missing metric support.
- Ramp-state misses now account for 3 spans, all on ramp-tagged identities: two approach-level stack misses on Sari/Veyra and one Sari sustained-DPS goal ramp-stack miss. `RampApproachProbe.tscn` now proves real Sari/Veyra `ramp` approach rows can consume direct ramp-state events, full stack max, peak duration, and window duration; its aggregate-pass controls preserve the current accepted-miss shape where Sari/Veyra still pass `approach_ramp` while `subject_ramp_stack_max` is below target. `MarksmanSustainedDpsGoalProbe.tscn` proves Sari's goal-level ramp-stack span can pass from direct `ramp_state_changed` telemetry and preserves an aggregate-pass low-ramp control with `goal_marksman_sustained_dps_ramp_stack_max` below target. Prior non-ramp attrition ramp noise is gone, and the export classifier also avoids treating `sustained_dps` as sustain/survival.
- Sustain/survival accounts for 6 spans, now split by evidence path: sustain approach EHP ratio on Berebell/Vykos, peel approach EHP ratio on Paisley/Totem, support-role team EHP proxy on Axiom, and support-role subject EHP diagnostic on Totem. `EhpRatioPathProbe.tscn` now proves all four EHP ratio paths can pass from aggregate unit healing/shields, source-owned support maps, and team EHP totals, so those rows are live sustain/peel pressure debt rather than missing metric support. Mobility/reposition accounts for 6 spans, brawler direct attrition for 4, and magic share for 3. `RepositionMovementKernelProbe.tscn` now proves direct movement signals can pass `approach_reposition` through max-step, post-cast displacement, and total-path spans, so the Berebell/Bo/Mortem movement rows are live movement-output/timing gaps rather than missing metric support. `SkirmishDiveBacklineGoalProbe.tscn` now proves hit attribution can pass Bo's `brawler.skirmish_dive` backline-contact span through `damage_to_frontline_pct`, while an all-frontline control fails; the Bo dive-contact row is live backline-access scenario debt rather than missing metric support. `BrawlerDirectAttritionProbe.tscn` now proves the role metric can pass direct attrition through frontline-share, sustain EHP, and pressure evidence, so the Berebell/Bo/Mortem/Vykos rows are live evidence/tuning gaps rather than missing metric support. `MagePeriodicityKernelProbe.tscn` now proves magic hit components can pass `role_mage_identity` through top-window magic share and peak-over-mean evidence, so the Luna/Paisley/Volt magic-share rows are live output/attribution gaps rather than missing metric support.
- The old residual `other` bucket is now explicit: engage/CC timing has 3 spans, assassin opening presence has 1 span, and team-fortification buff uptime has 1 span. `EngageCcTimingKernelProbe.tscn` now proves direct control-mobility signals can pass `approach_engage` through early displacement, first action, and first-CC timing, so the Brute/Grint/Korath rows are engage timing/scenario debt rather than missing metric support. `TeamFortificationBuffGoalProbe.tscn` now proves source-owned `buff_applied` telemetry feeds Kythera's `tank.team_fortification` ally-buff goal span, while an aggregate EHP/prevention pass keeps the buff span failing when no ally buff is present; the Kythera buff-uptime row is live fortification-context debt rather than missing metric support.
- Opponent-side aggregate noise is now filtered out of saved reports: `b_unit_pass_count` and `_b` suffix labels no longer appear in `diagnostics.lower_level_fail_spans`.

General accepted-miss gap-kind triage from the current export:
- Largest non-support or cross-role gap kinds are multi-target coverage below target (5), burst approach peak-share below target (4), direct attrition evidence below target (4), backline pressure below target (3), engage CC timing unproven (3), magic damage share below target (3), marksman role candidate/team-share diagnostic below target (3), movement distance below target (3), body-block events absent (2), body-block prevented damage absent (2), execute bonus share absent (2), marksman role subject damage-share diagnostic below target (2), marksman sustained-DPS goal damage share below target (2), ramp approach stack below target (2), redirect explicit threat-swap absent (1), redirect target-swap absent (1), redirect taunt absent (1), Wombo goal peak-share below target (1), and marksman sustained-DPS goal ramp-stack below target (1). The old 6-row effective-health group is now split into sustain, peel, and support-role EHP buckets so tuning can target the right metric path.
- `accepted_gap_kind_summary.csv` now rolls up all 80 accepted spans into 43 gap kinds with affected topics, units, labels, block types, and a representative next action. The same detail rows are embedded as `audit_gap_kind_details` in `rga_accepted_misses_summary.json`, while support-specific `support_peel_gap_kind_counts` remains the focused view for the support/peel bucket. `AcceptedMissGuardCoverageSmoke.tscn` now verifies the regenerated rollup still has 43 gap kinds and 80 spans, and that every gap kind maps to one or more committed guard scenes.

Support/peel/cleanse/CC bucket triage from the current saved report JSON:

The `support_peel_triage` column in `accepted_lower_level_fail_spans.csv` and `support_peel_triage_counts` in `rga_accepted_misses_summary.json` now regenerate these groups directly from current reports. The same export also adds `support_peel_gap_kind` and `support_peel_next_action`. Current gap-kind counts are: peel approach team-save proxy absent 3, support-role team-peel proxy absent 2, debuff cleanse bait rate below target 2, debuff cleanse pressure absent 2, debuff cleanse scenario delta below target 2, lockdown high-tenacity effective drop below target 2, lockdown cleanse scenario delta below target 1, CC-immunity approach cooldown trade below target 1, peel-carry goal cooldown trade below target 1, peel-carry goal save proxy absent 1, CC-prevention context absent 1, peel-interrupt context absent 1, and wombo CC-sync absent 1.

| Area | Rows | Current evidence gap | Audit decision |
| --- | ---: | --- | --- |
| Axiom `support.team_amplification` with `amp,peel,sustain` | 2 | `approach_peel` and `role_support_identity` still show 0 team peel saves in the all-unit row, but hard-peel cleanse/CC-immunity diagnostics are no longer saved because Axiom does not claim `cc_immunity` or `support.peel_carry`. | Axiom's aggregate support pass is real. `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves the real Axiom rows can pass team-save evidence and preserve a low-team-save aggregate pass through direct ally protection. Remaining debt is a team peel-save scenario attribution gap, not hard-peel/cleanse identity debt. |
| Paisley `mage.wombo_combo_burst` with `aoe,peel` | 1 | `approach_peel` still reports 0 team peel saves in the all-unit row, but missing hard-peel cleanse/CC-immunity diagnostics are no longer saved for this soft shield-peel identity. | Treat this as shield-peel/team-save live-evidence debt. `SoftPeelTeamSaveAcceptedMissProbe.tscn` proves Paisley's real `approach_peel` row can pass team-save evidence and preserve a low-team-save aggregate pass through ally protection. |
| Totem `support.peel_carry` with `peel,cc_immunity,amp` | 7 | The all-unit RoleMatrix row still lacks team peel saves, interrupt events, `subject_cc_prevented_as_target`, and both approach-level CC-immunity and goal-level peel-carry cooldown-trade efficiency, even though it has direct shield/amp/CC-immunity evidence. | This is scenario/threshold debt in the all-unit smoke, not proof that Totem support/peel telemetry is absent. `TotemCleanseLiveProbe.tscn` remains the explicit real-ability cleanse control, and `TotemPeelCarryAcceptedMissProbe.tscn` now guards the accepted-miss shape across direct team-save, EHP, CC-prevention, interrupt, cooldown-trade, and direct-protection evidence. |
| Debuff counterplay on Kythera and Sari | 6 | Live `counterplay` rows now exist, but Kythera and Sari still miss three separate response checks: cleanse bait rate, cleanse pressure, and cleanse scenario delta, two rows each. Grint now passes the live debuff counterplay scenario and is no longer in this triage group. | Counterplay telemetry exists and the scenario harness is live. `CounterplayAcceptedMissProbe.tscn` now proves Kythera/Sari can pass response-pressure spans and preserves aggregate-pass controls where direct debuff evidence passes while cleanse-pressure/bait/delta spans fail. Remaining rows are targeted cleanse-bait, cleanse-pressure, or scenario-delta tuning, or retagging if these identities should not require cleanse response pressure. |
| Lockdown counterplay on Brute and Volt | 3 | Live `counterplay` rows now exist. Brute and Volt still miss high-tenacity effective-drop evidence, and Volt also has a lockdown cleanse scenario-delta miss. | `CounterplayAcceptedMissProbe.tscn` now proves Brute/Volt can pass high-tenacity and cleanse scenario spans and preserves aggregate-pass controls where direct lockdown evidence passes while response spans fail. Remaining rows are lockdown-specific response tuning: split high-tenacity response composition/duration work from the neutral-vs-cleanse scenario-delta setup, or retag if anti-CC response proof should not be required. |
| Luna `mage.wombo_combo_burst` | 1 | `goal_wombo_combo_burst_cc_sync_proxy` remains 0 while the goal can still pass through burst/AoE evidence. `WomboComboGoalProbe.tscn` proves the CC-sync proxy can pass from direct control-mobility CC event telemetry, and also preserves the aggregate-pass/no-CC accepted-miss shape. | Treat as live CC-sync scenario debt unless the design decides burst/AoE aggregate evidence is sufficient. |

Implication:
- The current all-unit RGA gate is green and should not block the starter/shop audit.
- The pass is threshold/aggregate based, not proof that every role/goal/approach semantic subspan is expressed cleanly. Treat the accepted spans as a balance, scenario, and identity-tag backlog before declaring identity semantics fully proven.
- `tests/rga_testing/validation/CounterplayContextTriageSmoke.tscn` guards the synthetic counterplay interpretation, `CounterplayAcceptedMissProbe.tscn` preserves the accepted-miss aggregate/control shape, and `RoleMatrixSmoke.tscn` now exercises live counterplay response rows. Grint's live row now passes, while Brute/Kythera/Sari/Volt still leave accepted counterplay spans for future content/scenario tuning.

## Current Loss And Exit Modal Framebuffer Recheck

Fresh live-editor framebuffer evidence was generated on 2026-06-24 after the earlier dummy-renderer capture failures:
- `tests/visual/LossScreenSmoke.tscn` saved `outputs/visual_iter/loss_screen_pass/loss_overlay_modal_fixed.png` and printed `LossScreenSmoke: OK`.
- `tests/visual/ExitFlowSmoke.tscn` saved `outputs/visual_iter/exit_menu_pass/01_unit_select_system_menu.png`, saved `outputs/visual_iter/exit_menu_pass/02_combat_system_menu.png`, and printed `ExitFlowSmoke: OK`.

Visual read:
- The loss modal is centered, legible, and constrained to a modal frame; New Game is clearly visible. The synthetic test state leaves the scoreboard body almost blank, with only the `Scoreboard` heading visible, so real defeat screenshots should still be checked for populated scoreboard readability.
- The system menu is centered and legible from both Unit Select and CombatView. The backdrop now uses alpha `0.54` instead of the earlier near-black `0.78`, keeping the paused Unit Select or combat state visible enough for return-context while preserving modal focus. `ExitFlowSmoke` asserts the backdrop alpha remains between `0.45` and `0.62`.
- This recheck closes the earlier "loss/exit framebuffer unavailable" evidence gap for synthetic modal states; the following real-run capture adds a populated player damage row.
- The 2026-06-25 lighter-backdrop rerun completed with `ExitFlowSmoke: OK` and `errors: []`, but the current MCP display was dummy/headless and skipped fresh PNG capture. The existing 2026-06-24 PNGs remain the visual baseline for the old dim, not proof of the lighter backdrop.

## Current Real Loss Overlay Capture

Fresh live-editor evidence was generated with the ignored audit scene `outputs/audit_playtest/RealLossOverlayCapture.tscn`.

Generated files:
- `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.png`
- `outputs/audit_playtest/real_loss_overlay_capture/axiom_real_loss_overlay.json`
- `outputs/audit_playtest/real_loss_overlay_capture/bonko_stage2_no_loss_overlay.json`

Axiom first-loss result:
- The real defeat overlay is centered and legible.
- Summary labels at the time reported `Team Damage: 143`, `Team Healing: 0`, `Total Kills: 0`, and `Top Damage: Axiom (143)`.
- The visible player scoreboard row shows Axiom with 143 damage, so the populated player-row readability gap is closed for a simple one-unit defeat.
- The extracted label list also contained `Beegle` and `1.2k`, but that enemy row is not visible in the modal screenshot because the loss-screen scoreboard is non-expandable. That is probably intentional for modal containment, but it means the player cannot compare the enemy ledger from the defeat modal.
- The top-right `Menu` button remains visible behind the defeat overlay. It is outside the modal frame and reads as an active control even while the loss modal should own attention.

2026-06-25 player-only scoreboard fix:
- The loss modal titles the embedded scoreboard as player-only final-battle detail, disables enemy rows for the modal context, and clears hidden enemy row nodes instead of merely hiding the enemy column.
- `LossScreenSmoke` now uses a populated tracker with Axiom and an enemy row, then verifies Axiom is present while `Beegle` and `1.2k` are absent from all loss-screen label text.
- `StatsPanelClickSmoke` still passes, so regular combat stats/scoreboard behavior remains intact outside the defeat modal.
- The MCP run printed `LossScreenSmoke: OK` with `errors: []`; PNG capture was skipped because the current MCP display is dummy/headless, so this is behavioral evidence rather than fresh screenshot evidence.

2026-06-25 run-total stat fix:
- `StatsTracker` now maintains run totals for damage, healing, and kills until a new run resets the tracker totals.
- The defeat modal summary now reports `Run Damage`, `Run Healing`, `Run Kills`, and `Top Run Damage`, while the embedded ledger is labeled `Final Battle Damage`.
- `LossScreenSmoke` simulates an earlier Axiom damage/kills battle followed by a later final battle where the player has no damage. The smoke verifies the modal still reports `Run Damage: 143`, `Run Kills: 1`, and `Top Run Damage: Axiom (143)`.
- `StatsPanelClickSmoke` and `ActualRunLoopSmoke` both passed after the change, so regular combat ledger behavior and the Main-flow loss/reset path still work.

2026-06-25 behavioral fix:
- `Main.refresh_system_menu_state()` now treats `LossOverlayLayer` as an authoritative modal state: the top-right system Menu button hides, disables, and cannot be opened by Escape or direct system-menu calls while defeat is active.
- The combat controller calls the Main refresh hook immediately after creating `LossOverlayLayer`, so the real loss path updates without waiting for another screen transition.
- `ExitFlowSmoke` was extended to create a synthetic loss layer, verify the system Menu button hides, verify the system menu does not pause or overlay the defeat state, and verify `request_new_run()` clears the loss layer and returns to Unit Select.
- The MCP run printed `ExitFlowSmoke: OK` with `errors: []`; the runner skipped PNG captures because the current MCP display is dummy/headless, so this is behavioral evidence, not fresh screenshot evidence.

Bonko solo Stage 2 result:
- The same harness attempted a Bonko forced opener, then started the second fight without purchases.
- No loss overlay appeared within the capture timeout; the summary recorded `loss_overlay_visible=false`, `reason=loss_overlay_not_seen_after_second_fight`, `stage=2`, and `gold=3`.
- This is not enough to diagnose whether combat stalled, Bonko survived longer than the timeout, or the capture condition missed the state, but it keeps the Stage 2 no-resolution/late feedback concern alive under a current automated audit path.

## Current Loss Modal Visual Recheck

Fresh current-state visual evidence was generated on 2026-06-25 with the ignored hold scene `outputs/audit_playtest/CurrentLossModalVisualHold.tscn`.

Generated files:
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window.png`
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_window_run_totals.png`
- `outputs/audit_playtest/current_loss_modal_visual/current_loss_modal_summary.json`
- `outputs/audit_playtest/current_loss_modal_visual/notes.md`

Earlier result:
- `current_loss_modal_window.png` showed the defeat modal centered and legible with no competing top-right Menu button.
- That screenshot predates the run-total title change: it shows the modal scoreboard title as `Player Damage` with only the player row `Axiom` / `143`.
- The old summary confirmed `loss_overlay_visible=true`, `system_menu_button_visible=false`, `system_menu_button_disabled=true`, `enemy_column_child_count=0`, and label text limited to `Defeat`, stage/high score, player summary stats, the player-only damage ledger, `Axiom`, and `143`.
- `godot-ai editor_screenshot(source="game")` could not capture because `_mcp_game_helper` did not register debugger capture in that run, so the accepted PNG came from the OS-window capture helper after verifying the `Gamble Battle (DEBUG)` window.

2026-06-25 run-total visual refresh:
- `CurrentLossModalVisualHold.tscn` was run through the live editor via Godot-AI `project_run`; the Godot-AI game capture helper still did not mark `game_capture_ready`, so the accepted PNG came from the OS-window helper targeting the visible `Gamble Battle (DEBUG)` process.
- `current_loss_modal_window_run_totals.png` was inspected after capture and shows the current centered defeat modal with `Run Damage: 143`, `Run Healing: 0`, `Run Kills: 1`, `Top Run Damage: Axiom (143)`, and `Final Battle Damage`.
- The modal remains visually contained, the New Game action is prominent, the player-only Axiom row is readable, and the top-right system Menu is absent behind defeat.
- The refreshed summary JSON now contains the same run-total labels and confirms `system_menu_button_visible=false`, `system_menu_button_disabled=true`, and `enemy_column_child_count=0`.

## Current Starter Runner Recheck

Fresh ignored-runner evidence was regenerated on 2026-06-24 at `outputs/audit_playtest/starter_audit_results.json` using `outputs/audit_playtest/StarterAuditRunner.tscn`.

Current level-1 starter surface:
- `axiom`, `berebell`, `bo`, `bonko`, `brute`, `cashmere`, `grint`, `korath`, `morrak`, `mortem`, `repo`, `sari`

Current automated solo-starter result:

| Starter | Role | Wins | First loss | Total player damage | Stage 1 | Stage 2 |
|---|---|---:|---:|---:|---|---|
| Bonko | brawler | 1 | 2 | 1796 | victory | defeat |
| Berebell | brawler | 1 | 2 | 1385 | victory | defeat |
| Sari | marksman | 1 | 2 | 1383 | victory | defeat |
| Grint | tank | 1 | 2 | 1253 | victory | defeat |
| Brute | tank | 1 | 2 | 1215 | victory | defeat |
| Morrak | brawler | 1 | 2 | 1038 | victory | defeat |
| Bo | brawler | 1 | 2 | 988 | victory | defeat |
| Korath | tank | 1 | 2 | 961 | victory | defeat |
| Mortem | brawler | 1 | 2 | 918 | victory | defeat |
| Repo | tank | 1 | 2 | 667 | victory | defeat |
| Cashmere | mage | 1 | 2 | 622 | victory | defeat |
| Axiom | support | 0 | 1 | 143 | defeat | - |

Summary:
- Current starter count is 12, not the earlier 21. The removed starter-visible units are the new cost-2 premium tier: `kythera`, `luna`, `nyxa`, `paisley`, `teller`, `totem`, `veyra`, `volt`, and `vykos`.
- Eleven of 12 current starters beat Stage 1 solo and then lose Stage 2 solo. Axiom remains the only current starter that loses Stage 1 in this automated run.
- No current level-1 solo starter clears Stage 2. The best total-damage reads are Bonko, Berebell, Sari, Grint, and Brute.
- The level-2 solo check against the four-enemy creep mix still had no winners. Highest damage was Grint 591, Bonko 562, Brute 377, and Korath 261.
- Focused item checks still improve numbers without flipping the tested outnumbered fights: Cashmere `doubleblade` 240 -> 303, Nyxa `mind_siphon` 1752 -> 2037, and Korath `blood_engine` 475 -> 598.
- Audit implication: the current branch has successfully moved fragile/premium kits out of the starter picker, but the early game is still a one-body wall. A good Stage 1 solo win plus no deployed support still loses Stage 2, so first-shop deployment clarity and board-width onboarding remain core risks.

## Current All-Starter Main-Flow Replay

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/all_starter_main_flow_audit/all_starter_main_flow_results.json` using `outputs/audit_playtest/AllStarterMainFlowAudit.tscn`. The MCP debug run completed with `AllStarterMainFlowAudit: OK starters=12` and `errors: []`.

Run result:
- The runner used the real Main scene and current starter catalog: `axiom`, `berebell`, `bo`, `bonko`, `brute`, `cashmere`, `grint`, `korath`, `morrak`, `mortem`, `repo`, and `sari`.
- All 12 starters opened the CombatView from Unit Select, and all 12 successfully repositioned the starting board unit through the existing drag path.
- Axiom reached a nonlethal Stage 1 retry state after the forced opener: `first_fight_result="retry"`, `stage_after_first=1`, and `gold_after_first=1`. It did not reach the first shop in this default-bet replay.
- The other 11 starters reached the first shop at Stage 1 Round 2 with level-1 offers only.
- For each of those 11 starters, the runner clicked one rendered affordable shop card, saw the deploy prompt, moved the bought bench unit to the board, and resolved the next fight back to a shop/planning state.
- Summary counts: `starter_count=12`, `first_shop_count=11`, `first_retry_count=1`, `deploy_success_count=11`, `second_resolved_count=11`, `starter_failures=[]`, and no shop errors.

Implication:
- The current Main-flow presenter path is now covered across all 12 current starters for selection, initial board drag, forced opener handling, and first-shop buy/deploy where the starter reaches shop.
- Axiom remains the onboarding outlier in `AllStarterMainFlowAudit` because the default-bet replay records the immediate Stage 1 retry state rather than the follow-up retry fight. The stronger tracked `AxiomRetryEconomySmoke` now proves that state can recover mechanically: retry shop, 1-cost helper buy, bench-to-board deploy, retry-fight win, and full Stage 2 planning shop.
- This remains automated behavioral coverage. It does not close the separate live-window screenshot and human drag-feel gaps.

## Current Shop And Premium Runner Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/current_shop_audit_results.json` using `outputs/audit_playtest/CurrentShopAuditRunner.tscn`. The MCP debug run completed with `errors: []`.

Current shop-tier sample:

| Player level | Sampled offers | Cost-1 offers | Cost-2 offers | Cost-3 offers | Premium coverage |
|---:|---:|---:|---:|---:|---|
| 1 | 1000 | 1000 | 0 | 0 | none |
| 2 | 1000 | 797 | 203 | 0 | all 9 cost-2 ids seen |
| 3 | 1000 | 645 | 301 | 54 | all 9 cost-2 ids seen |

Rapid transaction probe:
- A level-2 shop reached a premium offer after one reroll: `kythera`, `axiom`, `repo`, `axiom`, `bo`.
- Five immediate `Shop.buy_unit(slot)` calls all succeeded, spending 6 gold total and filling the bench with `kythera`, `axiom`, `repo`, `axiom`, `bo`.
- The purchased offers became five sealed/blank placeholders. This direct transaction path is now backed by the rendered-card burst recheck below; real pointer-coordinate spacing and feel still need window-level input testing.

Premium Stage 2 helper probe:

| Starter | Premium helpers that beat Stage 2 as second body |
|---|---|
| Bonko | `kythera`, `luna`, `nyxa`, `paisley`, `teller`, `totem`, `veyra`, `volt`, `vykos` |
| Axiom | `nyxa`, `teller`, `vykos` |

Runner implication:
- Cost-2 premium value exists mechanically once a second unit actually reaches the board. Bonko plus any cost-2 premium beat the Stage 2 direct-combat check, and support opener Axiom can flip Stage 2 with Nyxa, Teller, or Vykos.
- The audit risk is therefore UI reliability and comprehension: the player must notice the premium, buy it, understand that it landed on the bench, and deploy it before the next fight. The old manual risk around unclear buying/deployment remains valid even though premium units are not underpowered in the direct-combat probe.
- The duplicate-name scoreboard probe produced two separate model rows for two Berebells (`index 1` damage 1487, `index 0` damage 1433). That confirms duplicate rows are expected for duplicate copies, but the visual design still needs copy/star/index context so players do not read it as a display bug.

## Current Rapid Shop Input Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/rapid_shop_input_audit/rapid_shop_input_results.json` using `outputs/audit_playtest/RapidShopInputAudit.tscn`. The MCP debug run completed with `RapidShopInputAudit: OK findings=0` and `errors: []`.

Run result:
- The runner used the real Main scene, selected Bonko, won the forced opener, granted 16 audit gold to isolate input handling from economy scarcity, and rerolled three times to a unique cost-1 shop: `Cashmere`, `Bonko`, `Sari`, `Morrak`, and `Grint`.
- It emitted all five rendered `ShopCard.pressed` signals in one same-frame burst. All five emitted, spent the expected 5 gold (`14 -> 9`), added five bench units, produced five sealed/purchased placeholders, left phase `PREVIEW`, kept `combat_active=false`, kept the continue button at `Start Battle`, showed the deploy prompt, and emitted no shop errors.
- A stale double-click check against the first original card found that the original card had already become invalid after the grid rebuild, so no stale second purchase fired and no shop error appeared.
- Five bench-to-board deploy attempts all moved units successfully. The final board was `["bonko", "cashmere", "bonko", "sari", "morrak", "grint"]`, the bench was empty, and the post-burst fight resolved back to preview.

Real-window OS-coordinate follow-up:
- Fresh ignored hold-scene evidence was generated on 2026-06-25 under `outputs/audit_playtest/rapid_shop_os_burst/` using `outputs/audit_playtest/RapidShopOSBurstHold.tscn` and `outputs/audit_playtest/rapid_shop_os_burst_clicks.ps1`.
- The hold scene instantiated the real Main UI, selected Berebell, then staged a valid Stage 1 Round 2 planning shop directly through game autoloads to isolate the shop input path from opener RNG. This is audit-assisted setup, not natural full-run progression proof.
- `01_before_rapid_os_burst.png` shows the staged shop at `Gold: 18`, `Start Battle`, and five enabled visible 1g cards: `Mortem`, `Berebell`, `Bo`, `Repo`, and `Korath`.
- `rapid_shop_os_burst_summary.json` preserves the pre-click card centers `(475,968)`, `(635,968)`, `(795,968)`, `(955,968)`, and `(1115,968)`. `rapid_shop_os_burst_clicks.json` confirms OS clicks at those same screen coordinates with 25 ms spacing.
- `02_after_rapid_os_burst.png` and the final summary confirm all five purchases landed: bench `["mortem", "berebell", "bo", "repo", "korath"]`, gold `18 -> 13`, five sold placeholders, `phase=PREVIEW`, `continue_button_text="Start Battle"`, `deploy_prompt_visible=true`, and no `shop_errors`.

Implication:
- The current Main-flow shop transaction/presenter path tolerates a rapid burst across rendered shop cards and subsequent bench deployment without reproducing the older battle-lock failure.
- The real-window buying portion is now covered for OS-coordinate clicks under a staged Round 2 setup. Remaining risk is natural long-form human timing, deployment drag feel, and whether purchase feedback is prominent enough during normal play pressure.

## Current Duplicate Scoreboard Visual Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/duplicate_scoreboard_visual/duplicate_scoreboard_visual_results.json` using `outputs/audit_playtest/DuplicateScoreboardVisualAudit.tscn`. The MCP debug run completed with `DuplicateScoreboardVisualAudit: OK` and `errors: []`. A live editor run also saved `outputs/audit_playtest/duplicate_scoreboard_visual/duplicate_berebell_scoreboard.png`.

Original run result:
- The duplicate Berebell custom fight started and resolved as victory, with 66 hits, 2920 player damage, and 649 enemy damage.
- Model rows remained separate by internal index: `index 1` Berebell had 1487 damage and `index 0` Berebell had 1433 damage.
- The rendered scoreboard showed two visible player rows: `Berebell 1.5k` and `Berebell 1.4k`.
- There was no name/value overlap in the rendered rows.
- The rendered rows had zero visible identity disambiguators. The only visible texts were the duplicate name and each damage value, so the player cannot tell which Berebell copy is which from the scoreboard alone.

2026-06-25 fix and validation:
- Duplicate scoreboard rows now keep separate combat rows but add copy suffixes when a team has repeated display names, for example `Berebell #1` and `Berebell #2`.
- The suffix is produced in `ScoreboardModel`, then reused by `ScoreboardRow` and tooltip copy so rendered labels and hover context stay consistent.
- `tests/visual/ScoreboardDuplicateDisambiguationSmoke.tscn` passed through MCP with `ScoreboardDuplicateDisambiguationSmoke: OK` and `errors: []`. The existing `StatsPanelClickSmoke` also passed afterward with `errors: []`.

Implication:
- Duplicate scoreboard rendering is numerically readable, and the row split is intentional rather than a model aggregation bug.
- The identity ambiguity is closed for duplicate display names. A future polish pass can replace the copy suffix with board slot, star/level, or aggregate-row design if that becomes the preferred UX.

## Current Start Battle Feedback Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/start_battle_feedback/start_battle_feedback_results.json` using `outputs/audit_playtest/StartBattleFeedbackAudit.tscn`. The MCP debug run completed with `StartBattleFeedbackAudit: OK` and `errors: []`.

Run result:
- The runner used the real Main scene, selected Bonko, won the forced opener, then injected a stable audit team (`bonko`, `grint`, `nyxa`, `volt`) so repeated Start Battle transitions could be observed.
- Stage 2, 3, and 4 each started from visible enabled `Start Battle`.
- Immediately after each button press, the button text changed to disabled `Combat Resolving...`, phase changed to combat, bet read `Bet: 1 (locked)`, and the combat engine reported active.
- Each audited start resolved back to preview: Stage 2 -> 3, Stage 3 -> 4, and Stage 4 -> 5.

Implication:
- The current automated Main-flow behavior has immediate Start Battle feedback. The older `Battle Locked` ambiguity is no longer present in this path; the current label is clearer and appears synchronously with combat start.
- A live-editor screenshot attempt for the same runner failed before the post-forced-fight shop and overwrote the JSON, so the passing MCP run was repeated to restore the evidence. Treat this as behavioral proof, not a fresh real-window visual capture.

Live-window recheck:
- Fresh OS-window screenshots were captured on 2026-06-25 in `outputs/audit_playtest/live_start_battle_transition_2026_06_25/`.
- `06_round2_wait_after_forced.png` shows the normal Round 2 planning state with an enabled `Start Battle` button.
- `07_immediate_after_start_battle.png` was captured immediately after one click and shows the button disabled as `Combat Resolving...`, the bet locked, and the board in combat.
- `08_followup_after_transition.png` shows the disabled resolving state persisting during combat, and `09_final_after_transition_wait.png` shows the screen returning to planning with `Start Battle` restored.

Updated implication:
- Start Battle is now covered by both behavior and real-window visual evidence. The remaining design risk is not whether the click gives feedback; it is whether longer or stalled combat needs a progress indicator, timeout, or clearer stuck-state recovery.

## Current Premium Buy/Deploy Main-Flow Recheck

Fresh ignored-runner evidence was generated on 2026-06-24 at `outputs/audit_playtest/premium_deploy_audit/premium_deploy_audit_results.json` using `outputs/audit_playtest/PremiumDeployAuditRunner.tscn`. The MCP debug run completed with `PremiumDeployAuditRunner: OK` and `errors: []`.

The same runner was refreshed on 2026-06-25 through legacy MCP. It again completed with `PremiumDeployAuditRunner: OK` and `errors: []`. In the refreshed run, Bonko's opener left enough gold for natural Buy XP to succeed, so no audit gold was needed for the XP step; the runner then granted premium-shop audit gold, rerolled once, bought cost-2 `Veyra`, showed the deploy prompt, and dragged Veyra to the board for final board state `["bonko", "veyra"]`.

A later 2026-06-25 rerun varied the reward/economy outcome and still passed. It completed with `PremiumDeployAuditRunner: OK` and `errors: []`; natural Buy XP at 4 gold correctly failed the reserve-floor rule with tooltip `Must keep at least 1 health (need +1)`, one audit gold grant let Buy XP advance to `Lvl 2 (2/6)`, the level-2 shop exposed cost-2 `Volt` after three rerolls, and the runner bought/deployed Volt for final board `["bonko", "volt"]`. This keeps the behavioral cost-2 path covered even though live-window screenshots remain blocked.

Run result:
- Bonko won the forced opener and reached the post-fight shop with visible `Gold: 4` and `Lvl 1 (0/2)`.
- A natural Buy XP click at 4 gold did not change gold or level; the button tooltip reported `Must keep at least 1 health (need +1)`.
- The audit runner then granted 1 gold to test the successful path. Buy XP advanced to `Lvl 2 (2/6)` and left gold at 1.
- The runner granted 11 audit gold for a premium-shop interaction, rerolled once, and found cost-2 `Volt` as a rendered shop card.
- Clicking the rendered `Volt` card bought it to the bench, showed the first-purchase deploy prompt, and left the board as `["bonko"]`.
- Dragging the bench unit to the board succeeded; final board state was `["bonko", "volt"]`, bench was empty, and the continue button read `Start Battle`.

Implication:
- The cost-2 premium buy/deploy path is behaviorally covered in the current Main flow after leveling, including rendered card click and bench-to-board drag. The accepted runner history now covers two cost-2 outcomes: `Volt` after an audit-funded XP step and `Veyra` after natural Buy XP.
- The reserve-floor Buy XP affordance is still weak: the click is accepted by the button but produces no obvious visible error beyond tooltip state. A player at 4 gold can easily read this as a missed click.
- PNG capture requests in this runner were skipped under the MCP dummy/headless framebuffer. A live-editor attempt to capture the same runner was session-sensitive and failed before the post-fight shop, so this evidence should be treated as behavioral JSON/debug-output proof, not visual-polish proof.

## Current Live Main-Flow Screenshot Recheck

Fresh current-run screenshot evidence was generated on 2026-06-25 under `outputs/audit_playtest/live_flow_recheck_2026_06_25/`, with notes in `outputs/audit_playtest/live_flow_recheck_2026_06_25/notes.md`.

Accepted screenshots:
- `01_title.png`: title screen.
- `02_unit_select_initial.png`: Unit Select before active selection.
- `03_bonko_selected.png`: Bonko selected and Start Game enabled.
- `04_forced_first_fight.png`: forced first-fight planning state.
- `05_round2_shop.png`: first real shop after Bonko wins the opener.

Run result:
- The first title Start click transitioned to Unit Select on the first attempt.
- The current Unit Select surface showed exactly the 12 cost-1 starters.
- Bonko selected on the first pointer click, and Start Game enabled immediately.
- The forced first-fight planning screen correctly disabled Reroll, Lock, and Buy XP; the continue button said `Start Forced Fight`; the shop placeholder said `FIRST FIGHT` / `Win to open shop`.
- Bonko won the opener and reached `Stage 1 - Round 2/6` with `Gold: 3`, `Lvl 1 (0/2)`, `Start Battle`, and a five-card level-1 shop: `Bo`, `Mortem`, `Morrak`, `Repo`, `Sari`, all priced `1g`.
- The live UI tree reported each shop card as a full `150x138` button with about 10 px horizontal gaps.
- A pointer-coordinate click at approximately `(475, 968)` on the first card succeeded; `godot.log` recorded `[BenchPlacement] Added to bench slot=0 unit=Bo level=1`.

Visual/UX read:
- Title and selected-unit states are strong: large targets, clear title art, and an obvious enabled Start Game state after selection.
- Initial Unit Select still has a small ambiguity: the preview says `Inspecting Axiom` before a selection is made, so inspection and selection can blur until the player notices Start Game is disabled.
- The forced-first-fight behavior is correct, but the bottom placeholder text is very low contrast and visually subtle. The button carries most of the meaning.
- The first real shop is readable at 1920x1080, but the cards sit close to the bottom edge. Labels and prices are readable on this desktop capture, but the layout still feels compressed under timer pressure.

Limit:
- Immediately after the first shop-card purchase, a broad Godot-AI scene-tree inspection timed out and the bridge then dropped with a keepalive timeout. The newest debug process from this run was stopped manually. This pass confirms the pointer-coordinate purchase event, but it did not capture accepted post-purchase bench/deploy screenshots and does not close the live drag-feel or manual cost-2 deployment gaps.

## Current Live Window Capture Fallback Attempt

After the Godot-AI session list dropped to zero active sessions, a fallback attempted to capture and click the visible `Gamble Battle (DEBUG)` window directly. Diagnostic files were saved under `outputs/audit_playtest/window_capture_2026_06_25/`.

Result:
- Bringing an existing debug window to the foreground produced a real game-window capture at Stage 1 Round 2 with a visible 1g shop, `Gold: 3`, and `Lvl 1 (0/2)`.
- That debug window was stale rather than live: the planning timer stayed at `0:59`, a pointer click around `(475, 965)` on the first shop card did not change gold or bench state, and no new bench-placement log appeared.
- The two stale `Gamble Battle (DEBUG)` game processes were stopped while the editor windows were left alone.
- A fresh `scenes/Main.tscn` launch through legacy MCP started headless (`--headless --path ... scenes/Main.tscn`), returned `errors: []`, and exposed no capturable game window. It was stopped cleanly.

Implication:
- The stale-window captures are not accepted as gameplay proof; they only explain why the fallback did not close the post-buy/deploy screenshot gap.
- The accepted evidence for post-leveling cost-2 buy/deploy remains the refreshed `PremiumDeployAuditRunner` JSON/debug-output path.
- This gap was later partially closed for cost-1 post-buy deployment by the live Bonko-to-Brute recheck below; manual cost-2 deployment after leveling remains open.

## Current Live Bonko Shop And Deployment Recheck

Fresh live editor/debug-window evidence was saved on 2026-06-24 under `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs\`.

Captured sequence:
- `001_bonko_forced_first_fight.png`: Bonko selected, forced first fight shown with `FIRST FIGHT` / `Win to open shop`, disabled shop actions, and Start Forced Fight available.
- `002_bonko_round2_shop.png`: after Bonko won the opener, Stage 1 - Round 2/6 showed 3 gold, level 1, and only cost-1 offers: `Morrak`, `Mortem`, `Mortem`, `Brute`, `Mortem`.
- `004_bonko_brute_drag_attempt.png`: after buying Brute, gold fell to 2, the Brute card became a sealed shop placeholder, Brute appeared on the first bench slot, legal board cells highlighted green, and the board still contained only Bonko after the drag attempt.

Runtime state saved with the drag-attempt screenshot:
- `board_ids`: `["bonko"]`
- `bench_ids`: `["brute"]`
- `gold`: 2
- `phase`: preview/planning
- `stage`: 2
- `planning_time_left`: about 8 seconds

Live-run implication:
- The current level-1 shop behavior is correct: no cost-2 premium appeared before leveling.
- The premium helper result from the runner remains mechanically meaningful, but live UI value still depends on leveling, seeing the premium offer, buying it, and fielding it in time.
- Even the simpler cost-1 Brute helper did not enter the board on the first real drag attempt before timer pressure. That keeps first-shop deployment clarity as a current live blocker, not just a stale pre-fix finding.
- This run restored fresh screenshot evidence through the live editor path, but `editor_screenshot(source="game")` later timed out and Godot-AI lost its active session. Computer Use could see the `Gamble Battle (DEBUG)` window, but `get_window_state` failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`, so OS-level coordinate dragging could not continue in this pass.

Follow-up live max-bet/XP recheck:
- A live editor run confirmed the current Unit Select grid exposes the 12 cost-1 starters only.
- The first inspected `Start Game` click on Bonko did not transition; a second click on the same enabled button center did. This reinforces the need for stronger click/transition feedback around critical buttons.
- In the forced first-fight state, clicking the bet slider at its right edge changed the visible bet from 1 to 2, matching the starting 2 gold cap.
- Max-bet Bonko won the opener and reached Stage 1 - Round 2/6 with visible `Gold: 4`, `Lvl 1 (0/2)`, and all cost-1 offers: `Bo`, `Grint`, `Bonko`, `Cashmere`, `Grint`.
- A real click at the inspected Buy XP button center did not visibly update the level, XP, or gold labels. A direct autoload state read immediately afterward showed `gold=3`, `shop_level=1`, `shop_xp=0`, and `shop_xp_to_next=2`.
- That means the visible Buy XP click did not produce a successful XP purchase, level-up, or clear error. Later code and harness inspection narrowed the diagnosis: `ShopPresenter._on_buy_xp()` calls `Shop.buy_xp()`, then refreshes progress and card state directly, so a successful presenter path should repaint. The live issue is more likely the Buy XP button/input path failing to fire or complete under the current Godot-AI/OS-window capture setup than the cost-2 logic itself being unavailable.
- The bridge became unstable during deeper state inspection: a corrected `game_eval` timed out, then `game_manage.get_ui_elements` timed out, and Godot-AI dropped to zero active sessions. No fresh screenshot was saved for this follow-up segment.

## Current Live Cost-1 Post-Buy Deploy Recheck

Fresh live Main-flow evidence was saved on 2026-06-25 under `outputs/audit_playtest/live_deploy_recheck_2026_06_25/` after recovering Godot-AI through a fresh editor launch. The active session was `gamble-battle@0ad7`, running `res://scenes/Main.tscn`.

Accepted screenshots:
- `01_title.png`: title screen.
- `02_unit_select.png`: Unit Select with the current 12 cost-1 starters and the initial Axiom inspection preview.
- `03_bonko_selected.png`: Bonko selected and Start Game active.
- `04_forced_first_fight.png`: Stage 1 Round 1 forced first fight with disabled shop controls and `Start Forced Fight`.
- `05_round2_shop_before_buy.png`: Bonko reached Stage 1 Round 2 with 3 gold, level 1, and cost-1 offers: `Brute`, `Brute`, `Repo`, `Repo`, and `Morrak`.
- `06_after_cost1_buy_bench_prompt.png`: first live pointer-coordinate shop buy placed Brute on the bench, but screenshot inspection/timer pressure let combat start before deployment.
- `07_after_missed_deploy_back_to_planning.png`: after the fight resolved back to planning, Brute remained on the bench and Bonko remained on the board.
- `08_after_drag_bridge_drop_window.png`: OS-level capture after Godot-AI dropped during the first live drag attempt, showing the timer extended, Brute selected on the bench, and Bonko still on the board.
- `09_after_os_drag_attempt.png`: OS-level drag from the first bench slot to the board succeeded visually; Brute moved onto the player board and the first bench slot was empty.

Run result:
- A direct state read immediately after the first shop click confirmed `bench=["brute"]`, `board=["bonko"]`, `gold=2`, `phase=1`, and `stage=2`.
- The planning timer can still expire while evidence is being inspected; this pass auto-started combat with Brute still on the bench before a clean deploy screenshot could be captured.
- After the round returned to planning, the timer was extended for audit purposes. Godot-AI then dropped during the drag attempt, but the live game window stayed responsive.
- OS-level mouse input recovered the interaction and moved Brute from bench to board in the same live run.

Implication:
- The cost-1 live post-buy path is now visually covered: purchase-to-bench is confirmed by state and screenshot, and bench-to-board deployment is confirmed by real-window drag evidence.
- The remaining deployment gap is narrower: live manual cost-2 buy/deploy after leveling still needs a real-window screenshot pass, and the Godot-AI bridge remains too fragile for uninterrupted long-form manual play.
- Final validation after this doc update reran `tests/visual/ActualRunLoopSmoke.tscn` through legacy MCP; it printed `ActualRunLoopSmoke: OK` with `errors: []`. `git diff --check`, direct trailing-whitespace checks for this doc and brain notes, and canonical brain vault validation also passed.

## Current Live Cost-2 Buy XP And Deployment Attempt

Fresh live evidence was captured on 2026-06-25 under `outputs/audit_playtest/live_cost2_recheck_2026_06_25/`; the local folder also contains `notes.md`.

Accepted screenshots:
- `01_title.png`: title screen from the first Godot-AI run.
- `02_unit_select.png`: Unit Select with the current 12 cost-1 starters.
- `03_bonko_selected.png`: Bonko selected and Start Game active.
- `04_forced_first_fight_default_bet.png`: forced first fight at default bet.
- `05_forced_first_fight_max_bet.png`: attempted max-bet click; visible state still showed bet 1, and model readback confirmed `current_bet=1`.
- `06_after_forced_fight.png`: Bonko reached Stage 1 Round 2 with 3 gold, level 1, and cost-1 offers.
- `08_audit_assist_visible_gold.png`: after an audit model grant to 16 gold, the visible gold label still showed 3.
- `09_after_buy_xp_click.png`: Godot-AI Buy XP click produced no model change; direct readback stayed `gold=16`, `level=1`, `xp=0`, `xp_to_next=2`.
- `11_os_after_buy_xp_bridge_timeout.png`: OS capture after Godot-AI timed out; visible state was unchanged.
- `12_os_after_real_buy_xp_click.png`: real OS click on Buy XP; visible state was still unchanged.
- `13_restart_title_os.png`: second clean debug-window launch captured from the OS.
- `14_restart_round2_shop_os.png`: second run reached Round 2 shop through OS input, but Godot-AI never registered the game helper for state/setup.

Initial run result:
- The first run proved the model could be audit-assisted to 16 gold, but the visible UI did not refresh the gold label because that setup wrote `Economy.gold` directly instead of using the normal `Economy.add_gold(...)` signal path.
- The Godot-AI bridge dropped after the Buy XP attempts.
- The second run proved the OS-window route can still reach Bonko's Round 2 shop, but `game_capture_ready` stayed false and `game_eval` returned `EVAL_GAME_NOT_READY`, so level-2 setup could not be applied or verified.

Signal-path live-window recheck:
- A follow-up ignored assist scene, `outputs/audit_playtest/LiveCost2WindowAssist.tscn`, instantiates the real `scenes/Main.tscn` UI and only applies setup gold through `Economy.add_gold(...)` after Round 2 planning is reached.
- `25_assist_round2_gold_grant.png` shows Round 2 planning with visible `Gold: 5`, proving the signal-path gold grant refreshed the UI.
- `26_assist_after_buy_xp_os_click.png` shows a real OS click on Buy XP advancing the visible UI to `Lvl 2 (2/6)`; the assist then visibly refreshed post-XP funds to `Gold: 12`.
- `27_assist_after_level2_reroll.png` shows a real OS reroll at level 2 exposing `Teller 2g` and `Vykos 2g`.
- `28_assist_after_cost2_buy.png` shows a real OS click buying cost-2 Teller, sealing the purchased shop slot, adding Teller to bench, and showing the deploy prompt.
- `29_assist_after_cost2_drag.png` shows a real OS drag moving Teller from bench to the player board beside Bonko.

Updated implication:
- The live-window Buy XP input path works when the visible economy state is valid and refreshed through normal signals.
- The cost-2 level-2 shop, purchase, deploy prompt, and bench-to-board drag are now covered by live-window screenshots under audit-assisted economy setup.
- The remaining proof gap is narrower: an unassisted live run still needs to show whether ordinary play naturally reaches enough gold/health for Buy XP at the moment a player expects it, and the reserve-floor rejection at 4 gold still needs clearer visible feedback.

## Current Buy XP Code And Harness Diagnostic

Fresh source inspection and harness evidence on 2026-06-25 narrowed the Buy XP risk:
- `scripts/ui/shop/shop_presenter.gd` wires `ShopButtons.buy_xp_pressed` to `_on_buy_xp()`, and `_on_buy_xp()` calls `Shop.buy_xp()`, `_refresh_progress()`, and `_refresh_cards_state()`.
- `scripts/game/shop/shop.gd` still leaves `buy_xp()` without a full `_emit_all()` call, but the presenter path compensates with direct refresh calls after a successful button signal.
- A fresh legacy MCP run of `outputs/audit_playtest/PremiumDeployAuditRunner.tscn` completed with `PremiumDeployAuditRunner: OK` and `errors: []`.
- In that run, natural Buy XP at 4 gold failed correctly because of reserve-floor protection; after one audit gold grant, Buy XP advanced to level 2 and the progress label read `Lvl 2 (2/6)`.
- The same run bought cost-2 `Volt` from a level-2 shop, showed the deploy prompt, and moved Volt from bench to board for final board `["bonko", "volt"]`.
- A fresh `outputs/audit_playtest/NaturalBuyXPAudit.tscn` run then proved the natural economy path without gold grants: after Bonko bought/deployed a cost-1 helper, max-bet the next fight, and won, Stage 1 Round 3 opened at `Gold: 6`; Buy XP succeeded and updated to `Gold: 2`, `Lvl 2 (2/6)`.

Implication:
- Current source and harness evidence prove the model/presenter path can level, expose a cost-2 offer, buy it, and deploy it.
- Natural access to level 2 is no longer the weak point. The first 4-gold Buy XP denial now has explicit visible feedback in the presenter path, while labels correctly remain unchanged.

## Current Natural Buy XP Main-Flow Recheck

Fresh ignored-runner evidence was generated on 2026-06-25 at `outputs/audit_playtest/natural_buy_xp_audit/natural_buy_xp_results.json` using `outputs/audit_playtest/NaturalBuyXPAudit.tscn`. The MCP debug run completed with `NaturalBuyXPAudit: OK` and `errors: []`.

Run result:
- Bonko won the forced opener after max-betting and reached Stage 1 Round 2 with `Gold: 4`, `Lvl 1 (0/2)`, and visible tooltip text `Must keep at least 1 health (need +1)`.
- Clicking Buy XP at 4 gold produced a `WOULD_KILL_YOU` shop error with context `{ "op": "buy_xp", "need_more": 1 }`, left `Gold: 4` and `Lvl 1 (0/2)` unchanged, and showed `Need +1 gold to buy XP and keep 1 health.` as visible feedback.
- The run bought and deployed cost-1 Mortem without audit gold, then max-bet the next fight.
- After the win, Stage 1 Round 3 opened at `Gold: 6`, `Lvl 1 (0/2)`, with Bonko and Mortem still on board.
- Clicking Buy XP at 6 gold succeeded naturally, updated `Gold: 2`, and advanced the progress label to `Lvl 2 (2/6)` with no shop errors.

Implication:
- Ordinary play can naturally reach a valid Buy XP moment before cost-2 shopping if the player buys/deploys a cheap helper, then risks a max-bet win.
- The audit should stop treating natural Buy XP access as unproven. The immediate communication gap is now covered mechanically: failed 4-gold clicks keep economy/progress labels stable and explain the reserve-floor rule in visible UI text.

Key manual evidence captured in this continuation:
- `00_title_bridge.png`: title screen captured from Godot-AI `project_run`.
- `01_unit_select.png`: Unit Select after clicking Start through `game_manage.input_mouse`.
- `02_nyxa_planning.png`: Nyxa selected, first planning state, forced first fight, no shop offers.
- `03_nyxa_combat_round1.png`: Nyxa first combat in progress.
- `09_nyxa_after_round1_visual.png`: Nyxa won first fight and reached Stage 1 - Round 2 with a populated shop.
- `10_nyxa_after_buying_shop.png`: attempted strategic shop buying led to a confusing `Battle Locked` state after only one visible gold spend.
- `13_axiom_planning.png`, `14_axiom_after_forced_fight.png`, `15_axiom_after_buy_vykos_attempt.png`, `16_axiom_after_retry.png`: Axiom support opener through first loss/retry attempt.
- `18_bonko_planning.png`, `19_bonko_after_round1.png`: Bonko brawler opener through Round 1 win and Round 2 shop reveal.
- `21_title_after_focus_retry.png`, `22_unit_select_after_relaunch.png`: recovered Godot-AI capture after focusing the debug game window.
- `23_berebell_planning.png`, `24_berebell_after_round1.png`, `25_berebell_after_buy_vykos.png`, `25_berebell_after_buy_brute.png`, `26_berebell_after_round2.png`: Berebell opener through Round 2 loss after buying Vykos and Brute.
- Bo strategic positioning attempt: after `27_after_berebell_new_game.png`, a Bo run was started to test bench-to-board drag placement, but Godot-AI dropped to zero active sessions before any Bo screenshots were saved.
- `28_rerelaunched_title.png`, `29_bo_planning.png`, `30_bo_after_round1.png`, `31_bo_after_buy_grint_bonko_mortem.png`, `32_bo_after_round2.png`: recovered Bo run through Round 2 battle-lock/stall after shop-buy attempts.
- External evidence `33_external_title.png`, `34_brute_planning.png`, `35_brute_after_round1.png`, `36_brute_after_teller_click_no_bench.png`, `37_brute_after_round2_wait.png`: Brute run through Round 2 battle-lock/stall after a Teller purchase attempt.
- External evidence `38_cashmere_title.png`, `39_unit_select_for_cashmere.png`, `40_cashmere_planning.png`, `41_cashmere_after_round1.png`, `42_cashmere_round1_stall_wait.png`, `43_cashmere_round2_outcome.png`: Cashmere run through forced opener and Round 2 battle-lock/no-resolution outcome.
- External evidence `44_grint_planning.png` through `53_grint_round2_after_start_wait.png`: Grint run through forced opener, post-fight shop buy, failed bench-to-board drag attempt, Round 2 start, and final Stage 2 defeat overlay.
- Recovered Korath evidence `54_korath_resume_title.png` through `73_korath_round5_result_window.png`: Korath max-bet opener, Round 2 shop/brawler line, successful bench-to-board drags, Buy XP level-up, and final Stage 5 defeat.
- Recovered Kythera evidence `74_kythera_selected_window.png` through `79_kythera_round2_result_window.png`: item-assisted Kythera opener, Round 2 shop buys that did not clearly field helpers, and final Stage 2 defeat.
- Recovered Luna evidence `80_luna_planning_maxbet_window.png` through `91_luna_round3_after_wait_window.png`: Luna max-bet opener, Brute-assisted Round 2 clear, bench units not contributing, and Stage 3 defeat.
- Recovered Morrak evidence `93_morrak_selected_window.png` through `108_morrak_final_or_stuck_window.png`: Morrak max-bet opener, multi-round brawler/tank board building, repeated late-round Start Battle ambiguity, and final Stage 5 defeat.
- Recovered Mortem evidence `109_mortem_selected_window.png` through `124_mortem_final_result_window.png`: failed max-bet opener, item-assisted retry, Nyxa/Bo carry support, XP/buy interaction misses, and final Stage 5 defeat.
- Recovered Sari evidence `125_sari_selected_window.png` through `140_sari_after_timer_wait_window.png`: max-bet marksman opener, brawler/tank board building, and repeated Round 5 planning-loop/start ambiguity.
- Recovered Paisley evidence `142_paisley_selected_window.png` through `152_paisley_final_window.png`: item-assisted opener, long first-fight wait, ally-supported climb to Stage 5.
- Recovered Repo evidence `153_repo_selected_window.png` through `158_repo_retry_result_window.png`: item-assisted opener still left Repo in a Round 1 retry economy state; a Brute buy/retry still ended Stage 1.
- Lower roster select evidence `160_lower_unit_select_after_scroll_window.png`: scrolled Unit Select exposed Teller, Totem, Veyra, Volt, and Vykos, while the right preview still showed stale Cashmere inspection text.
- Recovered Teller evidence `161_teller_selected_window.png` through `171_teller_late_result_window.png`: max-bet opener, failed batch-buy attempt, slower one-by-one shop/deploy recovery, and Stage 5 planning state.
- Recovered Totem evidence `172_totem_unit_select_scrolled_window.png` through `182_totem_late_result_window.png`: item-assisted support opener, long first-fight wait, ally-supported recovery, and Stage 5 planning state.
- Recovered Veyra evidence `183_veyra_selected_window.png` through `186_veyra_after_extra_wait_window.png`, plus retry `205_veyra_retry_selected_window.png` through `207_veyra_retry_after_round1_window.png`: max-bet opener stalled in Battle Locked, while default-bet item-assisted retry reached Round 2.
- Recovered Volt evidence `187_volt_selected_window.png` through `195_volt_late_result_window.png`: item-assisted opener, ally-supported climb, and Stage 5 planning state.
- Recovered Vykos evidence `196_vykos_selected_window.png` through `204_vykos_final_window.png`: strong max-bet opener, failed batch-buy/deploy follow-up, and Stage 2 defeat.

## Manual Starter Coverage Summary

| Starter | Best live result | Strategic read | Primary evidence |
|---|---|---|---|
| Axiom | Stage 1 defeat/retry failure | Pure support has no satisfying solo opener and cannot convert the bad retry economy. | `13`-`16` |
| Berebell | Stage 2 defeat | Good brawler opener, but early buys need clearer deployment to matter. | `23`-`26` |
| Bo | Round 2 battle-lock/stall | Strong enough opener, but shop/deploy flow can lock before the intended brawler/frontline plan resolves. | `29`-`32` |
| Bonko | Round 2 shop reached | Best plan was board width: Nyxa carry plus Grint/Korath-style frontline. | `18`-`19` |
| Brute | Round 2 battle-lock/stall | Good tank opener, but Teller purchase attempt reproduced the no-resolution lock. | `34`-`37` |
| Cashmere | Round 2 battle-lock/stall | Needs immediate frontline; the Round 2 combat state stalled before strategy could be evaluated cleanly. | `39`-`43` |
| Grint | Stage 2 defeat | Tank opener works, but undeployed bench damage does not help and loss stats zeroed out. | `44`-`53` |
| Korath | Stage 5 defeat | Best tank start so far; brawler/frontline width before XP carried longest. | `54`-`73` |
| Kythera | Stage 2 defeat | Item support can save the opener, but helper buys did not clearly enter combat. | `74`-`79` |
| Luna | Stage 3 defeat | Good mage behind Brute/frontline, weak if bought allies stay unclear or undeployed. | `80`-`91` |
| Morrak | Stage 5 defeat | Strong brawler/tank swarm start; Berebell-style allies became the real carry. | `93`-`108` |
| Mortem | Stage 5 defeat with item retry | Item-sensitive; Nyxa/Bo support buys turned a failed max-bet opener into a long run. | `109`-`124` |
| Nyxa | Round 2 reached strongly | Clearest early carry; wants immediate frontline. | `02`-`10` |
| Paisley | Stage 5 planning/late defeat path | Weak solo impression, but item plus Sari/Berebell/Veyra/Morrak-style buys can climb. | `142`-`152` |
| Repo | Stage 1 defeat/retry failure | One of the weakest starts; item and Brute retry still failed to create a board. | `153`-`158` |
| Sari | Stage 5 planning loop | Good marksman with body density, but late Start Battle state repeated instead of cleanly resolving. | `125`-`140` |
| Teller | Stage 5 planning state | Strong opener and viable with slow deliberate buys; batch buying was unreliable. | `161`-`171` |
| Totem | Stage 5 planning state | Support starter needs item/allies; Morrak/Bo/Vykos/Mortem-style bodies did the work. | `172`-`182` |
| Veyra | Round 2 with item retry; max-bet stall | Default-bet item opener is viable, but max-bet opener exposed a long Battle Locked stall. | `183`-`186`, `205`-`207` |
| Volt | Stage 5 planning state | Item-assisted opener works, then Kythera/Nyxa/Morrak/Korath/Vykos-style allies carry. | `187`-`195` |
| Vykos | Stage 2 defeat | Very strong opener, but post-shop batch-buy/deploy failure left him alone for the loss. | `196`-`204` |

## Current Live UI Findings

1. Godot-AI is useful but unstable for long playtest loops.
   - `project_run`, `editor_screenshot(source="game")`, and `game_manage.input_mouse` work when the editor session is healthy.
   - Repeated `editor_manage(op="game_eval")` polling disconnects the plugin during live play.
   - Long waits can also leave the server with "No active Godot session", requiring process cleanup and editor relaunch.
   - Repeated `game_manage.input_mouse` shop-click batches can also drop the session; this happened during Bonko's Round 2 all-buy attempt.
   - After relaunch, `editor_screenshot(source="game")` initially returned a black 763-byte frame while runtime UI inspection still worked. Focusing the `Gamble Battle (DEBUG)` window restored real framebuffer captures.
   - A later live editor run restored fresh Bonko framebuffers and saved external screenshots under `C:\Users\Flipm\Documents\gamble-battle-playtest-audit\current_runs`, but an `editor_screenshot(source="game")` timeout after the Brute buy/drag attempt coincided with Godot-AI dropping back to zero active sessions.
   - Computer Use could see the `Gamble Battle (DEBUG)` window after the Godot-AI session dropped, but its window-state capture failed with `SetIsBorderRequired failed: No such interface supported (0x80004002)`, blocking a fallback OS-level drag continuation in that pass.
   - A later Bo positioning attempt dropped the editor registration again (`session_manage` returned `count: 0`) while the debug game process and `godot-ai` sidecar process were still running. This reproduced the same "no active Godot session" blocker without `game_eval` polling.
   - Saving screenshots inside the Godot project caused editor-import side effects (`.png.import` files appeared under `outputs/audit_playtest/manual_runs`). Moving later screenshots outside the project avoided new import churn and made the Brute setup screenshots stable, though it did not fix the Round 2 gameplay stall.
   - Godot-AI `input_mouse` uses the 1920x1080 runtime viewport coordinates, while `editor_screenshot(source="game")` saves 640x360 images. Screenshot-pixel clicks miss unless scaled.
   - Shop buying is more stable one click at a time than in batches. A Grint retry successfully bought one unit and kept the session alive; a three-click batch dropped Godot-AI to zero registered sessions.
   - A follow-up Korath attempt dropped Godot-AI to `session_manage.count = 0` before either `54_korath_planning.png` or `55_korath_round2_shop.png` could be saved, while the editor, debug game, and sidecar processes were still running.
   - A later Korath continuation reproduced the drop again during long result polling, but the MCP-launched debug game stayed playable. Capturing and clicking the real `Gamble Battle (DEBUG)` window through OS input kept the run moving after Godot-AI lost its active session.
   - Practical impact: exhaustive manual starter playtesting is currently slower and less reliable than it should be.

2. The opening shop is technically blocked but still invites clicking.
   - Reroll, Lock, Buy XP, and empty shop cards did not change gold, XP, offers, or level during the forced first fight state.
   - The UI still presents these controls in the player decision area, so the player naturally tries them.
   - Better solution: render the opening shop as a single disabled "Win first fight to open shop" panel, or give the player an actual first recruit/shop decision before combat.
   - Current branch resolution: the opening shop now renders as one explicit `FIRST FIGHT` / `Win to open shop` panel, and activating that locked panel shows `First fight is forced. Win to open the shop.` via the existing shop message label.

3. Normal runs currently start with dev item inventory enabled.
   - Components and remover are visible immediately in the left item panel.
   - This is useful for testing item mechanics but contaminates balance/playtest reads.
   - Kythera looked like a solo Round 1 loser in the supporting runner, but an item-assisted manual opener reached Round 2. That is useful mechanic evidence, but it also shows the current dev inventory can flip perceived starter viability.
   - Better solution: gate `Items.DEV_STARTER_INVENTORY_ENABLED` behind a debug flag/profile and keep production playtests inventory-clean.

4. Nyxa is the clearest early carry so far.
   - Manual UI run: Nyxa won Round 1 and reached Round 2 with 3 gold and shop offers.
   - Supporting runner data: Nyxa had the strongest Stage 2 damage read among the selectable starters, with 802 Stage 2 damage and 1631 total damage across her two-stage run.
   - Best practical direction: pair Nyxa with immediate frontline, especially Grint/Vykos/Brute-style bodies when available.

5. Shop/start hit targets need more breathing room.
   - In the Nyxa manual run, clicking shop cards for Grint/Vykos/Veyra appeared to leave the run in `Battle Locked` with only 1 gold spent.
   - This may be a coordinate/playtest artifact, but it mirrors a real user risk: compact shop cards, the Start Battle button, and bottom controls are tightly clustered at 1080p.
   - A current live Bonko max-bet recheck also produced an unclear Buy XP interaction: clicking the inspected Buy XP button center reduced the live model gold from 4 to 3 while XP stayed at 0, level stayed at 1, and visible labels still showed the pre-click state.
   - The current rapid rendered-card runner did not reproduce a battle lock: five same-frame shop-card presses stayed in preview, produced five bench units, and resolved the next fight. That lowers transaction-risk but does not eliminate live pointer/hit-target risk.
   - Current branch mitigation: the gothic theme now spaces shop cards with wider gutters, gives the command strip more separation, and preserves the immediate `Combat Resolving...` transition on `Start Battle`. Fresh OS-window capture `08_round2_shop_wait.png` confirms the first real shop still fits the 1080p debug window after the spacing pass.
   - Better solution: preserve this spacing and add stronger purchase/deploy feedback only if future natural full-run play still shows pointer misses under pressure.

6. Bench-to-board deployment is mechanically required and now has first-purchase assist, but manual drag clarity still needs watching.
   - Existing shop docs and `tests/visual/actual_run_loop_smoke.gd` confirm shop purchases go to `BenchGrid`; bought units must then move from bench to board before they help.
   - Berebell's Vykos/Brute purchases succeeded, but the visual affordance was unclear and the player timer was nearly expired before I could confidently deploy them.
   - Bo's Round 2 shop offered `Grint`, `Luna`, `Totem`, `Bonko`, and `Mortem`. I attempted to buy Grint frontline plus Bonko/Mortem brawler pressure; only one visible purchase/deployment clearly landed before the run entered `Battle Locked`.
   - Grint's retry bought a backline damage unit from the shop, but a real mouse drag from the first bench slot to `TileP_16` did not move it. The bought unit remained selected on the bench and the right stats panel updated to that unit instead.
   - Korath's recovered run proved the intended drag can work after the later interaction fixes: a bought Berebell moved from the first bench slot to the board, then additional units were deployed in later rounds.
   - Current live Bonko recheck repeated the problem after the cost-tier pass: buying Brute from the Round 2 level-1 shop worked, but a first drag attempt left `board_ids` as `["bonko"]` and `bench_ids` as `["brute"]` with about 8 seconds left in planning.
   - Current branch mitigation: first post-fight purchase now shows `Bought <unit>. Drag it from bench to board.`, emits the first-deploy assist path, logs `Deploy <unit>: drag the glowing bench unit to a highlighted board cell.`, highlights the player grid plus the bought bench slot/unit, and extends short planning time to 20 seconds.
   - Fresh `ActualRunLoopSmoke` proves the prompt, signal connection, timer extension, bench placement, bench highlight, bench-to-board move, highlight clearing, next fight resolution, and reset recovery with `errors: []`.
   - The 2026-06-25 real-window deploy release recheck exposed one remaining correctness bug: OS dragging could start a ghost but fail to drop if release happened outside the source `UnitView`. `DragAndDroppable` now handles global mouse motion/release while dragging, and the patched OS-window pass bought Cashmere, dragged it from bench to board, emptied the bench, and reported `completion_reported=true`.
   - Remaining UX risk: physical mouse drag/hit clarity can still feel fragile under real pressure, but the board-cell guidance, bench-slot guidance, and active-drag release path now have direct behavioral and OS-window coverage; future visual/manual passes can focus on speed/pressure polish.

7. Round 2 used to stall in Battle Locked with no visible progress; indefinite hangs are now guarded mechanically.
   - Bo reached Round 2 with 4 gold, showed a nonzero Round 1 scoreboard, then entered a battle-locked Round 2 state after the shop-buy attempt.
   - After 50 seconds, the screenshot still showed the same active-board state, `Battle Locked`, `Gold: 1`, `Bet: 1 (locked)`, and scoreboard Bo damage at 0.
   - Brute reproduced the stall from a cleaner external-screenshot run: Round 2 shop was `Luna`, `Teller`, `Teller`, `Bonko`, `Bo`; clicking Teller spent 1 gold, immediately battle-locked the run, overlapped a pink unit/effect on Brute, and after 50 seconds still showed `Battle Locked`, `Gold: 1`, and 0 scoreboard damage.
   - Cashmere reached Round 2 and then reproduced a battle-locked no-resolution state after the planning timer elapsed. The final capture still showed Stage 1 - Round 2/6, `Battle Locked`, and 0 Cashmere scoreboard damage.
   - `get_debug_output()` reported no script errors, while Godot-AI game logs still marked the run as active and showed repeated movement-vector lines. This looks like a combat progression/movement stall, not a clean defeat.
   - Current branch mitigation: `CombatEngine` has a 45-second absolute combat timeout and 12-second no-progress timeout, each forcing a result from the current board state.
   - Fresh `CombatWatchdogSmoke` proves both timeout paths stop battle, emit the expected watchdog log line, and finish with `errors: []`.
   - Fresh `CombatResolvingFeedbackSmoke` proves the visible button state stays immediate as `Combat Resolving...`, then advances to elapsed `Resolving Ns...`, warns as `Still resolving Ns...` after 10 seconds, and switches to `Resolving fallback...` when a watchdog log arrives.
   - Remaining UX risk: elapsed/fallback feedback is smoke-covered but not yet captured from a naturally long real-window fight.

8. Late-round Start Battle feedback is easy to misread.
   - Luna's Round 3 and Morrak's Round 5 both had moments where Start Battle appeared not to take immediately; a later capture showed the game had either entered `Battle Locked` or eventually resolved after a second click/wait.
   - Sari's Round 5 was worse: repeated Start Battle attempts and long waits kept returning to Stage 1 - Round 5 planning with changing shops/gold/scoreboard values instead of a normal defeat or clear.
   - This may be normal timer/combat delay, but the user-facing state does not distinguish "click missed", "combat queued", and "fight is running slowly."
   - The current Start Battle feedback runner shows the automated Main flow still switches immediately to disabled `Combat Resolving...` at Stage 2, 3, and 4 and enters combat phase with an active engine.
   - Current branch mitigation: the same button now reports elapsed resolving time after the short delay and a fallback label if the combat watchdog has to force a result.

9. A failed opener can create a bad retry economy state.
   - Manual Axiom run: after the forced opener, the game stayed on Stage 1 - Round 1 with 1 gold and a populated shop.
   - I tried to buy the best visible damage/body option from the shop before retrying. The UI instead entered `Battle Locked`, bet locked, gold 0, and showed "Purchasing this now would kill you."
   - This is especially punishing for support starters: the unit most in need of help gets shown the help, then the buy/start/economy rules make the interaction feel broken.
   - Better solution: after a Round 1 loss, either give enough gold to buy exactly one unit safely, make the reserve-floor rule clear before the click, or route loss directly to New Game if retry is not intended.
   - Current branch mitigation: non-broke Chapter 1 Stage 1 defeats recover to 2 gold before the retry shop opens. `AxiomRetryEconomySmoke` verifies Axiom can buy one 1-cost helper, keep 1 gold, deploy it to board, and clear the first-deploy highlight.

10. Loss screen stats can become misleading after a retry.
   - Axiom had visible scoreboard damage of 195 after the first attempt.
   - The final defeat overlay after the retry reported Team Damage 0 and Top Damage: Axiom (0).
   - Berebell also showed a nonzero scoreboard during the run, then the Stage 2 defeat overlay reported Team Damage 0 and Top Damage: Berebell (0).
   - Better solution: clarify whether the loss screen reports the final battle only or the run total, and avoid showing zeroed stats when the run already produced visible combat stats.
   - Current branch mitigation: `StatsTracker` now keeps run totals until a new run, `LossScreen` reports run-total summary copy, and the embedded ledger is labeled `Final Battle Damage`. `LossScreenSmoke` verifies a prior Axiom damage/kills battle remains visible after a later final-battle reset.

11. Betting is present but not yet strategically interesting in the opener.
   - The bet defaults to 1 and locks during combat.
   - The first fight effectively asks the player to accept the default because there is no meaningful pre-fight economy choice.
   - Korath could drag the bet slider to 2 before the opener; it locked correctly and paid out enough to reach 4 gold for Round 2.
   - Better solution: either make the first wager a deliberate tutorial decision or hide/defer betting until the player has a real alternative.

12. Buy XP works; preserve explicit reserve/economy feedback.
   - Korath's Stage 5 planning state had 7 gold. Buying XP changed `Lvl 1 (0/2)` to `Lvl 2 (2/6)` and left 3 gold before purchases.
   - Subsequent low-gold buying surfaced "Purchasing this now would kill you" even after a strong run, so the reserve-floor rule still needs clearer preview and affordance.
   - Mortem and Sari later exposed a related click-feedback problem: XP and late shop buys did not always visibly apply even with enough gold, and subsequent states made it hard to tell whether the click missed, the timer advanced, or the purchase was rejected.
   - The current premium deploy runner reproduced the clean boundary: at 4 gold, Buy XP does not level; after one audit gold grant, Buy XP succeeds and updates to `Lvl 2 (2/6)`.
   - The live-window signal-path recheck confirmed the same input behavior visually: once the UI showed `Gold: 5`, an OS click on Buy XP changed the visible label to `Lvl 2 (2/6)`.
   - The natural Buy XP runner confirmed a non-granted route: Bonko plus a bought/deployed cost-1 helper reached `Gold: 6` after the next max-bet win, and Buy XP then advanced naturally to `Lvl 2 (2/6)`.
   - The refreshed natural Buy XP runner also confirms the denied 4-gold click now emits `Need +1 gold to buy XP and keep 1 health.` as visible UI feedback.

13. Scoreboard identity was unclear with duplicates. Closed in the current branch.
   - Morrak's Stage 5 run showed two separate `Berebell` scoreboard rows, and the duplicate visual runner confirmed they originally rendered as `Berebell 1.5k` and `Berebell 1.4k` with no visible identity disambiguator.
   - The current branch adds copy suffixes for repeated display names and covers them with `ScoreboardDuplicateDisambiguationSmoke`.
   - Future polish can still choose star levels, board slots, or merged aggregate rows, but duplicate copy labels are no longer a blocker.

14. Hexeon exists in data but is not starter-selectable.
   - Live Unit Select exposes 21 starter buttons.
   - Supporting context shows Hexeon is cost 3 and filtered out by starter/shop level odds.
   - Better solution: decide intentionally whether Hexeon is a later-shop unit or should be eligible as a starter.

15. Lower Unit Select scrolling could leave stale inspection context. Closed in the current branch.
   - The original manual screenshot showed Teller/Totem/Veyra/Volt/Vykos visible after scrolling while the right preview still read like Cashmere was being inspected.
   - Current `UnitSelectSmoke` covers the intended behavior: hover preview changes to `Inspecting ...`, scrolling clears stale hover state without selecting a unit, and the preview returns to `No champion chosen`.
   - Preserve this scroll/focus clearing behavior unless a future redesign binds the preview to an explicit selected or focused starter.

16. Batch shop-buying and deployment are not reliable enough for speed play.
   - Teller's first full-shop batch buy appeared to spend little and left only Teller fighting; a slower one-by-one purchase/deploy sequence worked and reached Stage 5.
   - Vykos had a strong opener, but batch-buying damage support left him effectively alone again and the run died at Stage 2.
   - This makes the game feel hostile to efficient play even when the intended strategy is obvious.
   - The current rapid rendered-card runner now covers the same-frame transaction path and five direct drag-lifecycle deploys cleanly, so the remaining risk is visual/physical interaction clarity rather than known transaction corruption.
   - Better solution: make shop purchases transactional and loudly visible: bench flash, gold delta, purchase sound, disabled sold card, and clear "unit is on bench, deploy it" state.

17. First-fight movement/edge cases can make viable starters look broken, though no-progress hangs are now bounded.
   - Paisley, Totem, and Veyra all produced long first-fight waits or edge-position oddities before either resolving or continuing to Round 2.
   - Veyra's max-bet opener remained in `Battle Locked` across multiple waits, but the same starter reached Round 2 on a default-bet item retry.
   - Current branch now has no-progress and absolute combat timeout telemetry. Remaining work is stuck-position recovery and clearer visible combat status if long fights still read as frozen.

## Supporting All-Starter Runner Results

These results are useful balance evidence but should not be treated as completed strategic UI playthroughs. They used the ignored audit runner under `outputs/audit_playtest`, not manual shop/position/item decision-making for each unit.

| Unit | ID | Role | Goal | Wins | Highest stage | First loss | Total player damage |
|---|---|---|---|---:|---:|---:|---:|
| Axiom | `axiom` | support | `support.team_amplification` | 0 | 1 | 1 | 195 |
| Berebell | `berebell` | brawler | `brawler.frontline_disruption` | 1 | 2 | 2 | 1451 |
| Bo | `bo` | brawler | `brawler.skirmish_dive` | 1 | 2 | 2 | 1254 |
| Bonko | `bonko` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1512 |
| Brute | `brute` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1467 |
| Cashmere | `cashmere` | mage | `mage.pick_burst` | 1 | 2 | 2 | 956 |
| Grint | `grint` | tank | `tank.initiate_fight` | 1 | 2 | 2 | 1602 |
| Korath | `korath` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1210 |
| Kythera | `kythera` | tank | `tank.team_fortification` | 0 | 1 | 1 | 783 |
| Luna | `luna` | mage | `mage.wombo_combo_burst` | 1 | 2 | 2 | 1084 |
| Morrak | `morrak` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1317 |
| Mortem | `mortem` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1282 |
| Nyxa | `nyxa` | marksman | `marksman.backline_siege` | 1 | 2 | 2 | 1631 |
| Paisley | `paisley` | mage | `mage.wombo_combo_burst` | 0 | 1 | 1 | 359 |
| Repo | `repo` | tank | `tank.single_target_lockdown` | 0 | 1 | 1 | 551 |
| Sari | `sari` | marksman | `marksman.sustained_dps` | 1 | 2 | 2 | 1430 |
| Teller | `teller` | marksman | `marksman.tank_shredding` | 1 | 2 | 2 | 1069 |
| Totem | `totem` | support | `support.peel_carry` | 0 | 1 | 1 | 642 |
| Veyra | `veyra` | tank | `tank.frontline_absorb` | 1 | 2 | 2 | 1123 |
| Volt | `volt` | mage | `mage.pick_burst` | 0 | 1 | 1 | 567 |
| Vykos | `vykos` | brawler | `brawler.attrition_dps` | 1 | 2 | 2 | 1648 |

Summary from supporting data:
- Fifteen starters beat Round 1 and then lost Round 2.
- Six starters lost Round 1: Axiom, Kythera, Paisley, Repo, Totem, and Volt.
- No level-1 solo starter cleared Round 2.
- Level-2 solo checks against a four-enemy creep mix also all lost.
- Item spot checks improved numbers but did not flip the outnumbered fights: `doubleblade` helped Cashmere, `mind_siphon` helped Nyxa, and `blood_engine` helped Korath.

## Strategy Notes So Far

- Axiom manual result: lost the opener, reached a retry shop with 1 gold, could not convert the shop into a useful board, then lost the run. This validates that pure support is a poor starter under the current forced-solo opener.
- Berebell manual result: won the forced opener, reached Round 2 with 3 gold, bought Vykos for brawler synergy and Brute for frontline, then still lost Round 2. The buys behaved correctly and left 1 gold, but manual placement/bench affordance was unclear before the timer expired.
- Bo positioning attempt: selected after the Berebell New Game reset to test buying plus bench-to-board drag placement, but Godot-AI lost the active editor session before Bo screenshots could be saved. Existing code context says the correct manual move is bench `UnitView` drag/drop to a `TileP_*` board cell; the smoke test bypasses input by calling `move_router._bench_to_board`.
- Bo recovered manual result: won the forced opener, reached Round 2 with 4 gold, and rolled `Grint`, `Luna`, `Totem`, `Bonko`, `Mortem`. Intended line was Grint frontline plus Bonko/Mortem brawler pressure, but the buy/placement flow entered `Battle Locked`; after 50 seconds Round 2 still had no visible resolution and Bo's scoreboard remained at 0.
- Brute manual result: won the forced opener, reached Round 2 with 3 gold, and rolled `Luna`, `Teller`, `Teller`, `Bonko`, `Bo`. Intended line was Teller backline damage behind Brute, but clicking Teller spent 1 gold and immediately created a battle-locked no-resolution state before a normal bench drag could happen.
- Cashmere manual result: won the forced opener slowly, reached Round 2, and then reproduced the no-resolution `Battle Locked` state. Best line would have been immediate frontline support, but the timer/lock state overtook the shop phase.
- Grint manual result: won the forced opener, reached Round 2, and bought one backline damage unit while trying to preserve a Grint frontline. The bench-to-board drag failed; starting Round 2 with the bought unit undeployed ended in a Stage 2 defeat overlay reporting Team Damage 0 and Top Damage: Grint (0).
- Bonko manual result: won the forced opener cleanly and reached Round 2 with 5 gold and a strong shop (`Repo`, `Bo`, `Korath`, `Grint`, `Nyxa`). Best line was to buy immediate board width: Nyxa carry plus Grint/Korath frontline, with XP delayed.
- Korath recovered manual result: max-bet opener won, Round 2 shop bought and deployed Berebell, later added Grint/Teller/Repo-style board width, bought XP on Stage 5, and finally lost on Stage 5. Best line so far was tank starter plus immediate brawler/frontline width; Berebell carried top damage at 663 on the defeat overlay.
- Kythera recovered manual result: item-assisted opener reached Round 2, but the Round 2 buy/deploy sequence still ended as a Stage 2 defeat with only Kythera on the defeat scoreboard. Best line needs an ally before combat; as a pure starter she still reads weak, but item support can make her opener look viable.
- Luna recovered manual result: max-bet opener reached Round 2, adding Brute let the run clear Round 2, and the run ended at Stage 3. Best line is Luna behind an immediate tank; bench units that are bought but not clearly deployed do not help and make the run feel worse than the visible shop suggests.
- Morrak recovered manual result: max-bet opener won, Kythera/Repo/Berebell/Teller-style board width carried through Stage 5, and final defeat reported 4206 team damage with Berebell top damage at 1754. Best line is brawler/tank swarm width before XP; Morrak himself was solid but not the carry once Berebell entered.
- Mortem recovered manual result: max-bet opener lost at Stage 1, but an offensive item retry reached Stage 5. Nyxa and Bo were key support buys, and the final defeat reported 3321 team damage with Mortem top damage at 1050. Mortem is much more sensitive to item support and early carry/frontline purchases than the runner result implied.
- Sari recovered manual result: max-bet opener won, Brute/Morrak/Vykos/Mortem-style body density carried her to Stage 5, but Round 5 entered a repeated planning/start ambiguity rather than a clean final defeat. Best line is still frontline plus brawlers before XP; Vykos overtook Sari on several scoreboard reads.
- Paisley recovered manual result: item-assisted opener eventually reached Round 2 after a long wait, then Sari/Berebell/Veyra/Morrak-style buys carried the run to Stage 5. Paisley can ride a strong board, but she is not the early carry; the first item and first shop matter heavily.
- Repo recovered manual result: item-assisted opener still produced a Stage 1 retry economy with 1 gold; buying Brute and retrying still ended in Stage 1 defeat with only Repo on the defeat overlay. Repo remains one of the weakest starts under the current forced-solo format.
- Teller recovered manual result: max-bet opener reached Round 2 with 6 gold, but the first full-shop batch-buy/deploy attempt failed to produce a wider board. Slowing down to buy and deploy one unit at a time worked, and a Volt/Repo/Grint/Kythera/Axiom-style board reached Stage 5. Teller is a real starter if the player resists batch inputs and prioritizes board width.
- Totem recovered manual result: item-assisted opener eventually reached Round 2 after a long wait, then Morrak/Bo/Vykos/Mortem/Teller-style purchases carried to Stage 5. Totem's own scoreboard impact stayed modest; he needs allies immediately and should not be presented as a satisfying solo damage start.
- Veyra recovered manual result: max-bet opener exposed a Battle Locked stall, but a default-bet item-assisted retry reached Round 2 with 4 gold and shop offers `Mortem`, `Berebell`, `Teller`, `Paisley`, and `Volt`. Best line is Veyra frontline plus immediate damage, especially Mortem/Teller/Volt if the buy/deploy flow is stable.
- Volt recovered manual result: item-assisted opener reached Round 2, and later Kythera/Nyxa/Morrak/Korath/Vykos-style allies pushed to Stage 5. Volt did not remain the carry once stronger allies entered, but he can be a viable start if item support or a first-shop frontline arrives.
- Vykos recovered manual result: max-bet opener was one of the clearest wins, showing about 1.0k opener damage. The run still died at Stage 2 because batch-buy/deploy support failed to enter cleanly; Vykos wants immediate second-body support but the current UI can erase that strategic intent.
- Best early pattern: start with a high-output unit or immediately add one; then buy frontline.
- Frontline bodies matter more than pure support early because Round 2 becomes an outnumbered swarm check.
- Support starters need immediate help. Axiom and Totem are not satisfying solo starts because their identity depends on allies they do not have.
- Fragile mages and utility tanks need a better first decision. Paisley, Volt, Repo, and Kythera all create weak first impressions under the forced solo opener.
- If the shop offers frontline plus damage after Round 1, buy bodies before XP. XP is too expensive at 4g when the player has 3g and needs board width immediately.

## Priority Fixes

1. Add a real opening decision before first combat, or explicitly frame the first fight as a short tutorial/prologue.
2. Preserve the now-proven Chapter 1 recovery path where a good Round 1 result plus one reasonable purchase survives, and where Axiom's retry helper line can progress into Stage 2; future tuning should target strategic quality/clear speed rather than the former hard-survival blocker.
3. Preserve dev starter inventory gating: `Items.DEV_STARTER_INVENTORY_ENABLED` defaults false, `DevStarterInventorySmoke` proves normal `reset_run()` keeps inventory and visible slots empty, and starter item seeding only happens when the dev flag is explicitly enabled.
4. Preserve the clearer forced-first-fight placeholder and its direct click/keyboard feedback if players still try the locked opener controls.
5. Preserve the widened spacing and hit clarity between shop cards, shop buttons, betting, and Start Battle.
6. Completed item dynamic effect cleanup is now guarded: unimplemented completed-item `effects` ids were removed from static-stat resources, Hemothorn's unsupported `pct_omnivamp` stat key was converted to supported `pct_lifesteal`, and `CompletedItemEffectRegistrySmoke` fails future completed items that declare unregistered runtime effects or unsupported stat keys.
7. Preserve and extend the debug in-game Audit QA controls for manual playtests: state export, screenshot status, restart, timer hold, and speed controls that do not require fragile repeated Godot-AI eval calls.
8. Preserve first-purchase deploy assist and drag release handling: prompt text, highlighted board cells, short-timer extension, and global release/drop cleanup must stay covered so bought units are actually fielded in early manual runs.
9. Preserve the combat no-progress and absolute-timeout watchdogs plus the visible resolving feedback labels; capture a natural real-window long-fight example if manual play ever sees one.
10. Preserve the post-win planning beat: `PostCombatPlanningBeatSmoke` now proves the intermission bar appears before planning returns, then restores a full shop, enabled `Start Battle`, and at least 55 seconds of planning time so the next shop decision is not silently consumed.
11. Preserve the now-passing rapid rendered-card buy/deploy behavior and the audit-assisted real-window OS-coordinate burst result; broaden only if future natural full-run play exposes human-speed hit-target or feedback issues.
12. Preserve the now-covered Unit Select scroll/focus behavior: scrolling away from a hovered starter should clear stale inspection copy instead of leaving the previous unit in the preview panel.
13. Preserve and visually verify the current `Combat Resolving...` Start Battle transition in real-window play, with elapsed resolving labels and watchdog fallback text as the no-progress recovery path.
14. Preserve Buy XP transactional feedback: if the click is unaffordable, show the reserve-floor reason; if it succeeds, keep gold/level/XP labels repainting immediately and make any reroll/shop refresh rules visible.
15. Preserve the now-fixed defeat modal ownership: the top-right system Menu hides, disables, and cannot open while the defeat overlay is active.
16. Preserve the now-explicit player-only defeat scoreboard: keep enemy ledger rows out of the loss modal unless a future design pass intentionally adds an enemy-comparison section.
17. Preserve duplicate scoreboard copy suffixes for repeated unit names unless a future stats UX pass deliberately replaces them with board slot, star/level, or aggregate-row context.
