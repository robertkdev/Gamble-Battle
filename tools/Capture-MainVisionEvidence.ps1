param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'outputs\vision_snapshots\smoke'
$stagedRoot = Join-Path $projectRoot 'outputs\visual_debug\main_vision\staged'
$manifestPath = Join-Path $projectRoot 'outputs\visual_debug\main_vision\captures.json'
$freshnessCutoff = [DateTime]::UtcNow.AddMinutes(-15)
New-Item -ItemType Directory -Path $stagedRoot -Force | Out-Null

$specs = @(
	@{ Prefix = '01_title_'; Name = '01_title.png'; Label = 'Title menu'; State = 'title'; Event = 'title'; Timestamp = 0 },
	@{ Prefix = '02_unit_select_'; Name = '02_unit_select.png'; Label = 'Starter selection'; State = 'unit_select'; Event = 'unit_select'; Timestamp = 1000 },
	@{ Prefix = '03_opening_combat_'; Name = '03_opening_combat.png'; Label = 'Opening fight planning'; State = 'opening_combat'; Event = 'opening_combat'; Timestamp = 2000 },
	@{ Prefix = '04_system_menu_'; Name = '04_system_menu.png'; Label = 'In-run system menu'; State = 'system_menu'; Event = 'system_menu'; Timestamp = 3000 },
	@{ Prefix = '05_post_fight_shop_'; Name = '05_post_fight_shop.png'; Label = 'Post-fight planning shop'; State = 'post_fight_shop'; Event = 'post_fight_shop'; Timestamp = 4000 },
	@{ Prefix = '06_unit_detail_stats_'; Name = '06_unit_detail_stats.png'; Label = 'Scrolled player unit details'; State = 'unit_detail_stats'; Event = 'unit_detail_stats'; Timestamp = 5000 }
)

$captures = foreach ($spec in $specs) {
	$source = Get-ChildItem -LiteralPath $sourceRoot -Filter "$($spec.Prefix)*_viewport.png" |
		Sort-Object LastWriteTimeUtc -Descending |
		Select-Object -First 1
	if ($null -eq $source) {
		throw "Missing authoritative runtime capture for prefix $($spec.Prefix)"
	}
	if ($source.LastWriteTimeUtc -lt $freshnessCutoff) {
		throw "Runtime capture is stale: $($source.FullName)"
	}
	$destination = Join-Path $stagedRoot $spec.Name
	Copy-Item -LiteralPath $source.FullName -Destination $destination -Force
	(Get-Item -LiteralPath $destination).LastWriteTimeUtc = [DateTime]::UtcNow
	@{
		path = "staged/$($spec.Name)"
		label = $spec.Label
		group = 'journey'
		role = 'actual'
		state = $spec.State
		viewport = 'desktop-1920x1080'
		camera = 'player'
		layer = 'final'
		event = $spec.Event
		timestamp_ms = $spec.Timestamp
		metadata = @{
			runtime = 'Godot 4.5 editor game framebuffer'
			scene = 'VisionCaptureSmoke.tscn'
			branch = 'codex/019f7639-37d-playtest'
			source = $source.Name
		}
	}
}

$payload = @{ captures = @($captures) } | ConvertTo-Json -Depth 8
$utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $payload, $utf8WithoutBom)
Write-Output "Wrote $manifestPath with $($captures.Count) fresh player-frame captures."
