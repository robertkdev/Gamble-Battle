param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$attackRoot = Join-Path $projectRoot 'outputs\visual_iter\attack_visuals_pass'
$resultRoot = Join-Path $projectRoot 'outputs\visual_iter\post_combat_planning_beat_pass'
$outputRoot = Join-Path $projectRoot 'outputs\visual_debug\phase4_combat_presentation'
$stagedRoot = Join-Path $outputRoot 'staged'
$manifestPath = Join-Path $outputRoot 'captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ SourceRoot = $attackRoot; Name = 'opening_frontline_01_anticipation_t040.png'; Label = 'Frontline anticipation'; Group = 'temporal'; State = 'anticipation'; Event = '00_attack'; Timestamp = 40; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'opening_frontline_02_release_t120.png'; Label = 'Frontline release'; Group = 'temporal'; State = 'release'; Event = '00_attack'; Timestamp = 120; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'opening_frontline_03_impact_arrival.png'; Label = 'Frontline contact'; Group = 'temporal'; State = 'impact'; Event = '00_attack'; Timestamp = 220; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'opening_frontline_04_recovery.png'; Label = 'Frontline recovery'; Group = 'temporal'; State = 'recovery'; Event = '00_attack'; Timestamp = 500; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'engage_arcane_03_impact_arrival.png'; Label = 'Arcane family impact'; Group = 'attack_family'; State = 'arcane'; Event = '01_attack_family'; Timestamp = 220; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'blood_precision_03_impact_arrival.png'; Label = 'Precision family impact'; Group = 'attack_family'; State = 'precision'; Event = '01_attack_family'; Timestamp = 220; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'support_voltage_03_impact_arrival.png'; Label = 'Support family impact'; Group = 'attack_family'; State = 'support'; Event = '01_attack_family'; Timestamp = 220; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $resultRoot; Name = '01d_post_victory_consequence_hold.png'; Label = 'Victory consequence'; Group = 'consequence'; State = 'victory'; Event = '02_victory'; Timestamp = 480; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $resultRoot; Name = '01a_post_defeat_impact_ceremony.png'; Label = 'Defeat impact'; Group = 'consequence'; State = 'defeat'; Event = '03_defeat'; Timestamp = 220; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $resultRoot; Name = '01c_boss_victory_consequence_hold.png'; Label = 'Boss victory hold'; Group = 'consequence'; State = 'boss_victory'; Event = '04_boss_victory'; Timestamp = 480; Viewport = 'desktop-1920x1080' },
	@{ SourceRoot = $attackRoot; Name = 'engage_arcane_1280x720_03_impact_arrival.png'; Label = 'Compact arcane impact'; Group = 'compact'; State = 'impact'; Event = '05_compact'; Timestamp = 220; Viewport = 'compact-1280x720' },
	@{ SourceRoot = $attackRoot; Name = 'engage_arcane_1366x768_03_impact_arrival.png'; Label = 'Compact arcane impact wide'; Group = 'compact'; State = 'impact'; Event = '05_compact'; Timestamp = 220; Viewport = 'compact-1366x768' }
)

$captures = foreach ($spec in $specs) {
	$source = Join-Path $spec.SourceRoot $spec.Name
	if (-not (Test-Path -LiteralPath $source)) {
		throw "Missing authoritative Phase 4 runtime capture: $source"
	}
	$destination = Join-Path $stagedRoot $spec.Name
	Copy-Item -LiteralPath $source -Destination $destination -Force
	(Get-Item -LiteralPath $destination).LastWriteTimeUtc = [DateTime]::UtcNow
	@{
		path = "staged/$($spec.Name)"
		label = $spec.Label
		group = $spec.Group
		role = 'frame'
		state = $spec.State
		viewport = $spec.Viewport
		camera = 'player'
		layer = 'final'
		event = $spec.Event
		timestamp_ms = $spec.Timestamp
		metadata = @{
			runtime = 'Godot 4.5 editor game framebuffer'
			scenes = 'AttackVisualSignatureCapture.tscn + PostCombatPlanningBeatSmoke.tscn'
			build = 'codex/019f80d9-676-task'
		}
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh Phase 4 runtime captures."
