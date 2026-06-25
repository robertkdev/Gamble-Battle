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
	if ($text -match 'time_to_first_cc') {
		return "engage_cc_timing"
	}
	if ($text -match 'a_first_frac') {
		return "assassin_opening_presence"
	}
	if ($text -match 'team_fortification_buff_uptime') {
		return "team_fortification_buff_uptime"
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
	if ($text -match 'sustain(?!ed)|ehp_ratio') {
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

function Get-SupportPeelTriageGroup($Unit, $Label) {
	$topic = Get-SpanTopic $Label
	if ($topic -ne "support_peel_cleanse_cc") {
		return ""
	}
	$unitId = [string]$Unit
	switch ($unitId) {
		"axiom" { return "axiom_soft_peel_team_save_gap" }
		"paisley" { return "paisley_shield_peel_team_save_gap" }
		"totem" { return "totem_all_unit_scenario_threshold_gap" }
		"luna" { return "luna_wombo_cc_sync_gap" }
		"brute" { return "debuff_lockdown_counterplay_context_gap" }
		"grint" { return "debuff_lockdown_counterplay_context_gap" }
		"kythera" { return "debuff_lockdown_counterplay_context_gap" }
		"sari" { return "debuff_lockdown_counterplay_context_gap" }
		"volt" { return "debuff_lockdown_counterplay_context_gap" }
		default { return "support_peel_other" }
	}
}

function Get-SupportPeelGapKind($Label) {
	$text = [string]$Label
	if ($text -match 'debuff_cleanse|lockdown_cleanse|tenacity') {
		return "counterplay_context_absent"
	}
	if ($text -match 'cc_sync') {
		return "wombo_cc_sync_absent"
	}
	if ($text -match 'cooldown_trade_efficiency') {
		return "cooldown_trade_quality_below_target"
	}
	if ($text -match 'cc_prevented') {
		return "cc_prevention_context_absent"
	}
	if ($text -match 'interrupt_events') {
		return "peel_interrupt_context_absent"
	}
	if ($text -match 'peel_saves') {
		return "team_peel_save_metric_absent"
	}
	if ($text -match 'cc_immunity|cleanse') {
		return "hard_peel_submode_absent"
	}
	return ""
}

function Get-SupportPeelNextAction($GapKind) {
	switch ([string]$GapKind) {
		"counterplay_context_absent" { return "Add a cleanse/high-tenacity counterplay context, or retune the debuff/lockdown tag if that counterplay should not be required." }
		"wombo_cc_sync_absent" { return "Decide whether wombo requires direct CC-sync evidence or whether burst/AoE aggregate evidence is sufficient." }
		"cooldown_trade_quality_below_target" { return "Tune the threat-response setup or the cooldown-trade efficiency threshold for the all-unit support scenario." }
		"cc_prevention_context_absent" { return "Create an incoming-CC threat context that can prove subject CC prevention, or keep it as optional quality evidence." }
		"peel_interrupt_context_absent" { return "Create an interruptible carry-threat context so peel-carry can prove direct interrupt evidence." }
		"team_peel_save_metric_absent" { return "Create a live dive/carry-threat scenario that can trigger team peel-save attribution." }
		"hard_peel_submode_absent" { return "Confirm whether this identity should prove hard peel through cleanse/CC immunity, then retag or add/tune direct evidence." }
		default { return "" }
	}
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
		engage_cc_timing = 'time_to_first_cc'
		assassin_opening_presence = 'a_first_frac'
		team_fortification_buff_uptime = 'team_fortification_buff_uptime'
		ramp_state = 'ramp'
		sustain_survival = 'sustain(?!ed)|ehp_ratio'
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
		$unitId = [string](Get-OptionalProperty $j "unit_id" "")
		$gapKind = Get-SupportPeelGapKind $label
		$rows += [pscustomobject]@{
			unit = $unitId
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
			support_peel_triage = Get-SupportPeelTriageGroup $unitId $label
			support_peel_gap_kind = $gapKind
			support_peel_next_action = Get-SupportPeelNextAction $gapKind
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
$supportPeelRows = @($rows | Where-Object { [string]$_.support_peel_triage -ne "" })
$supportPeelTriageCounts = Count-By $supportPeelRows "support_peel_triage"
$supportPeelTriageSummary = ($supportPeelTriageCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$supportPeelGapKindCounts = Count-By $supportPeelRows "support_peel_gap_kind"
$supportPeelGapKindSummary = ($supportPeelGapKindCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$primaryTopicCounts = Count-By $rows "topic"
$primaryTopicSummary = ($primaryTopicCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
$keywordBucketCounts = Count-KeywordBuckets $rows

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
	primary_topic_counts = $primaryTopicCounts
	keyword_bucket_counts = $keywordBucketCounts
	support_peel_triage_counts = $supportPeelTriageCounts
	support_peel_gap_kind_counts = $supportPeelGapKindCounts
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
	"- Primary topic counts: $primaryTopicSummary",
	"- Support/peel triage: $supportPeelTriageSummary",
	"- Support/peel gap kinds: $supportPeelGapKindSummary",
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
