# Stage Progression

Gamble Battle uses 10 authored chapters, then procedural endless chapters. Every chapter keeps the same 5-stage cadence:

1. Creep reward round
2. Normal RGA challenge/puzzle
3. Normal RGA challenge/puzzle
4. Boss
5. Mirror fight against the board the player took into the boss fight

Core constants live in `scripts/game/progression/progression_config.gd`. `AUTHORED_CHAPTER_COUNT` is `10`, and `ENDLESS_START_CHAPTER` is the first generated chapter after that authored campaign.

Enemy composition lives in `scripts/game/progression/roster_catalog.gd`. For authored chapters, creep, boss, and mirror slots are authored per chapter. Normal slots are selected by `scripts/game/progression/rga_stage_challenge_director.gd` from bounded chapter-tier puzzle pools and cached so planning preview and combat use the same pick.

For endless chapters, `scripts/game/progression/endless_chapter_generator.gd` builds generated StageSpecs by difficulty rating. `RosterCatalog` caches those specs in chapter/stage order so planning preview and combat receive identical generated boards. Normal endless stages include `rga_challenge` metadata, boss stages are generated from the same difficulty budget system, and mirror stages still use the boss-entry board snapshot.

Mirror fights use `scripts/game/progression/mirror_board_store.gd`. The combat manager snapshots the player's board when the boss fight starts, then the mirror rule applies that snapshot to the next stage's enemy team, including unit order, levels, combat stats, and equipped item IDs.
