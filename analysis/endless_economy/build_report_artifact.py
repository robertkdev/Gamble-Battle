#!/usr/bin/env python3
"""Build the canonical report artifact from reviewed model outputs."""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
ANALYSIS_DIR = ROOT / "analysis" / "endless_economy"
ARTIFACT_PATH = ANALYSIS_DIR / "artifact.json"


def read_csv(name: str) -> list[dict[str, Any]]:
	with (ANALYSIS_DIR / name).open("r", encoding="utf-8", newline="") as handle:
		rows: list[dict[str, Any]] = list(csv.DictReader(handle))
	for row in rows:
		for key, value in list(row.items()):
			if value == "":
				row[key] = None
				continue
			try:
				number: float = float(value)
			except (TypeError, ValueError):
				continue
			row[key] = int(number) if number.is_integer() else number
	return rows


def values_sql(rows: list[dict[str, Any]], fields: list[str], table_name: str) -> str:
	def literal(value: Any) -> str:
		if value is None:
			return "NULL"
		if isinstance(value, (int, float)):
			return str(value)
		return "'" + str(value).replace("'", "''") + "'"

	values: list[str] = []
	for row in rows:
		values.append("(" + ", ".join(literal(row[field]) for field in fields) + ")")
	return (
		f"WITH {table_name} ({', '.join(fields)}) AS (\n  VALUES\n    "
		+ ",\n    ".join(values)
		+ f"\n)\nSELECT * FROM {table_name};"
	)


def source(
	source_id: str,
	label: str,
	path: str,
	rows: list[dict[str, Any]],
	fields: list[str],
	description: str,
	metric_definitions: list[str],
) -> dict[str, Any]:
	return {
		"id": source_id,
		"label": label,
		"path": path,
		"query": {
			"engine": "SQLite",
			"language": "sql",
			"sql": values_sql(rows, fields, source_id.replace("-", "_")),
			"description": description,
			"tables_used": [path],
			"filters": ["Deterministic model output generated from the checked-in baseline and fixed seed."],
			"metric_definitions": metric_definitions,
		},
	}


def build() -> dict[str, Any]:
	curve_rows: list[dict[str, Any]] = read_csv("recommended_curve.csv")
	policy_rows: list[dict[str, Any]] = [
		row for row in read_csv("policy_summary.csv") if row["policy"] != "_selected_model"
	]
	milestones: list[dict[str, Any]] = [
		row for row in curve_rows if row["chapter"] in {1, 5, 10, 20, 40, 60, 80}
	]
	unit_candidates: list[dict[str, Any]] = [
		{
			"candidate": "Current",
			"prices": "1 / 2 / 3 / 4 / 5",
			"price_power_cv": 0.1303,
			"top_tier_doublings": 0.0,
			"decision": "Keep for base units",
		},
		{
			"candidate": "Moderate widening",
			"prices": "1 / 2 / 4 / 7 / 11",
			"price_power_cv": 0.2662,
			"top_tier_doublings": 1.1375,
			"decision": "Reject as main sink",
		},
		{
			"candidate": "Broad exponential",
			"prices": "1 / 3 / 10 / 30 / 100",
			"price_power_cv": 0.9469,
			"top_tier_doublings": 4.3219,
			"decision": "Reject as main sink",
		},
	]
	now: str = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
	curve_source: dict[str, Any] = source(
		"curve-source",
		"Recommended 80-chapter economy curve",
		"analysis/endless_economy/recommended_curve.csv",
		curve_rows,
		[
			"chapter",
			"reference_bankroll",
			"standard_contract_price",
			"bold_contract_price",
			"reroll_price",
			"xp_or_command_price",
			"donor_contract_fee",
		],
		"Fixed reference bankroll and player-facing prices by chapter.",
		[
			"Reference bankroll = 3 * 1.22^(chapter - 1).",
			"Standard contract price = 1-2-5 rounded band near 20% of reference bankroll.",
			"Bold contract price = next visible 1-2-5 band above the standard option.",
			"Prices never use the player's current bankroll.",
		],
	)
	policy_source: dict[str, Any] = source(
		"policy-source",
		"Monte Carlo betting-policy validation",
		"analysis/endless_economy/policy_summary.csv",
		policy_rows,
		[
			"policy",
			"simulations",
			"survival_rate",
			"median_bankroll",
			"median_total_earned",
			"median_contracts_bought",
			"mean_win_probability",
			"mean_bet_fraction",
		],
		"Five deterministic policy cohorts, each simulated 5,000 times across 40 chapters.",
		[
			"Survival rate = share of simulations completing all 40 modeled chapters.",
			"Median total earned = median cumulative gross winnings, not ending bankroll.",
			"Odds-aware policy uses a fractional Kelly rule clamped to a minority wager.",
		],
	)
	unit_source: dict[str, Any] = source(
		"unit-source",
		"Base unit price candidate comparison",
		"analysis/endless_economy/live_baseline.json",
		unit_candidates,
		["candidate", "prices", "price_power_cv", "top_tier_doublings", "decision"],
		"Candidate tier schedules compared against the current 1.5x per-level stat multiplier.",
		[
			"Price-power CV = coefficient of variation of price divided by modeled power.",
			"Lower CV means more consistent value per gold across unit tiers.",
		],
	)
	sources: list[dict[str, Any]] = [
		curve_source,
		policy_source,
		unit_source,
		{
			"id": "notebook-source",
			"label": "Executable economy model notebook",
			"path": "analysis/endless_economy/endless_economy_model.ipynb",
		},
		{
			"id": "blueprint-source",
			"label": "Implementation blueprint",
			"path": "docs/research/endless_economy_blueprint_2026-07-16.md",
		},
		{
			"id": "tockers-source",
			"label": "Riot Games — Tocker's Trials mode overview",
			"href": "https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/new-tft-workshop-mode-tockers-trials/",
		},
		{
			"id": "last-flame-source",
			"label": "The Last Flame — official announcements",
			"href": "https://steamcommunity.com/app/1830970/announcements/?l=english",
		},
		{
			"id": "hadean-source",
			"label": "Hadean Tactics — Eternal Rift overview and updates",
			"href": "https://emberfishgames.com/hadean-tactics",
		},
	]
	return {
		"surface": "report",
		"manifest": {
			"version": 1,
			"surface": "report",
			"title": "Gamble Battle Endless Economy — Decision Blueprint",
			"description": "A research-backed, simulation-checked economy and escalation blueprint.",
			"generatedAt": now,
			"sources": sources,
			"cards": [
				{
					"id": "target-odds",
					"description": "Normal fights should feel favorable but not safe.",
					"dataset": "headline",
					"sourceId": "curve-source",
					"metrics": [{"label": "Target projected win odds", "field": "target_odds", "format": "percent"}],
				},
				{
					"id": "curve-growth",
					"description": "The independent curve used for prices and content budgets.",
					"dataset": "headline",
					"sourceId": "curve-source",
					"metrics": [{"label": "Reference bankroll growth / chapter", "field": "curve_growth", "format": "percent"}],
				},
				{
					"id": "normal-survival",
					"description": "Odds-aware policy completion rate across 40 modeled chapters.",
					"dataset": "headline",
					"sourceId": "policy-source",
					"metrics": [{"label": "Odds-aware survival", "field": "normal_survival", "format": "percent"}],
				},
				{
					"id": "hoard-penalty",
					"description": "Ten-times-price hoarding fails to become the dominant strategy.",
					"dataset": "headline",
					"sourceId": "policy-source",
					"metrics": [{"label": "10x hoarder earnings vs odds-aware", "field": "hoard_ratio", "format": "percent"}],
				},
			],
			"charts": [
				{
					"id": "price-curve",
					"title": "Player-facing price curve by chapter",
					"subtitle": "Fixed 1-2-5 price bands derived from the independent reference curve; logarithmic growth is shown as exact values in the milestone table.",
					"type": "line",
					"dataset": "curve",
					"sourceId": "curve-source",
					"encodings": {
						"x": {"field": "chapter", "type": "ordinal", "label": "Chapter"},
						"y": {"field": "standard_contract_price", "type": "quantitative", "label": "Gold"},
						"tooltip": [
							{"field": "reference_bankroll", "type": "quantitative", "label": "Reference bankroll"},
							{"field": "bold_contract_price", "type": "quantitative", "label": "Bold contract"},
							{"field": "donor_contract_fee", "type": "quantitative", "label": "Donor fee"},
						],
					},
					"xAxisTitle": "Chapter",
					"yAxisTitle": "Standard contract price (gold)",
					"valueFormat": "compact",
					"layout": "full",
				},
				{
					"id": "policy-earnings",
					"title": "Median money earned by betting policy",
					"subtitle": "5,000 simulations per policy over 40 chapters; exact survival and behavior fields remain available in the supporting table.",
					"type": "bar",
					"dataset": "policies",
					"sourceId": "policy-source",
					"encodings": {
						"x": {"field": "policy", "type": "nominal", "label": "Policy"},
						"y": {"field": "median_total_earned", "type": "quantitative", "label": "Median total earned"},
						"tooltip": [
							{"field": "survival_rate", "type": "quantitative", "format": "percent", "label": "Survival"},
							{"field": "median_contracts_bought", "type": "quantitative", "label": "Contracts bought"},
							{"field": "mean_bet_fraction", "type": "quantitative", "format": "percent", "label": "Mean bet fraction"},
						],
					},
					"xAxisTitle": "Betting policy",
					"yAxisTitle": "Median cumulative winnings",
					"valueFormat": "compact",
					"layout": "full",
				},
			],
			"tables": [
				{
					"id": "milestone-table",
					"title": "Milestone price schedule",
					"subtitle": "Exact player-facing prices at selected chapters.",
					"dataset": "milestones",
					"sourceId": "curve-source",
					"defaultSort": {"field": "chapter", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "chapter", "label": "Chapter", "format": "number"},
						{"field": "reference_bankroll", "label": "Reference bank", "format": "compact"},
						{"field": "standard_contract_price", "label": "Standard", "format": "compact"},
						{"field": "bold_contract_price", "label": "Bold", "format": "compact"},
						{"field": "reroll_price", "label": "Scout/reroll", "format": "compact"},
						{"field": "xp_or_command_price", "label": "XP/command", "format": "compact"},
						{"field": "donor_contract_fee", "label": "Donor fee", "format": "compact"},
					],
				},
				{
					"id": "unit-price-table",
					"title": "Base unit price candidates",
					"subtitle": "Widening fixed unit tiers buys little exponential runway and worsens value consistency.",
					"dataset": "unit_candidates",
					"sourceId": "unit-source",
					"defaultSort": {"field": "price_power_cv", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "candidate", "label": "Candidate", "type": "text"},
						{"field": "prices", "label": "Tier prices", "type": "text"},
						{"field": "price_power_cv", "label": "Price/power CV", "format": "number"},
						{"field": "top_tier_doublings", "label": "Extra doublings", "format": "number"},
						{"field": "decision", "label": "Decision", "type": "text"},
					],
				},
				{
					"id": "policy-table",
					"title": "Policy validation details",
					"subtitle": "Normal strategies retain comparable survival while pathological hoarding and all-in behavior are unattractive.",
					"dataset": "policies",
					"sourceId": "policy-source",
					"defaultSort": {"field": "median_total_earned", "direction": "desc"},
					"layout": "full",
					"columns": [
						{"field": "policy", "label": "Policy", "type": "text"},
						{"field": "survival_rate", "label": "Survival", "format": "percent"},
						{"field": "median_bankroll", "label": "Median bank", "format": "compact"},
						{"field": "median_total_earned", "label": "Median earned", "format": "compact"},
						{"field": "median_contracts_bought", "label": "Contracts", "format": "number"},
						{"field": "mean_win_probability", "label": "Mean win odds", "format": "percent"},
						{"field": "mean_bet_fraction", "label": "Mean wager", "format": "percent"},
					],
				},
			],
			"blocks": [
				{"id": "title", "type": "markdown", "body": "# Gamble Battle Endless Economy — Decision Blueprint"},
				{"id": "exec-heading", "type": "markdown", "body": "## Executive Summary"},
				{
					"id": "exec-body",
					"type": "markdown",
					"body": (
						"Keep the existing **1–5 base unit prices**. They are already better aligned with current "
						"power scaling than wider fixed tiers, and even a 1–100 schedule adds only about 4.3 doublings. "
						"Put exponential spending into **chapter contracts, donor fees, scouting, and command research**.\n\n"
						"Target normal pre-fight projections near **68% win odds**, quote payouts from those odds, and "
						"make a minority wager the normal behavior. Use a fixed reference curve—not the player's current "
						"wallet—to set prices. Every five-fight chapter should end with one mutually exclusive, identity-"
						"changing purchase that visibly escalates combat."
					),
				},
				{"id": "headline", "type": "metric-strip", "cardIds": ["target-odds", "curve-growth", "normal-survival", "hoard-penalty"]},
				{"id": "research-heading", "type": "markdown", "body": "## What the Reference Modes Contribute"},
				{
					"id": "research-body",
					"type": "markdown",
					"body": (
						"Riot's Tocker's Trials was not literally endless: it used 30 rounds, six bosses, three lives, "
						"solo planning without timers, a high score, and a separate Chaos layer. The useful lesson is its "
						"clear boss cadence and permission to show boards outside normal TFT constraints. The Last Flame's "
						"endless act and Hadean Tactics' Eternal Rift reinforce the value of run-specific build mutation, "
						"save/resume support, and new upgrade vocabularies after the ordinary roster loop is mature.\n\n"
						"Gamble Battle should combine those structures with incremental-game arithmetic: a visible "
						"exponential reference curve, periodic qualitative breakpoints, and reset boundaries that preserve "
						"identity without adding permanent exponential combat power."
					),
				},
				{"id": "decision-heading", "type": "markdown", "body": "## Decisions to Lock"},
				{
					"id": "decision-body",
					"type": "markdown",
					"body": (
						"1. **Unit shop:** retain 1–5 prices for ordinary recruitment; later shops become donor and contract markets.\n"
						"2. **Pricing:** use `3 × 1.22^(chapter−1)` as the first tuning reference, then round offers to readable 1-2-5 bands.\n"
						"3. **Odds and payouts:** start with `gross payout = clamp(1.45 / projected win probability, 1.05, 4.0)`; recalibrate before production.\n"
						"4. **Escalation:** one chapter contract every five fights; contracts create transformations, chains, hazards, trait rewrites, or command changes—not repeatable +1% stats.\n"
						"5. **Run structure:** endless multi-session runs persist inside a run; after defeat, preserve identity/history only, not compounding power.\n"
						"6. **Score:** emphasize total money earned and depth, with peak bank and biggest wager as secondary records."
					),
				},
				{"id": "curve-heading", "type": "markdown", "body": "## The Independent Price Curve"},
				{
					"id": "curve-body",
					"type": "markdown",
					"body": (
						"The reference curve is a content budget, not a rubber band. It defines what a healthy run should "
						"be able to earn and spend by chapter. Standard contracts cost roughly 20% of that reference; "
						"bold offers occupy the next visible price band. Actual wallet size never enters the price formula."
					),
				},
				{"id": "curve-chart-block", "type": "chart", "chartId": "price-curve"},
				{"id": "milestone-block", "type": "table", "tableId": "milestone-table"},
				{"id": "unit-heading", "type": "markdown", "body": "## Unit Prices Are Not the Exponential Sink"},
				{
					"id": "unit-body",
					"type": "markdown",
					"body": (
						"The current unit tiers should stay cheap and legible. Raising their fixed prices distorts value "
						"faster than it creates runway. A late-game unit can instead be valuable because it is the required "
						"donor, catalyst, or identity component for a chapter contract whose fee follows the large curve."
					),
				},
				{"id": "unit-table-block", "type": "table", "tableId": "unit-price-table"},
				{"id": "policy-heading", "type": "markdown", "body": "## Betting Behavior Check"},
				{
					"id": "policy-body",
					"type": "markdown",
					"body": (
						"With the selected provisional parameters, odds-aware and fixed-25% strategies both complete 40 "
						"chapters in about 70% of runs, while conservative play trades earnings for survival. A player who "
						"waits for ten times the contract price earns only about 1.7% as much as the odds-aware policy, and "
						"repeated all-in play collapses immediately."
					),
				},
				{"id": "policy-chart-block", "type": "chart", "chartId": "policy-earnings"},
				{"id": "policy-table-block", "type": "table", "tableId": "policy-table"},
				{"id": "roadmap-heading", "type": "markdown", "body": "## Content Roadmap"},
				{
					"id": "roadmap-body",
					"type": "markdown",
					"body": (
						"**Chapters 1–5:** ordinary roster building, current reroll/XP prices, first low-cost contract tutorial.\n\n"
						"**Chapters 6–15:** contracts add first qualitative mutations; duplicate units begin serving as named donors.\n\n"
						"**After level 14 / level-4 cap:** XP becomes Command Research and duplicate combining stops. "
						"Spending shifts to team rules, formation capacity, targeted scouting, trait rewrites, item awakenings, "
						"enemy modifiers, and spectacle systems.\n\n"
						"**Deep endless:** escalation comes from readable event chains—splits, summons, transformations, "
						"chain reactions, boss phases, hazards, and battlefield-wide payoffs—while board cap and UI readability remain bounded."
					),
				},
				{"id": "risks-heading", "type": "markdown", "body": "## Caveats and Required Tests"},
				{
					"id": "risks-body",
					"type": "markdown",
					"body": (
						"This is a blueprint, not production balance. The saved odds calibration has only 144 samples and "
						"is weakest in the outer probability buckets. The combat-rating model is a budgeting proxy, not a "
						"full unit-power estimator. The Monte Carlo model omits player skill, shop variance, composition "
						"synergy, and content-specific contract value.\n\n"
						"Before implementation, run: (1) larger odds calibration; (2) contract-choice prototypes at chapters "
						"5, 20, and 40; (3) readability tests for chain-reaction fights; (4) price sensitivity around 18–24% "
						"of the reference curve; and (5) multi-session save/resume and defeat-reset UX tests."
					),
				},
			],
		},
		"snapshot": {
			"version": 1,
			"generatedAt": now,
			"status": "ready",
			"datasets": {
				"headline": [
					{
						"target_odds": 0.68,
						"curve_growth": 0.22,
						"normal_survival": 0.7018,
						"hoard_ratio": round(540.66 / 31809.88, 6),
					}
				],
				"curve": curve_rows,
				"milestones": milestones,
				"policies": policy_rows,
				"unit_candidates": unit_candidates,
			},
			"accessIssues": [],
		},
		"sources": sources,
	}


def main() -> None:
	artifact: dict[str, Any] = build()
	ARTIFACT_PATH.write_text(json.dumps(artifact, indent=2), encoding="utf-8")
	print(ARTIFACT_PATH)


if __name__ == "__main__":
	main()
