extends RefCounted
class_name BalanceRunnerCSVReader

# Reads BalanceRunner identity_v2 CSV output into an array of Dictionaries.
# Header-driven: supports optional ability metric columns if present.

static func read_rows(path: String) -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    var fa := FileAccess.open(path, FileAccess.READ)
    if fa == null:
        push_warning("BRCSVReader: cannot open " + path)
        return rows
    if fa.eof_reached():
        return rows
    var header_line := fa.get_line()
    if header_line == null:
        return rows
    header_line = String(header_line).lstrip("\ufeff").strip_edges()
    if header_line == "":
        return rows
    var headers: PackedStringArray = _split_csv(header_line)
    while not fa.eof_reached():
        var line := String(fa.get_line())
        if line.strip_edges() == "":
            continue
        var cols: PackedStringArray = _split_csv(line)
        if cols.size() < headers.size():
            # Skip malformed/short lines
            continue
        var row := _parse_row(headers, cols)
        if row.size() > 0:
            rows.append(row)
    fa.close()
    return rows

static func _split_csv(s: String) -> PackedStringArray:
    # Identity_v2 uses simple comma separation with no quoted commas.
    var parts := PackedStringArray()
    for p in s.split(","):
        parts.append(String(p))
    return parts

static func _parse_row(headers: PackedStringArray, cols: PackedStringArray) -> Dictionary:
    var out := {}
    for i in range(headers.size()):
        var key := String(headers[i])
        var raw := (String(cols[i]) if i < cols.size() else "")
        out[key] = _coerce(key, raw)
    return out

static func _coerce(key: String, raw: String):
    var v := raw.strip_edges()
    # Map numeric columns to int/float; fall back to string.
    if _is_int_key(key):
        if v.is_valid_int():
            return int(v)
        # Some int fields may be formatted as floats (e.g., "12.0"). Try float->int.
        if v.is_valid_float():
            return int(round(float(v)))
        return 0
    if _is_float_key(key):
        if v.is_valid_float():
            return float(v)
        if v.is_valid_int():
            return float(int(v))
        return 0.0
    return v

static func _is_int_key(k: String) -> bool:
    var ints := {
        "attacker_cost": true, "defender_cost": true,
        "attacker_level": true, "defender_level": true,
        "attacker_avg_remaining_hp": true, "defender_avg_remaining_hp": true,
        "matches_total": true, "hit_events_total": true,
        "attacker_hit_events": true, "defender_hit_events": true,
        "attacker_healing_total": true, "defender_healing_total": true,
        "attacker_shield_absorbed_total": true, "defender_shield_absorbed_total": true,
        "attacker_damage_mitigated_total": true, "defender_damage_mitigated_total": true,
        "attacker_overkill_total": true, "defender_overkill_total": true,
        "attacker_damage_physical_total": true, "defender_damage_physical_total": true,
        "attacker_damage_magic_total": true, "defender_damage_magic_total": true,
        "attacker_damage_true_total": true, "defender_damage_true_total": true
    }
    return ints.has(k)

static func _is_float_key(k: String) -> bool:
    var floats := {
        "attacker_win_pct": true, "defender_win_pct": true, "draw_pct": true,
        "attacker_avg_time_to_win_s": true, "defender_avg_time_to_win_s": true,
        "attacker_avg_damage_dealt_per_match": true, "defender_avg_damage_dealt_per_match": true,
        "attacker_time_to_first_hit_s": true, "defender_time_to_first_hit_s": true,
        # Optional ability metrics columns
        "attacker_avg_casts_per_match": true, "defender_avg_casts_per_match": true,
        "attacker_first_cast_time_s": true, "defender_first_cast_time_s": true
    }
    return floats.has(k)

