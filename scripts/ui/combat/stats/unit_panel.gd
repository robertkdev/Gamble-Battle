extends Control
class_name UnitPanel

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")

@onready var portrait: TextureRect = $"VBox/Header/Portrait"
@onready var name_label: Label = $"VBox/Header/Info/Name"
@onready var role_badge: Label = $"VBox/Header/Info/RoleBadge"
@onready var goal_label: Label = $"VBox/Header/Info/GoalLabel"
@onready var approach_tags: FlowContainer = $"VBox/Header/Info/ApproachTags"
@onready var traits_label: Label = $"VBox/Header/Info/TraitsLabel"
@onready var bars_box: VBoxContainer = $"VBox/Bars"
@onready var stats_grid: GridContainer = $"VBox/StatsGrid"
@onready var dps_label: Label = $"VBox/Footer/DPSLabel"
@onready var casts_label: Label = $"VBox/Footer/CastsLabel"
var _extra_labels_added: bool = false

var tracker: StatsTracker = null
var team: String = "player"
var index: int = -1
var unit_ref: Unit = null

var hp_bar: ProgressBar
var mana_bar: ProgressBar

func _ready() -> void:
    _ensure_bars()
    _ensure_identity_styles()
    set_process(true)

func configure(_tracker: StatsTracker) -> void:
    tracker = _tracker

func set_target(_team: String, _index: int, u: Unit) -> void:
    team = String(_team)
    index = int(_index)
    set_unit(u)

func set_unit(u: Unit) -> void:
    unit_ref = u
    _refresh_header()
    _refresh_bars()
    _build_stats_grid()

func _process(_delta: float) -> void:
    _refresh_dynamic()

func _refresh_dynamic() -> void:
    # Live DPS (3s) and casts
    var dps3: float = 0.0
    var casts: float = 0.0
    var hps3: float = 0.0
    var absorbed_total: float = 0.0
    var cc_inf: float = 0.0
    var cc_rec: float = 0.0
    var overheal: float = 0.0
    var kills: float = 0.0
    var deaths: float = 0.0
    var time_alive: float = 0.0
    var focus_pct: float = 0.0
    if tracker != null and index >= 0:
        dps3 = tracker.get_value(team, index, "dps", "3S")
        casts = tracker.get_value(team, index, "casts", "ALL")
        hps3 = tracker.get_value(team, index, "hps", "3S")
        absorbed_total = tracker.get_value(team, index, "absorbed", "ALL")
        cc_inf = tracker.get_value(team, index, "cc_inflicted", "ALL")
        cc_rec = tracker.get_value(team, index, "cc_received", "ALL")
        overheal = tracker.get_value(team, index, "overheal", "ALL")
        kills = tracker.get_value(team, index, "kills", "ALL")
        deaths = tracker.get_value(team, index, "deaths", "ALL")
        time_alive = tracker.get_value(team, index, "time", "ALL")
        focus_pct = tracker.get_value(team, index, "focus", "ALL")
    dps_label.text = "DPS (3s): " + _fmt(dps3)
    casts_label.text = "Casts: " + str(int(round(casts)))
    _ensure_extra_footer()
    var f: HBoxContainer = $"VBox/Footer"
    if f and f.get_child_count() >= 10:
        var hps_lbl: Label = f.get_child(2)
        var ab_lbl: Label = f.get_child(3)
        var cci_lbl: Label = f.get_child(4)
        var ccr_lbl: Label = f.get_child(5)
        var ovh_lbl: Label = f.get_child(6)
        var kil_lbl: Label = f.get_child(7)
        var ded_lbl: Label = f.get_child(8)
        var tim_lbl: Label = f.get_child(9)
        var foc_lbl: Label = f.get_child(10)
        if hps_lbl is Label:
            (hps_lbl as Label).text = "HPS (3s): " + _fmt(hps3)
        if ab_lbl is Label:
            (ab_lbl as Label).text = "Shield Abs: " + _fmt(absorbed_total)
        if cci_lbl is Label:
            (cci_lbl as Label).text = "CC Inf(s): " + String.num(cc_inf, 2)
        if ccr_lbl is Label:
            (ccr_lbl as Label).text = "CC Rec(s): " + String.num(cc_rec, 2)
        if ovh_lbl is Label:
            (ovh_lbl as Label).text = "Overheal: " + _fmt(overheal)
        if kil_lbl is Label:
            (kil_lbl as Label).text = "Kills: " + str(int(kills))
        if ded_lbl is Label:
            (ded_lbl as Label).text = "Deaths: " + str(int(deaths))
        if tim_lbl is Label:
            (tim_lbl as Label).text = "Time: " + String.num(time_alive, 1) + "s"
        if foc_lbl is Label:
            (foc_lbl as Label).text = "Focus: " + String.num(focus_pct, 0) + "%"
    # Bars track current unit stats
    _refresh_bars()

func _ensure_extra_footer() -> void:
    if _extra_labels_added:
        return
    var f: HBoxContainer = $"VBox/Footer"
    if f == null:
        return
    var hps_lbl := Label.new()
    hps_lbl.text = "HPS (3s): 0"
    f.add_child(hps_lbl)
    var ab_lbl := Label.new()
    ab_lbl.text = "Shield Abs: 0"
    f.add_child(ab_lbl)
    var cci_lbl := Label.new(); cci_lbl.text = "CC Inf(s): 0"; f.add_child(cci_lbl)
    var ccr_lbl := Label.new(); ccr_lbl.text = "CC Rec(s): 0"; f.add_child(ccr_lbl)
    var ovh_lbl := Label.new(); ovh_lbl.text = "Overheal: 0"; f.add_child(ovh_lbl)
    var kil_lbl := Label.new(); kil_lbl.text = "Kills: 0"; f.add_child(kil_lbl)
    var ded_lbl := Label.new(); ded_lbl.text = "Deaths: 0"; f.add_child(ded_lbl)
    var tim_lbl := Label.new(); tim_lbl.text = "Time: 0s"; f.add_child(tim_lbl)
    var foc_lbl := Label.new(); foc_lbl.text = "Focus: 0%"; f.add_child(foc_lbl)
    _extra_labels_added = true

func _ensure_bars() -> void:
    if hp_bar == null:
        hp_bar = UIBars.make_hp_bar()
        bars_box.add_child(hp_bar)
    if mana_bar == null:
        mana_bar = UIBars.make_mana_bar()
        bars_box.add_child(mana_bar)

func _ensure_identity_styles() -> void:
    if role_badge and not role_badge.has_theme_stylebox_override("normal"):
        role_badge.add_theme_stylebox_override("normal", _make_badge_style())

func _refresh_header() -> void:
    var tex: Texture2D = null
    if unit_ref != null and String(unit_ref.sprite_path) != "":
        tex = load(unit_ref.sprite_path)
    if tex == null:
        tex = TextureUtils.make_circle_texture(Color(0.7, 0.7, 0.9), 64)
    portrait.texture = tex
    name_label.text = (unit_ref.name if unit_ref != null else "Unit")

    var primary_role := ""
    var primary_goal := ""
    var approaches: Array = []
    var trait_text := ""
    if unit_ref != null:
        primary_role = String(unit_ref.get_primary_role())
        if primary_role == "" and unit_ref.roles.size() > 0:
            primary_role = String(unit_ref.roles[0])
        primary_goal = String(unit_ref.get_primary_goal())
        if primary_goal == "" and unit_ref.identity != null:
            primary_goal = String(unit_ref.identity.primary_goal)
        approaches = unit_ref.get_approaches()
        if approaches.is_empty() and unit_ref.identity != null:
            approaches = unit_ref.identity.approaches.duplicate()
        trait_text = ", ".join(unit_ref.traits)

    _set_role_badge(_format_role(primary_role))
    _set_goal_label(_format_goal(primary_goal))
    _set_approach_tags(approaches)
    _set_traits(trait_text)

func _set_role_badge(text: String) -> void:
    if role_badge == null:
        return
    var clean := String(text).strip_edges()
    role_badge.text = clean
    role_badge.visible = clean != ""

func _set_goal_label(text: String) -> void:
    if goal_label == null:
        return
    var clean := String(text).strip_edges()
    goal_label.text = clean
    goal_label.visible = clean != ""
    goal_label.tooltip_text = clean

func _set_traits(text: String) -> void:
    if traits_label == null:
        return
    var clean := String(text).strip_edges()
    if clean == "":
        traits_label.visible = false
        traits_label.text = ""
        traits_label.tooltip_text = ""
    else:
        traits_label.visible = true
        traits_label.text = "Traits: " + clean
        traits_label.tooltip_text = clean

func _set_approach_tags(approaches: Array) -> void:
    if approach_tags == null:
        return
    for child in approach_tags.get_children():
        child.queue_free()
    if approaches == null:
        approach_tags.visible = false
        return
    var seen: Dictionary = {}
    var shown := 0
    for raw in approaches:
        var label_text := _prettify_token(String(raw))
        if label_text == "" or seen.has(label_text):
            continue
        seen[label_text] = true
        var lbl := Label.new()
        lbl.text = label_text
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        lbl.modulate = Color(1, 1, 1, 0.92)
        lbl.add_theme_stylebox_override("normal", _make_tag_style())
        approach_tags.add_child(lbl)
        shown += 1
        if shown >= 5:
            break
    approach_tags.visible = shown > 0

func _refresh_bars() -> void:
    if unit_ref == null:
        if hp_bar:
            hp_bar.visible = false
        if mana_bar:
            mana_bar.visible = false
        return
    hp_bar.visible = true
    mana_bar.visible = true
    hp_bar.max_value = max(1, unit_ref.max_hp)
    hp_bar.value = clamp(unit_ref.hp, 0, unit_ref.max_hp)
    mana_bar.max_value = max(0, unit_ref.mana_max)
    mana_bar.value = clamp(unit_ref.mana, 0, unit_ref.mana_max)

func _clear_stats_grid() -> void:
    for child in stats_grid.get_children():
        stats_grid.remove_child(child)
        child.queue_free()

func _build_stats_grid() -> void:
    _clear_stats_grid()
    if unit_ref == null:
        return
    var entries := [
        ["HP", str(unit_ref.max_hp)],
        ["AD", _fmt(unit_ref.attack_damage)],
        ["SP", _fmt(unit_ref.spell_power)],
        ["AS", String.num(unit_ref.attack_speed, 2)],
        ["CRIT", str(int(round(unit_ref.crit_chance * 100.0))) + "%"],
        ["Range", str(unit_ref.attack_range)],
        ["Armor", _fmt(unit_ref.armor)],
        ["MR", _fmt(unit_ref.magic_resist)],
        ["Move", _fmt(unit_ref.move_speed)],
        ["Mana", str(unit_ref.mana_start) + "/" + str(unit_ref.mana_max)],
    ]
    for e in entries:
        var box := VBoxContainer.new()
        var icon := Label.new()
        icon.text = String(e[0])
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        var val := Label.new()
        val.text = String(e[1])
        val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        box.add_child(icon)
        box.add_child(val)
        stats_grid.add_child(box)

func _fmt(v) -> String:
    var f: float = 0.0
    if typeof(v) == TYPE_INT:
        f = float(v)
    elif typeof(v) == TYPE_FLOAT:
        f = float(v)
    else:
        return str(v)
    if f >= 1000000.0:
        return String.num(f/1000000.0, 1) + "m"
    if f >= 1000.0:
        return String.num(f/1000.0, 1) + "k"
    if abs(f - round(f)) < 0.0001:
        return str(int(round(f)))
    return String.num(f, 2)

func _format_role(role_id: String) -> String:
    var raw := String(role_id).strip_edges()
    if raw == "":
        return ""
    var parts := raw.to_lower().split("_", false)
    var pretty := PackedStringArray()
    for part in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    return " ".join(pretty)

func _format_goal(goal_id: String) -> String:
    var raw := String(goal_id).strip_edges()
    if raw == "":
        return ""
    var parts := raw.split(".", false, 2)
    if parts.size() >= 2:
        var role_part := _format_role(parts[0])
        var goal_part := _prettify_token(parts[1])
        if role_part != "":
            if goal_part != "":
                return "%s - %s" % [role_part, goal_part]
            return role_part
    return _prettify_token(raw)

func _prettify_token(value: String) -> String:
    var text := String(value).strip_edges().to_lower()
    if text == "":
        return ""
    var parts := text.split("_", false)
    var pretty := PackedStringArray()
    for part in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    return " ".join(pretty)

func _make_badge_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.121569, 0.211765, 0.266667, 0.95)
    sb.corner_radius_top_left = 7
    sb.corner_radius_top_right = 7
    sb.corner_radius_bottom_right = 7
    sb.corner_radius_bottom_left = 7
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    return sb

func _make_tag_style() -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.0941177, 0.137255, 0.211765, 0.95)
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_right = 6
    sb.corner_radius_bottom_left = 6
    sb.content_margin_left = 6
    sb.content_margin_right = 6
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    return sb
