param(
	[string]$ReportDir = "$env:APPDATA\Godot\app_userdata\Gamble Battle\identity_reports",
	[string]$OutputDir = "outputs/audit_playtest/rga_accepted_misses_2026_06_25",
	[string[]]$IgnoredReportNames = @("faeling.json")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-StringArray($Value) {
	$out = @()
	if ($null -eq $Value) {
		return $out
	}
	if ($Value -is [System.Array]) {
		foreach ($item in $Value) {
			$out += [string]$item
		}
		return $out
	}
	$out += [string]$Value
	return $out
}

function Get-OptionalProperty($Object, [string]$Name, $DefaultValue = $null) {
	if ($null -eq $Object) {
		return $DefaultValue
	}
	if ($Object.PSObject.Properties.Name -contains $Name) {
		return $Object.$Name
	}
	return $DefaultValue
}

function Get-SpanTopic($Label) {
	$text = [string]$Label
	if ($text -match 'peel|cleanse|cc_immunity|cc_prevented|cc_sync|debuff_cleanse|tenacity|cooldown_trade') {
		return "support_peel_cleanse_cc"
	}
	if ($text -match 'backline_share|team_share|sustained_z|team_damage_share|long_range_damage_share|pressure_without_exposure') {
		return "marksman_damage_positioning"
	}
	if ($text -match 'burst|execute|kill|peak_1s') {
		return "burst_execute_kill"
	}
	if ($text -match 'frontline|body_block|redirect|taunt|engage') {
		return "tank_redirect_frontline"
	}
	if ($text -match 'sustain|ehp_ratio') {
		return "sustain_survival"
	}
	if ($text -match 'targets_hit|aoe|wombo') {
		return "aoe_wombo_targeting"
	}
	if ($text -match 'step_tiles|displacement|backline_contact') {
		return "mobility_reposition"
	}
	if ($text -match 'direct_attrition') {
		return "brawler_direct_attrition"
	}
	if ($text -match 'magic_share') {
		return "magic_share"
	}
	if ($text -match 'ramp') {
		return "ramp_state"
	}
	return "other"
}

function Count-By($Rows, $PropertyName) {
	$map = [ordered]@{}
	foreach ($row in $Rows) {
		$key = [string]$row.$PropertyName
		if (-not $map.Contains($key)) {
			$map[$key] = 0
		}
		$map[$key] = [int]$map[$key] + 1
	}
	return $map
}

function Count-KeywordBuckets($Rows) {
	$buckets = [ordered]@{
		support_peel_cleanse_cc = 'peel|cleanse|cc_immunity|cc_prevented|cc_sync|debuff_cleanse|tenacity|cooldown_trade'
		ramp_state = 'ramp'
		sustain_survival = 'sustain|ehp_ratio'
		marksman_damage_positioning = 'backline_share|team_share|sustained_z|team_damage_share|long_range_damage_share|pressure_without_exposure'
		burst_execute_kill = 'burst|execute|kill|peak_1s'
		tank_redirect_frontline = 'frontline|body_block|redirect|taunt|engage'
		aoe_wombo_targeting = 'targets_hit|aoe|wombo'
		mobility_reposition = 'step_tiles|displacement|backline_contact'
		brawler_direct_attrition = 'direct_attrition'
		magic_share = 'magic_share'
	}
	$out = [ordered]@{}
	foreach ($bucket in $buckets.Keys) {
		$pattern = $buckets[$bucket]
		$out[$bucket] = @($Rows | Where-Object { [string]$_.label -match $pattern }).Count
	}
	return $out
}

if (-not (Test-Path -LiteralPath $ReportDir)) {
	throw "ReportDir not found: $ReportDir"
}

$reports = @()
$ignored = @()
foreach ($file in Get-ChildItem -LiteralPath $ReportDir -Filter "*.json" | Sort-Object Name) {
	if ($IgnoredReportNames -contains $file.Name) {
		$ignored += $file.Name
		continue
	}
	$json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
	$reports += [pscustomobject]@{
		File = $file
		Json = $json
	}
}

$rows = @()
$roleRates = @()
foreach ($report in $reports) {
	$j = $report.Json
	$identity = Get-OptionalProperty $j "assigned_identity" ([pscustomobject]@{})
	$approaches = Get-StringArray (Get-OptionalProperty $identity "approaches" @())
	$diagnostics = Get-OptionalProperty $j "diagnostics" ([pscustomobject]@{})
	$spans = @((Get-OptionalProperty $diagnostics "lower_level_fail_spans" @()))
	foreach ($span in $spans) {
		$label = [string](Get-OptionalProperty $span "label" "")
		$rows += [pscustomobject]@{
			unit = [string](Get-OptionalProperty $j "unit_id" "")
			role = [string](Get-OptionalProperty $identity "primary_role" "")
			goal = [string](Get-OptionalProperty $identity "primary_goal" "")
			approaches = ($approaches -join ",")
			cost = [int](Get-OptionalProperty $identity "cost" 0)
			block_type = [string](Get-OptionalProperty $span "block_type" "")
			block = [string](Get-OptionalProperty $span "block" "")
			metric_id = [string](Get-OptionalProperty $span "metric_id" "")
			label = $label
			value = Get-OptionalProperty $span "value" $null
			want = Get-OptionalProperty $span "want" $null
			reason = [string](Get-OptionalProperty $span "reason" "")
			subject_side = [string](Get-OptionalProperty $span "subject_side" "")
			topic = Get-SpanTopic $label
		}
	}
	$verdicts = Get-OptionalProperty $j "verdicts" $null
	$roles = Get-OptionalProperty $verdicts "roles" $null
	if ($roles) {
		foreach ($roleName in $roles.PSObject.Properties.Name) {
			$roleVerdict = $roles.$roleName
			$roleRates += [pscustomobject]@{
				unit = [string](Get-OptionalProperty $j "unit_id" "")
				role = [string]$roleName
				pass_rate = [double](Get-OptionalProperty $roleVerdict "pass_rate" 0.0)
				failed_span_count = [int](Get-OptionalProperty $roleVerdict "failed_span_count" 0)
			}
		}
	}
}

$unitsWithRows = @($rows | Select-Object -ExpandProperty unit -Unique | Sort-Object)
$allUnits = @($reports | ForEach-Object { [string](Get-OptionalProperty $_.Json "unit_id" "") } | Sort-Object)
$unitsWithoutRows = @($allUnits | Where-Object { $unitsWithRows -notcontains $_ })
$nonRampGoalRampCount = @($rows | Where-Object {
	$_.label -match '^goal_.*_ramp_' -and ($_.approaches -split ',') -notcontains 'ramp'
}).Count
$rampFailCount = @($rows | Where-Object { $_.label -match 'ramp' }).Count

if (-not (Test-Path -LiteralPath $OutputDir)) {
	New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

$csvPath = Join-Path $OutputDir "accepted_lower_level_fail_spans.csv"
$summaryPath = Join-Path $OutputDir "rga_accepted_misses_summary.json"
$readmePath = Join-Path $OutputDir "README.md"

$rows | Sort-Object unit, block_type, block, label | Export-Csv -LiteralPath $csvPath -NoTypeInformation

$summary = [ordered]@{
	generated_at = (Get-Date).ToUniversalTime().ToString("o")
	source_report_dir = (Resolve-Path -LiteralPath $ReportDir).Path
	current_report_count = $reports.Count
	ignored_reports = $ignored
	current_units = $allUnits
	lower_level_fail_spans = $rows.Count
	units_with_any_lower_level_fail = $unitsWithRows
	units_without_lower_level_fail = $unitsWithoutRows
	block_type_counts = Count-By $rows "block_type"
	primary_topic_counts = Count-By $rows "topic"
	keyword_bucket_counts = Count-KeywordBuckets $rows
	highest_unit_fail_counts = @($rows | Group-Object unit | Sort-Object -Property @{Expression="Count"; Descending=$true}, @{Expression="Name"; Descending=$false} | ForEach-Object {
		[ordered]@{ unit = $_.Name; count = $_.Count }
	})
	lowest_role_pass_rates = @($roleRates | Sort-Object pass_rate, unit | Select-Object -First 12)
	ramp_fail_spans = $rampFailCount
	non_ramp_goal_ramp_spans = $nonRampGoalRampCount
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath

$readme = @(
	"# RoleMatrix Accepted Misses - 2026-06-25",
	"",
	'This artifact is generated from `user://identity_reports/*.json`, not raw console output.',
	"",
	"- Current reports: $($reports.Count)",
	"- Ignored reports: $($ignored -join ', ')",
	"- Subject-side accepted lower-level fail spans: $($rows.Count)",
	"- Units with at least one span: $($unitsWithRows.Count)",
	"- Ramp spans: $rampFailCount",
	"- Non-ramp goal-ramp spans: $nonRampGoalRampCount",
	"",
	"Generated files:",
	'- `accepted_lower_level_fail_spans.csv`',
	'- `rga_accepted_misses_summary.json`',
	"",
	"Regenerate with:",
	"",
	'```powershell',
	'.\tests\rga_testing\tools\Export-AcceptedMisses.ps1',
	'```'
)
$readme | Set-Content -LiteralPath $readmePath

Write-Output ("accepted_misses_export reports={0} spans={1} ramp_spans={2} non_ramp_goal_ramp={3} out={4}" -f $reports.Count, $rows.Count, $rampFailCount, $nonRampGoalRampCount, $OutputDir)
