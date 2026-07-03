# Stage Progression

Gamble Battle uses procedural chapters as the default campaign path from Chapter 1 onward. Every chapter keeps the same 5-stage cadence:

1. Creep reward round
2. Normal RGA challenge/puzzle
3. Normal RGA challenge/puzzle
4. Boss
5. Mirror fight against the board the player took into the boss fight

Core constants live in `scripts/game/progression/progression_config.gd`. `PROCEDURAL_START_CHAPTER` is `1`, and `EASIEST_REFERENCE_RATING` anchors Chapter 1 Round 1 to the old easiest creep-fight reference.

Enemy composition lives in `scripts/game/progression/roster_catalog.gd`. The old authored chapter map remains in the catalog as a reference source, but default gameplay routes Chapter 1 and later through generated specs.

`scripts/game/progression/endless_chapter_generator.gd` builds generated StageSpecs by difficulty rating. `RosterCatalog` caches those specs in chapter/stage order so planning preview and combat receive identical generated boards. Normal stages include `rga_challenge` metadata, boss stages are generated from the same difficulty budget system, and mirror stages still use the boss-entry board snapshot. Generated normal/boss difficulty includes raw unit level rating plus active enemy trait pressure; item pressure is currently exposed by `tests/rga_testing/validation/DifficultyRatingAudit.tscn` but is not part of generated boards until enemies start receiving generated item loadouts.

Player-facing naming remains the original chapter pattern. `ChapterCatalog.display_name_for()` returns `Chapter N` for Chapter 1 and all later generated chapters; the top bar and logs should not show an endless-mode label.

Mirror fights use `scripts/game/progression/mirror_board_store.gd`. The combat manager snapshots the player's board when the boss fight starts, then the mirror rule applies that snapshot to the next stage's enemy team, including unit order, levels, combat stats, and equipped item IDs.
