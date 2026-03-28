class_name CombatUnitBarsController
extends RefCounted
## 头顶双进度条：创建、样式、跟随相机、数值过渡（SmoothDualStatBars）。


const _SMOOTH_DUAL_BARS := preload("res://components/smooth_dual_stat_bars.gd")

var bar_offset_world_y: float = 2.15
var tween_duration_sec: float = 0.45
## 头顶条整体面板最小尺寸（像素）。
var panel_min_size: Vector2 = Vector2(108, 44)
## 血条、专注条各自的最小宽高（像素）。
var hp_bar_min_size: Vector2 = Vector2(100, 12)
var focus_bar_min_size: Vector2 = Vector2(100, 10)
## 两条之间的垂直间距（主题常量 separation）。
var bars_vertical_separation: int = 3
## 条中心对齐到单位头顶投影后，再向上偏移的屏幕像素（越大条离角色越远）。
var screen_anchor_margin_px: float = 4.0

var _root: Control
var _camera: Camera3D
## unit_id -> { "root": Control, "hp": ProgressBar, "focus": ProgressBar, "smooth": RefCounted }
var _widgets: Dictionary = {}


func _init(bars_root: Control, camera: Camera3D) -> void:
	_root = bars_root
	_camera = camera


func clear_and_rebuild(units: Array[BattleUnitRuntime]) -> void:
	for c in _root.get_children():
		c.queue_free()
	_widgets.clear()
	for u in units:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = panel_min_size
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", bars_vertical_separation)
		var hp := ProgressBar.new()
		hp.min_value = 0.0
		hp.max_value = 100.0
		hp.show_percentage = false
		hp.custom_minimum_size = hp_bar_min_size
		_style_bar_fill(hp, Color(0.22, 0.82, 0.38), Color(0.08, 0.14, 0.09))
		var fo := ProgressBar.new()
		fo.min_value = 0.0
		fo.max_value = 100.0
		fo.show_percentage = false
		fo.custom_minimum_size = focus_bar_min_size
		_style_bar_fill(fo, Color(0.32, 0.58, 0.98), Color(0.07, 0.1, 0.16))
		v.add_child(hp)
		v.add_child(fo)
		panel.add_child(v)
		_root.add_child(panel)
		var smooth: RefCounted = _SMOOTH_DUAL_BARS.new(panel, hp, fo)
		_widgets[u.id] = {"root": panel, "hp": hp, "focus": fo, "smooth": smooth}
		sync_unit_values(u)


func sync_unit_values(u: BattleUnitRuntime) -> void:
	var w: Variant = _widgets.get(u.id)
	if w == null:
		return
	var hp_pct := 0.0
	var fo_pct := 0.0
	if u.hp_max > 0:
		hp_pct = 100.0 * float(u.hp) / float(u.hp_max)
	if u.focus_max > 0:
		fo_pct = 100.0 * float(u.focus) / float(u.focus_max)
	var smooth: Variant = w.get("smooth", null)
	if smooth != null and smooth.has_method("tween_to"):
		smooth.tween_to(hp_pct, fo_pct, tween_duration_sec)
	else:
		(w["hp"] as ProgressBar).value = hp_pct
		(w["focus"] as ProgressBar).value = fo_pct


func sync_all_units(units: Array[BattleUnitRuntime]) -> void:
	for u in units:
		sync_unit_values(u)


func update_screen_positions(units: Array[BattleUnitRuntime], slots_by_unit_id: Dictionary) -> void:
	var cam := _camera
	if cam == null:
		return
	for u in units:
		var w: Variant = _widgets.get(u.id)
		if w == null:
			continue
		var panel_root: Control = w["root"]
		var slot: Variant = slots_by_unit_id.get(u.id)
		if slot == null:
			panel_root.visible = false
			continue
		if not u.is_alive():
			panel_root.visible = false
			continue
		var world: Vector3 = (slot as Node3D).global_position + Vector3(0, bar_offset_world_y, 0)
		if cam.is_position_behind(world):
			panel_root.visible = false
			continue
		var sp: Vector2 = cam.unproject_position(world)
		panel_root.visible = true
		panel_root.reset_size()
		var sz: Vector2 = panel_root.size
		panel_root.position = Vector2(sp.x - sz.x * 0.5, sp.y - sz.y - screen_anchor_margin_px)


func _style_bar_fill(bar: ProgressBar, fill_color: Color, track_color: Color) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = track_color
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"background", track)
	bar.add_theme_stylebox_override(&"fill", fill)
