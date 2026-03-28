class_name CombatUnitBarsController
extends RefCounted
## 头顶双进度条：创建、样式、跟随相机、数值过渡（SmoothDualStatBars）。


const _SMOOTH_DUAL_BARS := preload("res://components/smooth_dual_stat_bars.gd")

var bar_offset_world_y: float = 2.15
var tween_duration_sec: float = 0.45
## 条组最小尺寸下限（像素）；实际宽度/高度会与两条 ProgressBar + 间距取较大值，避免外框 Panel 时仍可撑开布局。
var panel_min_size: Vector2 = Vector2(100, 0)
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
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", bars_vertical_separation)
		var inner_w := maxf(hp_bar_min_size.x, focus_bar_min_size.x)
		var inner_h := hp_bar_min_size.y + float(bars_vertical_separation) + focus_bar_min_size.y
		v.custom_minimum_size = Vector2(
			maxf(panel_min_size.x, inner_w),
			maxf(panel_min_size.y, inner_h),
		)
		var hp := ProgressBar.new()
		hp.min_value = 0.0
		hp.max_value = 100.0
		hp.show_percentage = false
		hp.custom_minimum_size = hp_bar_min_size
		hp.theme_type_variation = &"CombatHpBar"
		var fo := ProgressBar.new()
		fo.min_value = 0.0
		fo.max_value = 100.0
		fo.show_percentage = false
		fo.custom_minimum_size = focus_bar_min_size
		fo.theme_type_variation = &"CombatFocusBar"
		v.add_child(hp)
		v.add_child(fo)
		_root.add_child(v)
		var smooth: RefCounted = _SMOOTH_DUAL_BARS.new(v, hp, fo)
		_widgets[u.id] = {"root": v, "hp": hp, "focus": fo, "smooth": smooth}
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
