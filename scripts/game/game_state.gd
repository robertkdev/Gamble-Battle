extends Node

# Minimal global game state: phase/stage + signals.

enum GamePhase { MENU, PREVIEW, COMBAT, POST_COMBAT }

var phase: int = GamePhase.MENU
var stage: int = 1

signal phase_changed(prev: int, next: int)
signal stage_changed(prev: int, next: int)

func set_phase(p: int) -> void:
	if p == phase:
		return
	var prev := phase
	phase = p
	phase_changed.emit(prev, phase)

func set_stage(s: int) -> void:
	if s == stage:
		return
	var prev := stage
	stage = s
	stage_changed.emit(prev, stage)
