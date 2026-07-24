# Gamble Battle Phase 2 Character Concept Ledger

Status: living creative reference
Scope: user-directed Phase 2 concepts and Stage Three redesign directions

This is an additive creative ledger, not a Board approval report, asset manifest, production commitment, or replacement for the locked unit-art criteria. Record each future user-directed concept here when they say to remember it. Preserve the user’s concrete imagery and the reason the idea works; do not silently normalize an unsettling design into a generic fantasy archetype.

## Concept 001 — Brass-Masked Rod Figure

**User response:** loved this concept.

### Definitive image

A very thin, adult-sized figure wears a long, faded burgundy coat. Its sleeves are sewn shut at the wrists, trapping its arms inside the coat. A smooth tarnished-brass mask, shaped like a sad man’s face, sits slightly too low on its head. The bad fit exposes a second pair of blinking eyes above the mask.

Four long iron rods emerge from its shoulder blades and drag behind it like the handles from a broken giant marionette. The rods are physical load-bearing tools, not decorative appendages or floating magic. They brace against floors and walls, launching the figure in violent straight bursts. In combat, it pins targets with the rods and uses the brass mask itself as a hammer.

### Why it works

- It keeps a coherent adult human presence while remaining deeply unsettling.
- It is threatening without becoming cartoonish: the silhouette, materials, body constraint, movement, and attacks all express the same idea.
- The sealed sleeves make the trapped body visible before any lore is needed.
- The low sad-face mask and exposed upper eyes create a specific, wrong human read rather than a generic monster face.
- The rods explain both the violent locomotion and the attack language, turning the figure’s physical limitation into its threat.

### Non-negotiable reads

- Do not simplify this into a generic puppet, mascot, marionette villain, or floating-rod sorcerer.
- Preserve the adult-sized, extremely thin human silhouette; do not make it cute, childlike, bulky, or toy-like.
- Keep the coat faded burgundy, the mask smooth tarnished brass, and the rods long iron with real contact, drag, brace, and impact logic.
- The mask is a weapon. The rods are both restraint and propulsion, not ornamental wings, tendrils, or VFX.
- The design should feel physically constrained, mechanically legible, and abruptly violent.

### Intentionally undecided

Name, roster role, traits, story, faction, and production-art treatment are not assigned yet. Future user dictation may establish them; do not retrofit this concept into an existing unit or approval workflow without an explicit user decision.

## Concept 002 — Malachor: Living Siege Cage

**User decision:** approved and locked as the Stage Three redesign direction.

**Approval boundary:** this selects the concept direction that later Malachor work must preserve. It does not replace the six-phase production process or claim final production-art approval/concept lock; that formal gate remains reserved for Phase Six.

**Preserved reference:** [`../../assets/concepts/phase3_redesign/malachor/malachor_living_siege_cage_selected_direction.png`](../../assets/concepts/phase3_redesign/malachor/malachor_living_siege_cage_selected_direction.png)

The preserved image is a non-destructive concept reference. It does not replace the current live unit asset at `assets/units/malachor.png`.

### Definitive direction

Malachor is rebuilt as a living siege cage. He retains his oppressive tank mass and lockdown identity, but no longer reads as a conventional armored boss. A colossal human-shaped body is trapped inside four or five uneven matte-black coffin plates. The plates are chained to a heavy collar and a single rigid spinal rail. Dry, pale skin appears through the gaps, and an exhausted, aware face is pressed behind a grille in the chest.

His legs are visibly weak. The coffin plates brace against the ground to support them, making the cage both prison and load-bearing body. This dependence is essential: Malachor is not a powerful knight wearing armor, but a captive mass made mobile and dangerous by the apparatus around him.

### Lockdown and attack language

The plates anchor into the ground, unfold around a target, then swing inward to imprison and crush. The same physical system explains his silhouette, locomotion, tank durability, crowd-control role, and finishing action. His threat comes from enclosure and compression rather than weapon flourishes or oversized hands.

### Non-negotiable reads

- Preserve the colossal human presence, oppressive tank mass, and lockdown identity.
- Keep four or five uneven matte-black coffin plates, the heavy collar, chains, and one rigid spinal rail as a coherent physical system.
- Show dry pale skin through gaps and an exhausted, aware human face behind the chest grille.
- Keep the legs weak and visibly supported by plates braced against the ground.
- The plates must anchor, unfold around a target, swing inward, imprison, and crush.
- Avoid a conventional helmet or knight-armor read.
- Avoid a crab-shell silhouette, giant claws, green glow, decorative spikes, and glossy raid-boss language.
- Avoid generic golem, mascot, or fantasy-brute simplification.

### Intentionally undecided

This direction does not yet settle final model construction, animation timing, gameplay-scale simplification, portrait crop, production materials, or replacement of the live unit asset. Those belong to later phases and the Phase Six formal approval gate.

## Concept 003 — Knoll: Foreclosure Press

**User decision:** approved and hard-locked as the Stage Three redesign direction.

**Approval boundary:** this is the binding creative and future-gameplay direction for later Knoll work. It does not replace the six-phase production process or claim the later Phase Six final concept/production lock.

**Preserved reference:** [`../../assets/concepts/phase3_redesign/knoll/knoll_foreclosure_press_selected_direction.png`](../../assets/concepts/phase3_redesign/knoll/knoll_foreclosure_press_selected_direction.png)

The image is a non-destructive Stage Three reference. It does not replace the current live asset at `assets/units/knoll.png`, and this record makes no gameplay-code change.

### Definitive visual direction

Knoll is no longer a goblin accountant. He is a small, gaunt adult human in a decayed merchant coat permanently sewn into his shoulders. He is hunched because an enormous vertical brass printing press is built through his ribcage, with two flat plates visible inside his chest. His face is itself compressed: his nose flattened, cheeks forced outward, and mouth reduced to a narrow horizontal line.

His ordinary arms remain folded or bound behind his back. Two much longer black articulated mechanical arms unfold from inside the coat. Their clamp-like hands seize an enemy and pull them into the chest press. The result is adult body-horror: solemn, materially physical, and threatening rather than campy, whimsical, or cute.

### Locked future ability direction — `Foreclosure Press`

When gameplay implementation begins, replace `Receipt Mark` with `Foreclosure Press`:

1. Knoll's clamp arms grab one enemy, physically remove/pull that target from position, and drag it into the chest press.
2. The press slams shut, dealing physical damage and stunning the target.
3. On release, the target bears a black `Foreclosed` stamp for several seconds.
4. While `Foreclosed`, the target's armor and magic resistance are seized, it cannot gain shields, and part of the stolen defenses is divided among Knoll's allies.

This expresses Trader/Harmony as physical repossession and redistribution, not spellcasting.

### Identity continuity for implementation

- Keep primary role `support`.
- Keep primary goal `support.enemy_lockdown`.
- Keep approaches `lockdown`, `debuff`, and `disrupt`.
- Preserve `support.formation_breaking` as an alternate.
- Reconsider or replace the old `mage.area_denial_zone` alternate when gameplay work starts; the preferred replacement space is defense redistribution or single-target exploitation.

### Non-negotiable reads and vetoes

- Preserve the small gaunt adult-human body, decayed merchant coat, body-integrated brass press, compressed face, bound ordinary arms, and long black mechanical clamp arms.
- The press and arms must be a single physical repossession system: seize, pull, press, stamp, and redistribute defenses.
- No goblin ears or goblin face.
- No abacus, papers, scroll bundle, bookkeeper joke, or top hat.
- No steampunk whimsy, mascot proportions, children's-book monster, glossy gacha styling, or campy read.
- No handheld weapon, magic orb, random spikes, or generic demon anatomy.

### Intentionally deferred

Final model construction, animation timing, numerical ability tuning, exact displacement rules, status duration, defense-share values, portrait crop, and replacement of the live unit asset remain later production work. They must inherit this locked direction and pass the Phase Six formal approval gate.

## Future entries

Add future user-approved concepts as a new numbered section with:

1. the concrete visual and combat image;
2. why the user likes it or why it works;
3. non-negotiable reads and anti-generic guardrails; and
4. any deliberately undecided details.
