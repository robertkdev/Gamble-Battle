# Stage Progression

Gamble Battle uses 10 authored chapters. Each chapter has 5 stages:

1. Creep reward round
2. Normal RGA challenge/puzzle
3. Normal RGA challenge/puzzle
4. Boss
5. Mirror fight against the board the player took into the boss fight

Core constants live in `scripts/game/progression/progression_config.gd`.

Enemy composition lives in `scripts/game/progression/roster_catalog.gd`. Creep, boss, and mirror slots are authored per chapter. Normal slots are selected by `scripts/game/progression/rga_stage_challenge_director.gd` from bounded chapter-tier puzzle pools and cached so planning preview and combat use the same pick.

Mirror fights use `scripts/game/progression/mirror_board_store.gd`. The combat manager snapshots the player's board when the boss fight starts, then the mirror rule applies that snapshot to the next stage's enemy team, including unit order, levels, combat stats, and equipped item IDs.
