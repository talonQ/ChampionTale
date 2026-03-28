class_name CombatTurnOrderStrip
extends RefCounted
## 本回合行动顺序横条：圆形槽位 + 头像；当前行动者放大。
## 顺序与尺寸变化通过 Tween 平滑过渡：每个槽位单独插值横向位置（_x_start→_x_end）与缩放。


const ACTING_PORTRAIT_SCALE := 1.32

var _strip: Control
var _diameter: int
var _separation: float
var _anim_sec: float
var _slot_by_id: Dictionary = {}
var _active_tween: Tween


func _init(strip: Control, diameter: int = 44, separation: int = 8, anim_duration_sec: float = 0.38) -> void:
	_strip = strip
	_diameter = maxi(24, diameter)
	_separation = float(separation)
	_anim_sec = maxf(0.0, anim_duration_sec)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE


func sync(
	units: Array[BattleUnitRuntime],
	highlight: BattleUnitRuntime,
	portrait_getter: Callable,
) -> void:
	var want: Dictionary = {}
	for u in units:
		want[u.id] = true
	for id in _slot_by_id.keys():
		if not want.has(id):
			var dead: SlotEntry = _slot_by_id[id]
			_slot_by_id.erase(id)
			dead.root.queue_free()

	var any_new := false
	for u in units:
		if not _slot_by_id.has(u.id):
			_slot_by_id[u.id] = _create_slot(u, portrait_getter)
			_strip.add_child(_slot_by_id[u.id].root)
			any_new = true

	for u in units:
		var e: SlotEntry = _slot_by_id[u.id]
		_refresh_portrait(e, u, portrait_getter)
		_apply_slot_visual(e, u, highlight)

	var max_h := float(_diameter) * ACTING_PORTRAIT_SCALE

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null

	for u in units:
		var e: SlotEntry = _slot_by_id[u.id]
		e._ps_end = _panel_scale_for(u, highlight)
		var ps0 := e.panel.scale.x
		if ps0 <= 0.001:
			ps0 = e._ps_end
		e._ps_start = ps0
		e._x_start = e.root.position.x

	var x_acc := 0.0
	for u in units:
		var e: SlotEntry = _slot_by_id[u.id]
		e._x_end = x_acc
		var w_end := float(_diameter) * e._ps_end
		x_acc += w_end + _separation

	var instant := any_new or _anim_sec <= 0.0001

	if instant:
		_run_layout(1.0, units, max_h)
		return

	var tree := _strip.get_tree()
	if tree == null:
		_run_layout(1.0, units, max_h)
		return

	_run_layout(0.0, units, max_h)
	_active_tween = tree.create_tween()
	var tw := _active_tween.tween_method(
		func(alpha: float) -> void:
			_run_layout(alpha, units, max_h),
		0.0,
		1.0,
		_anim_sec,
	)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_OUT)


func _run_layout(alpha: float, units: Array[BattleUnitRuntime], max_h: float) -> void:
	var max_right := 0.0
	for u in units:
		var e: SlotEntry = _slot_by_id[u.id]
		var ps := lerpf(e._ps_start, e._ps_end, alpha)
		var w := float(_diameter) * ps
		var x := lerpf(e._x_start, e._x_end, alpha)
		var y := (max_h - w) * 0.5
		e.root.size = Vector2(w, w)
		e.root.position = Vector2(x, y)
		e.panel.scale = Vector2(ps, ps)
		e.panel.position = Vector2.ZERO
		max_right = maxf(max_right, x + w)
	_strip.custom_minimum_size = Vector2(max_right, max_h)


func _panel_scale_for(u: BattleUnitRuntime, highlight: BattleUnitRuntime) -> float:
	var current := (
		highlight != null
		and highlight.id == u.id
		and u.is_alive()
		and not u.acted_this_round
	)
	return ACTING_PORTRAIT_SCALE if current else 1.0


func _create_slot(u: BattleUnitRuntime, portrait_getter: Callable) -> SlotEntry:
	var e := SlotEntry.new()
	e.unit_id = u.id
	var ps := 1.0
	var w := float(_diameter) * ps
	e.root = Control.new()
	e.root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.root.clip_contents = true
	e.root.size = Vector2(w, w)
	e.panel = Panel.new()
	e.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.panel.custom_minimum_size = Vector2(_diameter, _diameter)
	e.panel.size = e.panel.custom_minimum_size
	e.panel.clip_contents = true
	e.style = StyleBoxFlat.new()
	e.style.set_corner_radius_all(max(1, _diameter >> 1))
	e.style.bg_color = _hash_color(u.id)
	e.style.set_border_width_all(1)
	e.style.border_color = Color(0.12, 0.14, 0.2, 0.9)
	e.panel.add_theme_stylebox_override(&"panel", e.style)
	e.tex_rect = TextureRect.new()
	e.tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.tex_rect.set_anchor(SIDE_LEFT, 0.0)
	e.tex_rect.set_anchor(SIDE_TOP, 0.0)
	e.tex_rect.set_anchor(SIDE_RIGHT, 1.0)
	e.tex_rect.set_anchor(SIDE_BOTTOM, 1.0)
	var inset := maxi(2, int(round(float(_diameter) / 14.0)))
	e.tex_rect.offset_left = inset
	e.tex_rect.offset_top = inset
	e.tex_rect.offset_right = -inset
	e.tex_rect.offset_bottom = -inset
	e.tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	e.tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	e.lbl = Label.new()
	e.lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	e.lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	e.lbl.set_anchor(SIDE_LEFT, 0.0)
	e.lbl.set_anchor(SIDE_TOP, 0.0)
	e.lbl.set_anchor(SIDE_RIGHT, 1.0)
	e.lbl.set_anchor(SIDE_BOTTOM, 1.0)
	e.lbl.add_theme_font_size_override(&"font_size", maxi(14, _diameter >> 1))
	e.lbl.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.92))
	e.lbl.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	e.lbl.add_theme_constant_override(&"shadow_offset_x", 1)
	e.lbl.add_theme_constant_override(&"shadow_offset_y", 1)
	e.panel.add_child(e.tex_rect)
	e.panel.add_child(e.lbl)
	e.root.add_child(e.panel)
	e.panel.scale = Vector2(ps, ps)
	_refresh_portrait(e, u, portrait_getter)
	return e


func _refresh_portrait(e: SlotEntry, u: BattleUnitRuntime, portrait_getter: Callable) -> void:
	e.lbl.text = _short_initial(u.display_name)
	var tex: Texture2D = null
	if portrait_getter.is_valid():
		var v: Variant = portrait_getter.call(u)
		if v is Texture2D:
			tex = v
	e.tex_rect.texture = tex
	e.tex_rect.visible = tex != null
	e.lbl.visible = tex == null


func _apply_slot_visual(e: SlotEntry, u: BattleUnitRuntime, highlight: BattleUnitRuntime) -> void:
	var is_current := (
		highlight != null
		and highlight.id == u.id
		and u.is_alive()
		and not u.acted_this_round
	)
	var dim := u.acted_this_round
	if is_current:
		e.style.set_border_width_all(3)
		e.style.border_color = Color(0.95, 0.82, 0.25, 1)
	else:
		e.style.set_border_width_all(1)
		e.style.border_color = Color(0.12, 0.14, 0.2, 0.9)
	e.panel.modulate = Color(0.52, 0.54, 0.6, 1) if dim else Color.WHITE


func _short_initial(display_name: String) -> String:
	var n := display_name.strip_edges()
	var p := n.find("·")
	if p != -1 and p + 1 < n.length():
		n = n.substr(p + 1).strip_edges()
	if n.is_empty():
		return "?"
	return n.substr(0, 1)


func _hash_color(unit_id: int) -> Color:
	var h := int(unit_id) * 2654435761
	var r := float((h >> 0) & 255) / 255.0 * 0.35 + 0.25
	var g := float((h >> 8) & 255) / 255.0 * 0.35 + 0.22
	var b := float((h >> 16) & 255) / 255.0 * 0.35 + 0.28
	return Color(r, g, b, 1)


class SlotEntry extends RefCounted:
	var unit_id: int
	var root: Control
	var panel: Panel
	var style: StyleBoxFlat
	var tex_rect: TextureRect
	var lbl: Label
	var _ps_start: float = 1.0
	var _ps_end: float = 1.0
	var _x_start: float = 0.0
	var _x_end: float = 0.0
