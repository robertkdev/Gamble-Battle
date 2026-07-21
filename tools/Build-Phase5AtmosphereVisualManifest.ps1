param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'outputs\visual_iter\phase5_atmosphere_pass'
$outputRoot = Join-Path $projectRoot 'outputs\visual_debug\phase5_atmosphere'
$stagedRoot = Join-Path $outputRoot 'staged'
$manifestPath = Join-Path $outputRoot 'captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Name = '00_planning_authored_light.png'; Label = 'Planning authored light'; Group = 'planning'; State = 'planning'; Event = '00_planning'; Viewport = 'desktop-1920x1080' },
	@{ Name = '01_combat_authored_light.png'; Label = 'Combat color split'; Group = 'combat'; State = 'combat'; Event = '01_combat_open'; Viewport = 'desktop-1920x1080' },
	@{ Name = '02a_boss_escalation_t000.png'; Label = 'Boss escalation onset'; Group = 'temporal'; State = 'escalation'; Event = '02_boss_escalation'; Timestamp = 0; Viewport = 'desktop-1920x1080' },
	@{ Name = '02b_boss_escalation_t120.png'; Label = 'Boss escalation crest'; Group = 'temporal'; State = 'escalation'; Event = '02_boss_escalation'; Timestamp = 120; Viewport = 'desktop-1920x1080' },
	@{ Name = '02c_boss_escalation_t520.png'; Label = 'Boss escalation decay'; Group = 'temporal'; State = 'escalation'; Event = '02_boss_escalation'; Timestamp = 520; Viewport = 'desktop-1920x1080' },
	@{ Name = '03_victory_color_consequence.png'; Label = 'Victory consequence color'; Group = 'consequence'; State = 'victory'; Event = '03_victory'; Viewport = 'desktop-1920x1080' },
	@{ Name = '04_defeat_color_consequence.png'; Label = 'Defeat consequence color'; Group = 'consequence'; State = 'defeat'; Event = '04_defeat'; Viewport = 'desktop-1920x1080' },
	@{ Name = '05_compact_planning_authored_light.png'; Label = 'Compact planning authored light'; Group = 'compact'; State = 'planning'; Event = '05_compact_planning'; Viewport = 'compact-1280x720' },
	@{ Name = '06_compact_combat_authored_light.png'; Label = 'Compact combat color split'; Group = 'compact'; State = 'combat'; Event = '06_compact_combat'; Viewport = 'compact-1280x720' },
	@{ Name = '07a_compact_boss_escalation_t000.png'; Label = 'Compact boss escalation onset'; Group = 'temporal'; State = 'escalation'; Event = '07_compact_escalation'; Timestamp = 0; Viewport = 'compact-1280x720' },
	@{ Name = '07b_compact_boss_escalation_t120.png'; Label = 'Compact boss escalation crest'; Group = 'temporal'; State = 'escalation'; Event = '07_compact_escalation'; Timestamp = 120; Viewport = 'compact-1280x720' },
	@{ Name = '07c_compact_boss_escalation_t520.png'; Label = 'Compact boss escalation decay'; Group = 'temporal'; State = 'escalation'; Event = '07_compact_escalation'; Timestamp = 520; Viewport = 'compact-1280x720' },
	@{ Name = '08_compact_victory_color_consequence.png'; Label = 'Compact victory consequence'; Group = 'compact'; State = 'victory'; Event = '08_compact_victory'; Viewport = 'compact-1280x720' },
	@{ Name = '09_compact_defeat_color_consequence.png'; Label = 'Compact defeat consequence'; Group = 'compact'; State = 'defeat'; Event = '09_compact_defeat'; Viewport = 'compact-1280x720' }
)

$captures = foreach ($spec in $specs) {
	$source = Join-Path $sourceRoot $spec.Name
	if (-not (Test-Path -LiteralPath $source)) {
		throw "Missing authoritative Phase 5 runtime capture: $source"
	}
	$destination = Join-Path $stagedRoot $spec.Name
	Copy-Item -LiteralPath $source -Destination $destination -Force
	(Get-Item -LiteralPath $destination).LastWriteTimeUtc = [DateTime]::UtcNow
	$capture = @{
		path = "staged/$($spec.Name)"
		label = $spec.Label
		group = $spec.Group
		role = 'frame'
		state = $spec.State
		viewport = $spec.Viewport
		camera = 'player'
		layer = 'final'
		event = $spec.Event
		metadata = @{
			runtime = 'Godot 4.5 editor game framebuffer'
			scene = 'Phase5AtmosphereCapture.tscn'
			build = 'codex/019f80d9-676-task'
		}
	}
	if ($spec.ContainsKey('Timestamp')) {
		$capture.timestamp_ms = $spec.Timestamp
	}
	$capture
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh Phase 5 runtime captures."
