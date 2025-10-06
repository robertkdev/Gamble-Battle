extends Object
class_name RuleProvider

# Contract for stage/chapter behavior providers.
# Providers may implement any subset of these hooks; the runner must guard calls.
#
# StageSpec shape (Dictionary):
#   { ids: Array[String], kind: String, rules: Dictionary }

func on_pre_spawn(spec: Dictionary, ch: int, sic: int) -> void:
    # Called before units are spawned from the spec.
    # May mutate spec["rules"] if needed. No return value.
    pass

func on_post_spawn(units: Array, spec: Dictionary, ch: int, sic: int) -> void:
    # Called after units are constructed from spec.ids (before engine configure).
    # May mutate units array (e.g., apply tags) or adjust rules.
    pass

func on_pre_engine_config(state, engine, spec: Dictionary, ch: int = 0, sic: int = 0) -> void:
    # Called after spawner but before engine.configure(...).
    # Can toggle engine/state or set flags via spec.rules.
    pass

func on_battle_start(state, engine, spec: Dictionary, ch: int = 0, sic: int = 0) -> void:
    # Called after engine.start() and before the first process tick.
    pass

