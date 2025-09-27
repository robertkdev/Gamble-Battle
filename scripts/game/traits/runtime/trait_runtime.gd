extends RefCounted
class_name TraitRuntime

# Orchestrates trait effects: compiles traits, instantiates handlers, and delegates events.
# Wiring into CombatEngine/AbilitySystem is done by the caller via configure()+wire_signals().

const TraitRegistry := preload("res://scripts/game/traits/runtime/trait_registry.gd")
const TraitContext := preload("res://scripts/game/traits/runtime/trait_context.gd")
const KillEventsLib := preload("res://scripts/game/traits/runtime/kill_events.gd")

var state: BattleState
var engine: CombatEngine
var buff_system: BuffSystem
var ability_system: AbilitySystem

var registry: TraitRegistry = TraitRegistry.new()
var ctx: TraitContext = TraitContext.new()
var kill_events: KillEvents = null

# Active handler instances keyed by trait id
var handlers: Dictionary = {}

var _wired: bool = false

func configure(_engine: CombatEngine, _state: BattleState, _buffs: BuffSystem = null, _abilities: AbilitySystem = null) -> void:
	assert(_engine != null and _state != null)
	engine = _engine
	state = _state
	buff_system = _buffs
	ability_system = _abilities
	ctx.configure(engine, state, buff_system, ability_system)
	kill_events = KillEventsLib.new()
	if kill_events != null and kill_events.has_method("reset"):
		kill_events.reset()
	_instantiate_handlers()

func wire_signals() -> void:
	if engine != null and not engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.connect(_on_hit_applied)
	if engine != null and not engine.is_connected("victory", Callable(self, "_on_outcome")):
		engine.victory.connect(_on_outcome)
	if engine != null and not engine.is_connected("defeat", Callable(self, "_on_outcome")):
		engine.defeat.connect(_on_outcome)
	if ability_system != null and not ability_system.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
		ability_system.ability_cast.connect(_on_ability_cast)
	if kill_events != null and not kill_events.is_connected("unit_killed", Callable(self, "_on_unit_killed")):
		kill_events.unit_killed.connect(_on_unit_killed)
	_wired = true

func unwire_signals() -> void:
	if engine != null and engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.disconnect(_on_hit_applied)
	if engine != null and engine.is_connected("victory", Callable(self, "_on_outcome")):
		engine.victory.disconnect(_on_outcome)
	if engine != null and engine.is_connected("defeat", Callable(self, "_on_outcome")):
		engine.defeat.disconnect(_on_outcome)
	if ability_system != null and ability_system.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
		ability_system.ability_cast.disconnect(_on_ability_cast)
	if kill_events != null and kill_events.is_connected("unit_killed", Callable(self, "_on_unit_killed")):
		kill_events.unit_killed.disconnect(_on_unit_killed)
	_wired = false

func on_battle_start() -> void:
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_battle_start"):
			h.on_battle_start(ctx)

func on_battle_end() -> void:
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_battle_end"):
			h.on_battle_end(ctx)

func process(delta: float) -> void:
	if delta <= 0.0:
		return
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_tick"):
			h.on_tick(ctx, float(delta))

# Internal: build handler set from currently active traits on either team.
func _instantiate_handlers() -> void:
	handlers.clear()
	var p: Dictionary = ctx.compiled_player
	var e: Dictionary = ctx.compiled_enemy
	var traits: Array[String] = []
	for k in p.get("counts", {}).keys(): traits.append(String(k))
	for k2 in e.get("counts", {}).keys(): traits.append(String(k2))
	var seen: Dictionary = {}
	for t in traits:
		var tid := String(t)
		if seen.has(tid):
			continue
		seen[tid] = true
		var h = registry.instantiate(tid)
		if h != null:
			handlers[tid] = h

# === Signal handlers ===
func _on_ability_cast(team: String, index: int, ability_id: String) -> void:
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_ability_cast"):
			h.on_ability_cast(ctx, String(team), int(index), String(ability_id))

func _on_hit_applied(team: String, shooter_index: int, target_index: int, rolled_damage: int, dealt_damage: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	var evt := {
		"team": String(team),
		"source_index": int(shooter_index),
		"target_index": int(target_index),
		"rolled": int(rolled_damage),
		"dealt": int(dealt_damage),
		"crit": bool(crit),
		"before_hp": int(before_hp),
		"after_hp": int(after_hp),
		"player_cd": float(player_cd),
		"enemy_cd": float(enemy_cd)
	}
	# Relay to kill-events detector for traits that depend on kills.
	if kill_events != null:
		var tgt_team: String = ("enemy" if team == "player" else "player")
		kill_events.on_damage(String(team), int(shooter_index), tgt_team, int(target_index), int(dealt_damage), int(after_hp), "attack")
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_hit_applied"):
			h.on_hit_applied(ctx, evt)

func _on_outcome(_stage: int) -> void:
	on_battle_end()

func _on_unit_killed(source_team: String, source_index: int, target_team: String, target_index: int, _kind: String = "") -> void:
	for _k in handlers.keys():
		var h = handlers[_k]
		if h != null and h.has_method("on_unit_killed"):
			h.on_unit_killed(ctx, String(source_team), int(source_index), String(target_team), int(target_index))
