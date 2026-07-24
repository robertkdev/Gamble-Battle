# Blood Economy Conversion

Status: implemented on `codex/019f922e-cee-blood-economy-conversion`.

## Player-facing contract

Blood is Gamble Battle's universal reserve, wager, battle payout, shop-spend, reward, and progression currency. It is presented as an institutional commodity: measured dark-glass reserves, transfusion hardware, quotas, and house accounting. It is not a red coin, a joke-gore motif, or a synonym for the Sanguine trait.

The unseen house/network holds the reserve, escrows each wager, pays the established win return, refunds ties, and supplies reward or retry allocations. Existing tuning is preserved: the run starts with 3 units, the default wager remains 1, combat escrows the wager, a win pays `2 × wager`, and a tie restores the pre-combat reserve.

## Stable internal boundary

Player-facing text and currency art use **blood**, **blood reserve**, and **wager**. The established internal API remains named `gold`, `gold_changed`, `add_gold`, `current_bet`, and related identifiers. Those names are implementation compatibility seams, not current fiction. Renaming them would create broad save, test, autoload, and signal regression risk without changing play.

New player-facing work must not expose `Gold`, coins, `Bet:`, or `assets/ui/gold icon.png`. Tests may refer to the stable internal API when validating its blood-economy behavior.

## Dependency inventory and disposition

| Surface | Conversion |
|---|---|
| Reserve and wager HUD | Blood Reserve and Wager copy; measured-vessel asset |
| Title and tutorial | Blood/wager language and house-reserve framing |
| Shop, reroll, XP, purchases | Blood-reserve affordability and reserve-floor feedback |
| Combat results and ties | Blood payout, blood lost, and blood returned |
| Creep rewards and progression allocations | Blood grants/transfusions |
| Audit and vision surfaces | Blood and wager labels |
| Tests and probes | Visible-string expectations converted; internal API retained |
| Mogul | Trait resource, runtime effect, key, and active roster association retired |
| Teller and Ivara | Removed from playable data, abilities, identity resources, tests, and forward roster surfaces; Git history preserves prior work |
| Cashmere | Economy identity retired and replaced in the live roster by Laith |
| Laith | Arcanist only; secondary slot intentionally empty; provisional Ink Expulsion has no currency reward |
| Sanguine | Unchanged vitality/omnivamp trait; receives no economy payout behavior |
| Historical docs/art | Retained as dated evidence where useful and labeled as superseded rather than rewritten as current truth |

## Trait and roster constraints

The former Mogul roster removal produces 49 playable units. Laith is a cost-1 Arcanist. Teller and Ivara are not active redesign candidates.

Three different trait acceptance contracts must remain explicit:

1. **Natural capstone availability:** enough authored units exist to field a trait's maximum tier.
2. **Drafting redundancy and cost curve:** a deliberate vertical is realistically draftable, not merely equal to its threshold on paper.
3. **Intended pair fieldability:** two promised full verticals fit on the late-game board, including required overlap or explicit count sources.

The coordinator-verified board cap is 10. Simultaneously fielding Fortified 8 and Arcanist 8 therefore requires at least 6 units counted in both traits, or an explicit trait-count/capacity system. The projected roster has zero Fortified–Arcanist overlap. This is a documented design contradiction, not authorization to lower thresholds or silently alter capacity.

## Laith design boundary

Laith preserves the new person and visual concept: an elegant human woman bound to a spine-mounted ledger who violently expels pressurized tattoo-black ink. Casting is painful, permanently stains her, and erodes her memories. Her current bridge ability exists only to keep the playable roster coherent during this conversion; her final role and kit are deferred.

Her sole active trait is **Arcanist**. Do not assign a secondary trait in this task.

## Validation

The conversion-specific guard is `tests/rga_testing/ci/BloodEconomyConversionSmoke.tscn`. It checks the 49-unit roster, retired packages, Laith's sole trait and non-economy ability, unchanged wager/payout tuning, tie refund, authored reserve asset, and representative player-facing copy.
