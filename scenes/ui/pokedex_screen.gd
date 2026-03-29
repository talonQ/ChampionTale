extends Control
## 图鉴：左侧单位头像网格，右上种族值/特性，中上 3D 预览，下为技能列表与详情（见 `docs/pokedex.md`）。

const _BattleUiTheme := preload("res://ui/themes/champion_battle_theme.gd")
const _PokedexVisualCatalog := preload("res://components/pokedex_visual_catalog.gd")
const _CreatureAnimationDriver := preload("res://components/creature_animation_driver.gd")
const SCENE_MAIN := "res://scenes/ui/main_menu.tscn"
const _UNITS_DIR := "res://battle/definitions/units/"
## 显式 preload，保证导出包收录单位定义；导出后 `DirAccess` 枚举 `res://` 子目录常不可靠，不能单靠扫描。
const _UNIT_DEFINITION_PRELOADS: Array[BattleUnitDefinition] = [
	preload("res://battle/definitions/units/khazix.tres"),
	preload("res://battle/definitions/units/malphite.tres"),
	preload("res://battle/definitions/units/hecarim.tres"),
	preload("res://battle/definitions/units/fizz.tres"),
	preload("res://battle/definitions/units/renekton.tres"),
	preload("res://battle/definitions/units/trundle.tres"),
	preload("res://battle/definitions/units/volibear.tres"),
	preload("res://battle/definitions/units/wukong.tres"),
]

@export_group("3D 预览（等距感）")
## 相对水平面的俯角（越大越「俯视」）；约 45° 接近常见等距观感。
@export_range(20.0, 70.0, 1.0, "suffix:°") var preview_camera_elevation_deg: float = 45.0
## 在水平面上绕目标的方位角；约 45° 为斜向一角。
@export_range(0.0, 90.0, 1.0, "suffix:°") var preview_camera_orbit_yaw_deg: float = 45.0
## 与模型包围球半径相乘得到相机距离。
@export_range(1.2, 5.0, 0.05) var preview_camera_distance_scale: float = 2.75
@export_range(0.15, 2.5, 0.05, "suffix:m") var preview_camera_min_distance: float = 0.85
## 绕模型竖轴（Y）公转角速度；0 表示不自动旋转。
@export_range(-60.0, 60.0, 0.5, "suffix:°/s") var preview_camera_orbit_speed_deg_per_sec: float = 14.0

@export_group("图鉴分栏（比例 + 下限像素）")
## 主横条：左侧列表占主分割区宽度的比例。
@export_range(0.22, 0.42, 0.01) var layout_main_left_fraction: float = 0.30
@export_range(200, 420, 1) var layout_main_left_min_px: int = 288
## 右侧整体允许的最小宽度（用于钳制左列勿挤爆右栏）。
@export_range(480, 1200, 1) var layout_main_right_min_px: int = 620
## 右半：上排（2+3 区）占右半高度的比例。
@export_range(0.42, 0.65, 0.01) var layout_right_top_fraction: float = 0.54
@export_range(220, 520, 1) var layout_right_top_min_px: int = 300
@export_range(200, 480, 1) var layout_right_bottom_min_px: int = 260
## 上排横条：3D 预览（2 区）占上排宽度的比例。
@export_range(0.42, 0.62, 0.01) var layout_top_preview_fraction: float = 0.52
@export_range(260, 520, 1) var layout_preview_zone_min_width_px: int = 320
@export_range(220, 420, 1) var layout_stats_zone_min_width_px: int = 268
## 下排横条：技能列表（4 区）占下排宽度的比例。
@export_range(0.30, 0.55, 0.01) var layout_bottom_skills_fraction: float = 0.40
@export_range(180, 400, 1) var layout_skills_zone_min_width_px: int = 240
@export_range(240, 560, 1) var layout_detail_zone_min_width_px: int = 300
## 2 区 Viewport 纹理像素（越大越清晰，略增 GPU 负担）。
@export_range(256, 1024, 32) var layout_preview_viewport_pixels: int = 512
## 2 区面板最小高度（与 SubViewportContainer 一致）。
@export_range(200, 480, 1) var layout_preview_zone_min_height_px: int = 280

@onready var _btn_back: Button = %BtnBack
@onready var _unit_grid: GridContainer = %UnitGrid
@onready var _main_hsplit: HSplitContainer = %MainHSplit
@onready var _right_vsplit: VSplitContainer = %RightSplit
@onready var _top_row: HSplitContainer = %TopRow
@onready var _bottom_row: HSplitContainer = %BottomRow
@onready var _unit_scroll: ScrollContainer = %UnitScroll
@onready var _preview_subvpc: SubViewportContainer = %PreviewSubViewportContainer
@onready var _preview_viewport: SubViewport = %PreviewSubViewport
@onready var _preview_model_root: Node3D = %PreviewModelRoot
@onready var _preview_camera: Camera3D = %PreviewCamera
@onready var _preview_light: DirectionalLight3D = %PreviewLight
@onready var _stats_panel: PanelContainer = %StatsPanel
@onready var _skills_panel: PanelContainer = %SkillsPanel
@onready var _detail_panel: PanelContainer = %DetailPanel
@onready var _stats_rich: RichTextLabel = %StatsRichText
@onready var _skill_list: ItemList = %SkillList
@onready var _skill_detail: Label = %SkillDetailLabel

var _scene_transition: ChampionSceneTransition
var _unit_pick_group := ButtonGroup.new()
var _units: Array[BattleUnitDefinition] = []
## 与 `_skill_list` 行一一对应。
var _skills_shown: Array[SkillData] = []
## 预览公转：由 `_fit_preview_camera_to_aabb` 写入，`_process` 中更新相机。
var _preview_orbit_active: bool = false
var _orbit_center: Vector3 = Vector3.ZERO
var _orbit_look_bias: Vector3 = Vector3.ZERO
var _orbit_dist: float = 1.0
var _orbit_elev_rad: float = 0.0
var _orbit_base_yaw_rad: float = 0.0
var _orbit_yaw_offset_rad: float = 0.0


func _ready() -> void:
	theme = _BattleUiTheme.build()
	_scene_transition = get_tree().root.get_node_or_null("SceneTransition") as ChampionSceneTransition
	_btn_back.pressed.connect(_on_back_pressed)
	_skill_list.item_selected.connect(_on_skill_item_selected)
	get_viewport().size_changed.connect(_request_apply_pokedex_layout)
	_stats_rich.bbcode_enabled = true
	_stats_rich.fit_content = false
	_stats_rich.scroll_active = true
	_skill_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_detail.text = ""
	_load_and_sort_units()
	_populate_unit_buttons()
	if _unit_grid.get_child_count() > 0:
		(_unit_grid.get_child(0) as Button).button_pressed = true
	await get_tree().process_frame
	_apply_pokedex_layout()


func _process(delta: float) -> void:
	if not _preview_orbit_active or not is_visible_in_tree():
		return
	_orbit_yaw_offset_rad += deg_to_rad(preview_camera_orbit_speed_deg_per_sec) * delta
	_update_preview_orbit_camera()


func _request_apply_pokedex_layout() -> void:
	call_deferred(&"_apply_pokedex_layout")


func _apply_pokedex_layout() -> void:
	if not is_inside_tree():
		return
	_unit_scroll.custom_minimum_size.x = float(layout_main_left_min_px)
	_preview_subvpc.custom_minimum_size = Vector2(
		float(layout_preview_zone_min_width_px),
		float(layout_preview_zone_min_height_px)
	)
	_stats_panel.custom_minimum_size.x = float(layout_stats_zone_min_width_px)
	_skills_panel.custom_minimum_size.x = float(layout_skills_zone_min_width_px)
	_detail_panel.custom_minimum_size.x = float(layout_detail_zone_min_width_px)
	_top_row.custom_minimum_size.y = float(layout_right_top_min_px)
	_bottom_row.custom_minimum_size.y = float(layout_right_bottom_min_px)
	var px := maxi(256, layout_preview_viewport_pixels)
	_preview_viewport.size = Vector2i(px, px)

	var mw := int(_main_hsplit.size.x)
	if mw > 80:
		var max_left := mw - layout_main_right_min_px
		var want_left := int(float(mw) * layout_main_left_fraction)
		want_left = clampi(want_left, layout_main_left_min_px, maxi(layout_main_left_min_px, max_left))
		_main_hsplit.split_offset = want_left

	var rh := int(_right_vsplit.size.y)
	if rh > 80:
		var max_top := rh - layout_right_bottom_min_px
		var want_top := int(float(rh) * layout_right_top_fraction)
		want_top = clampi(want_top, layout_right_top_min_px, maxi(layout_right_top_min_px, max_top))
		_right_vsplit.split_offset = want_top

	var tw := int(_top_row.size.x)
	if tw > 80:
		var max_prev := tw - layout_stats_zone_min_width_px
		var want_prev := int(float(tw) * layout_top_preview_fraction)
		want_prev = clampi(want_prev, layout_preview_zone_min_width_px, maxi(layout_preview_zone_min_width_px, max_prev))
		_top_row.split_offset = want_prev

	var bw := int(_bottom_row.size.x)
	if bw > 80:
		var max_sk := bw - layout_detail_zone_min_width_px
		var want_sk := int(float(bw) * layout_bottom_skills_fraction)
		want_sk = clampi(want_sk, layout_skills_zone_min_width_px, maxi(layout_skills_zone_min_width_px, max_sk))
		_bottom_row.split_offset = want_sk


func _load_and_sort_units() -> void:
	_units.clear()
	var seen: Dictionary = {}
	for def in _UNIT_DEFINITION_PRELOADS:
		if def == null:
			continue
		var rp := (def as Resource).resource_path
		if not rp.is_empty():
			if seen.has(rp):
				continue
			seen[rp] = true
		_units.append(def)
	var dir := DirAccess.open(_UNITS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if not dir.current_is_dir() and entry.ends_with(".tres"):
				var path := _UNITS_DIR + entry
				if seen.has(path):
					entry = dir.get_next()
					continue
				if ResourceLoader.exists(path):
					var res: Resource = load(path)
					if res is BattleUnitDefinition:
						seen[path] = true
						_units.append(res as BattleUnitDefinition)
			entry = dir.get_next()
		dir.list_dir_end()
	elif _units.is_empty():
		push_warning("Pokedex: cannot open units dir (且无 preload 条目): %s" % _UNITS_DIR)
	_units.sort_custom(_compare_unit_defs)


static func _compare_unit_defs(a: BattleUnitDefinition, b: BattleUnitDefinition) -> bool:
	var na := a.display_name
	var nb := b.display_name
	if na != nb:
		return na < nb
	if a.unit_id != b.unit_id:
		return a.unit_id < b.unit_id
	var pa := (a as Resource).resource_path
	var pb := (b as Resource).resource_path
	return pa < pb


func _populate_unit_buttons() -> void:
	for c in _unit_grid.get_children():
		c.queue_free()
	for def in _units:
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = _unit_pick_group
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(76, 76)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		var vid := _PokedexVisualCatalog.visual_lookup_id(def)
		var tex := _PokedexVisualCatalog.portrait_texture(vid)
		if tex != null:
			btn.icon = tex
		else:
			btn.text = def.display_name.substr(0, 1) if def.display_name.length() > 0 else "?"
		btn.tooltip_text = def.display_name
		btn.toggled.connect(_on_unit_button_toggled.bind(def))
		_unit_grid.add_child(btn)


func _on_unit_button_toggled(pressed_on: bool, def: BattleUnitDefinition) -> void:
	## `bind(def)` 接在信号参数之后：先 `toggled(pressed)`，再绑定的 `def`。
	if pressed_on:
		_select_unit(def)


func _select_unit(def: BattleUnitDefinition) -> void:
	_refresh_preview_3d(def)
	_refresh_stats(def)
	_refresh_skill_list(def)
	_skill_list.deselect_all()
	_skill_detail.text = ""


func _refresh_preview_3d(def: BattleUnitDefinition) -> void:
	_preview_orbit_active = false
	set_process(false)
	for c in _preview_model_root.get_children():
		c.queue_free()
	var vid := _PokedexVisualCatalog.visual_lookup_id(def)
	var sc := _PokedexVisualCatalog.avatar_scene(vid)
	if sc == null:
		return
	var inst := sc.instantiate() as Node3D
	if inst == null:
		return
	_preview_model_root.add_child(inst)
	_ensure_creature_idle_driver(inst)
	_fit_preview_camera_to_aabb.call_deferred()


func _ensure_creature_idle_driver(avatar_root: Node3D) -> void:
	var existing := avatar_root.find_child("CreatureAnimationDriver", true, false)
	if existing != null and existing.get_script() == _CreatureAnimationDriver:
		return
	var driver: Node = _CreatureAnimationDriver.new()
	driver.name = "CreatureAnimationDriver"
	avatar_root.add_child(driver)


func _fit_preview_camera_to_aabb() -> void:
	var min_c := Vector3(INF, INF, INF)
	var max_c := Vector3(-INF, -INF, -INF)
	var found := false
	for n in _preview_model_root.find_children("*", "MeshInstance3D", true, false):
		var mm := n as MeshInstance3D
		var ab := mm.get_aabb()
		var xf := mm.global_transform
		for sx in [0.0, 1.0]:
			for sy in [0.0, 1.0]:
				for sz in [0.0, 1.0]:
					var lp := ab.position + Vector3(ab.size.x * sx, ab.size.y * sy, ab.size.z * sz)
					var wp: Vector3 = xf * lp
					found = true
					min_c = min_c.min(wp)
					max_c = max_c.max(wp)
	var center := Vector3.ZERO
	var ext := 0.35
	if found:
		center = (min_c + max_c) * 0.5
		ext = maxf((max_c - min_c).length() * 0.5, 0.08)
	var elev := deg_to_rad(preview_camera_elevation_deg)
	var dist := maxf(ext * preview_camera_distance_scale, preview_camera_min_distance)
	_orbit_center = center
	_orbit_look_bias = Vector3(0.0, ext * 0.08, 0.0)
	_orbit_dist = dist
	_orbit_elev_rad = elev
	_orbit_base_yaw_rad = deg_to_rad(preview_camera_orbit_yaw_deg)
	_orbit_yaw_offset_rad = 0.0
	_preview_orbit_active = _preview_model_root.get_child_count() > 0
	_update_preview_orbit_camera()
	set_process(_preview_orbit_active and absf(preview_camera_orbit_speed_deg_per_sec) > 0.001)
	# 动画驱动在下一帧已就绪时再保证 Idle 循环（与战斗槽一致）。
	var root := _preview_model_root.get_child(0) as Node3D
	if root != null:
		var drv := root.find_child("CreatureAnimationDriver", true, false)
		if drv != null and drv.has_method(&"play_idle"):
			drv.call_deferred(&"play_idle")


func _update_preview_orbit_camera() -> void:
	var yaw := _orbit_base_yaw_rad + _orbit_yaw_offset_rad
	var horiz := cos(_orbit_elev_rad) * _orbit_dist
	var off := Vector3(horiz * sin(yaw), sin(_orbit_elev_rad) * _orbit_dist, horiz * cos(yaw))
	var cam_pos := _orbit_center + off
	_preview_camera.position = cam_pos
	_preview_camera.look_at(_orbit_center + _orbit_look_bias, Vector3.UP)
	_align_preview_light_iso(_orbit_center, cam_pos)


func _align_preview_light_iso(_focus: Vector3, _camera_pos: Vector3) -> void:
	## 平行光仅使用朝向：与相机同向略偏转，模拟等距里常见的斜顶光。
	_preview_light.global_position = Vector3.ZERO
	_preview_light.global_transform.basis = _preview_camera.global_transform.basis
	_preview_light.rotate_object_local(Vector3.UP, deg_to_rad(-32.0))


static func _effective_spatk(def: BattleUnitDefinition) -> int:
	return def.spatk_base if def.spatk_base >= 0 else def.atk_base


static func _effective_spdef(def: BattleUnitDefinition) -> int:
	return def.spdef_base if def.spdef_base >= 0 else def.def_base


func _refresh_stats(def: BattleUnitDefinition) -> void:
	var sp_atk := _effective_spatk(def)
	var sp_def := _effective_spdef(def)
	var lines: PackedStringArray = []
	lines.append("[b]种族值[/b]\n")
	lines.append("HP　　%d\n" % def.hp_max)
	lines.append("攻击　%d\n" % def.atk_base)
	lines.append("防御　%d\n" % def.def_base)
	lines.append("特攻　%d\n" % sp_atk)
	lines.append("特防　%d\n" % sp_def)
	lines.append("速度　%d\n" % def.spd_base)
	lines.append("\n[b]特性[/b]\n")
	if def.traits.is_empty():
		lines.append("—")
	else:
		for t in def.traits:
			if t == null:
				continue
			lines.append("\n[color=#a8d4f0]%s[/color]\n" % t.display_name)
			var desc := t.description.strip_edges()
			if desc.length() > 0:
				lines.append(desc + "\n")
	_stats_rich.text = "".join(lines)


func _learnable_skills(def: BattleUnitDefinition) -> Array[SkillData]:
	var out: Array[SkillData] = []
	if def.learnable_skills.size() > 0:
		for s in def.learnable_skills:
			if s != null:
				out.append(s)
	else:
		for s in def.skills:
			if s != null:
				out.append(s)
	return out


func _refresh_skill_list(def: BattleUnitDefinition) -> void:
	_skill_list.clear()
	_skills_shown.clear()
	for s in _learnable_skills(def):
		_skills_shown.append(s)
		_skill_list.add_item(s.display_name)


func _on_skill_item_selected(index: int) -> void:
	if index < 0 or index >= _skills_shown.size():
		_skill_detail.text = ""
		return
	var sk: SkillData = _skills_shown[index]
	var hit_pct := int(round(clampf(sk.hit_chance, 0.0, 1.0) * 100.0))
	var desc := sk.description.strip_edges()
	_skill_detail.text = "名称：%s\n威力：%d\n命中：%d%%\n效果：%s" % [sk.display_name, sk.power, hit_pct, desc]


func _on_back_pressed() -> void:
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_MAIN)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN)
