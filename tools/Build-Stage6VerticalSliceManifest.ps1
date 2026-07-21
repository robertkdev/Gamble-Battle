param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'outputs\visual_iter\stage6_vertical_slice_pass'
$outputRoot = Join-Path $projectRoot 'outputs\visual_debug\stage6_vertical_slice'
$stagedRoot = Join-Path $outputRoot 'staged'
$manifestPath = Join-Path $outputRoot 'captures.json'
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Name = '00_title_entrance.png'; Label = 'Title entrance'; Group = 'entry'; State = 'title'; Event = 'entry'; Viewport = 'desktop-1920x1080' },
	@{ Name = '01_starter_commit.png'; Label = 'Starter commitment'; Group = 'decision'; State = 'starter'; Event = 'commit'; Viewport = 'desktop-1920x1080' },
	@{ Name = '02_planning_decision_contained.png'; Label = 'Planning decision contained'; Group = 'decision'; State = 'planning'; Event = 'decision'; Viewport = 'desktop-1920x1080' },
	@{ Name = '03_round_stinger_t080.png'; Label = 'Boss contract stinger'; Group = 'combat'; State = 'battle_intro'; Event = 'round_stinger'; Viewport = 'desktop-1920x1080' },
	@{ Name = '04_combat_cluster_readability.png'; Label = 'Combat cluster readability'; Group = 'combat'; State = 'combat'; Event = 'cluster'; Viewport = 'desktop-1920x1080' },
	@{ Name = '05a_boss_phase_normal_t000.png'; Label = 'Boss phase onset'; Group = 'temporal'; State = 'boss_phase'; Event = 'boss_phase'; Timestamp = 0; Viewport = 'desktop-1920x1080' },
	@{ Name = '05b_boss_phase_stinger_t080.png'; Label = 'Boss phase stinger'; Group = 'temporal'; State = 'boss_phase'; Event = 'boss_phase'; Timestamp = 80; Viewport = 'desktop-1920x1080' },
	@{ Name = '05c_boss_phase_settled_t800.png'; Label = 'Boss phase settled'; Group = 'temporal'; State = 'boss_phase'; Event = 'boss_phase'; Timestamp = 800; Viewport = 'desktop-1920x1080' },
	@{ Name = '06_boss_victory_ceremony.png'; Label = 'Boss victory ceremony'; Group = 'consequence'; State = 'boss_victory'; Event = 'consequence'; Viewport = 'desktop-1920x1080' },
	@{ Name = '07_next_planning_reveal.png'; Label = 'Next planning reveal'; Group = 'consequence'; State = 'planning_return'; Event = 'handoff'; Viewport = 'desktop-1920x1080' },
	@{ Name = '08_compact_planning_contained.png'; Label = 'Compact planning contained'; Group = 'compact'; State = 'planning'; Event = 'decision'; Viewport = 'compact-1280x720' },
	@{ Name = '09_compact_round_stinger_t080.png'; Label = 'Compact boss contract stinger'; Group = 'compact'; State = 'battle_intro'; Event = 'round_stinger'; Viewport = 'compact-1280x720' },
	@{ Name = '10_compact_combat_cluster_readability.png'; Label = 'Compact combat cluster readability'; Group = 'compact'; State = 'combat'; Event = 'cluster'; Viewport = 'compact-1280x720' },
	@{ Name = '11_compact_boss_victory_ceremony.png'; Label = 'Compact boss victory ceremony'; Group = 'compact'; State = 'boss_victory'; Event = 'consequence'; Viewport = 'compact-1280x720' }
)

$captures = foreach ($spec in $specs) {
	$source = Join-Path $sourceRoot $spec.Name
	if (-not (Test-Path -LiteralPath $source)) {
		throw "Missing authoritative Stage 6 runtime capture: $source"
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
			scene = 'Stage6VerticalSliceCapture.tscn'
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
Write-Output "Wrote $manifestPath with $($captures.Count) fresh Stage 6 runtime captures."
