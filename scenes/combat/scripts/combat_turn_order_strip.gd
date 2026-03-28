class_name CombatTurnOrderStrip
extends RefCounted
## 本回合行动顺序横条：圆形槽位 + 头像/占位字；已出手略暗，当前行动者描边高亮。
## 轮到且尚未出手时，整格在**保持原有绘制比例**的前提下放大（仅 scale，不改圆角/内边距公式）。


const ACTING_PORTRAIT_SCALE := 1.32

var _row: HBoxContainer
var _diameter: int


func _init(row: HBoxContainer, diameter: int = 44, separation: int = 8) -> void:
	_row = row
	_diameter = maxi(24, diameter)
	_row.add_theme_constant_override("separation", separation)


func sync(
	units: Array[BattleUnitRuntime],
	highlight: BattleUnitRuntime,
	portrait_getter: Callable,
) -> void:
	while _row.get_child_count() > 0:
		_row.get_child(0).free()
	for u in units:
		_row.add_child(_make_slot(u, highlight, portrait_getter))


func _make_slot(
	u: BattleUnitRuntime,
	highlight: BattleUnitRuntime,
	portrait_getter: Callable,
) -> Control:
	var is_current := (
		highlight != null
		and highlight.id == u.id
		and u.is_alive()
		and not u.acted_this_round
	)
	var dim := u.acted_this_round
	var tex: Texture2D = null
	if portrait_getter.is_valid():
		var v: Variant = portrait_getter.call(u)
		if v is Texture2D:
			tex = v
	var initial := _short_initial(u.display_name)
	var bg := _hash_color(u.id)

	var scale_acting := ACTING_PORTRAIT_SCALE if is_current else 1.0
	var outer := int(round(float(_diameter) * scale_acting))
	var root := Control.new()
	root.custom_minimum_size = Vector2(outer, outer)
	root.clip_contents = true

	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(_diameter, _diameter)
	panel.size = panel.custom_minimum_size
	panel.clip_contents = true
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(max(1, _diameter >> 1))
	sb.bg_color = bg
	if is_current:
		sb.set_border_width_all(3)
		sb.border_color = Color(0.95, 0.82, 0.25, 1)
	else:
		sb.set_border_width_all(1)
		sb.border_color = Color(0.12, 0.14, 0.2, 0.9)
	panel.add_theme_stylebox_override(&"panel", sb)
	panel.modulate = Color(0.52, 0.54, 0.6, 1) if dim else Color.WHITE
	var inset := maxi(2, int(round(float(_diameter) / 14.0)))
	var tex_rect := TextureRect.new()
	tex_rect.set_anchor(SIDE_LEFT, 0.0)
	tex_rect.set_anchor(SIDE_TOP, 0.0)
	tex_rect.set_anchor(SIDE_RIGHT, 1.0)
	tex_rect.set_anchor(SIDE_BOTTOM, 1.0)
	tex_rect.offset_left = inset
	tex_rect.offset_top = inset
	tex_rect.offset_right = -inset
	tex_rect.offset_bottom = -inset
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.texture = tex
	tex_rect.visible = tex != null
	panel.add_child(tex_rect)
	var lbl := Label.new()
	lbl.text = initial
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchor(SIDE_LEFT, 0.0)
	lbl.set_anchor(SIDE_TOP, 0.0)
	lbl.set_anchor(SIDE_RIGHT, 1.0)
	lbl.set_anchor(SIDE_BOTTOM, 1.0)
	lbl.add_theme_font_size_override(&"font_size", maxi(14, _diameter >> 1))
	lbl.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.92))
	lbl.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override(&"shadow_offset_x", 1)
	lbl.add_theme_constant_override(&"shadow_offset_y", 1)
	lbl.visible = tex == null
	panel.add_child(lbl)

	root.add_child(panel)
	var vis := float(_diameter) * scale_acting
	var pad := (float(outer) - vis) * 0.5
	panel.scale = Vector2(scale_acting, scale_acting)
	panel.position = Vector2(pad, pad)
	return root


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
