extends RefCounted
## 战斗 HUD 全局主题：冷色战场底 + 青蓝描边 + 翠绿按压反馈，与场景环境光 / 描边管线一致。
## 通过 `build()` 得到 `Theme`，赋给多个 `Control` 根节点即可向下继承。


static func build() -> Theme:
	var t := Theme.new()
	_flat_button_styles(t)
	_panels_and_labels(t)
	_progress_variants(t)
	return t


static func _sb_flat(
	bg: Color,
	border: Color,
	radius: int = 8,
	content: Vector4 = Vector4(14, 10, 14, 10),
	border_w: int = 2,
	shadow: bool = true,
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.38)
		s.shadow_size = 3
		s.shadow_offset = Vector2(0, 2)
	return s


static func _flat_button_styles(t: Theme) -> void:
	var n := _sb_flat(
		Color(0.14, 0.18, 0.26, 0.96), Color(0.32, 0.52, 0.68, 1), 8, Vector4(14, 10, 14, 10)
	)
	var h := _sb_flat(
		Color(0.18, 0.24, 0.34, 0.98), Color(0.42, 0.72, 0.88, 1), 8, Vector4(14, 10, 14, 10)
	)
	h.shadow_color = Color(0, 0, 0, 0.42)
	h.shadow_size = 4
	var p := _sb_flat(
		Color(0.1, 0.14, 0.22, 1), Color(0.55, 0.85, 0.45, 0.95), 8, Vector4(14, 10, 14, 10), 2, false
	)
	var d := _sb_flat(
		Color(0.12, 0.14, 0.18, 0.75), Color(0.28, 0.3, 0.36, 1), 8, Vector4(14, 10, 14, 10), 1, false
	)
	t.set_color(&"font_color", &"Button", Color(0.93, 0.95, 0.98, 1))
	t.set_color(&"font_hover_color", &"Button", Color(1, 1, 1, 1))
	t.set_color(&"font_pressed_color", &"Button", Color(0.75, 0.92, 0.65, 1))
	t.set_color(&"font_disabled_color", &"Button", Color(0.45, 0.48, 0.55, 1))
	t.set_font_size(&"font_size", &"Button", 15)
	t.set_stylebox(&"normal", &"Button", n)
	t.set_stylebox(&"hover", &"Button", h)
	t.set_stylebox(&"pressed", &"Button", p)
	t.set_stylebox(&"disabled", &"Button", d)


static func _panels_and_labels(t: Theme) -> void:
	var msg := _sb_flat(
		Color(0.1, 0.12, 0.18, 0.94), Color(0.38, 0.62, 0.78, 1), 10, Vector4(18, 14, 18, 14)
	)
	msg.shadow_color = Color(0, 0, 0, 0.45)
	msg.shadow_size = 5
	msg.shadow_offset = Vector2(0, 3)
	t.set_stylebox(&"panel", &"PanelContainer", msg)

	var tip := _sb_flat(
		Color(0.06, 0.08, 0.12, 0.95), Color(0.48, 0.58, 0.72, 1), 8, Vector4(12, 10, 12, 10), 1
	)
	tip.shadow_color = Color(0, 0, 0, 0.5)
	tip.shadow_size = 6
	t.set_type_variation(&"BattleTooltipPanel", &"PanelContainer")
	t.set_stylebox(&"panel", &"BattleTooltipPanel", tip)

	t.set_color(&"font_color", &"Label", Color(0.88, 0.9, 0.95, 1))
	t.set_font_size(&"font_size", &"Label", 14)
	t.set_color(&"default_color", &"RichTextLabel", Color(0.9, 0.92, 0.96, 1))
	t.set_font_size(&"normal_font_size", &"RichTextLabel", 16)
	t.set_font_size(&"bold_font_size", &"RichTextLabel", 16)
	t.set_font_size(&"italics_font_size", &"RichTextLabel", 15)
	t.set_font_size(&"bold_italics_font_size", &"RichTextLabel", 16)
	t.set_font_size(&"mono_font_size", &"RichTextLabel", 14)
	t.set_constant(&"separation", &"VBoxContainer", 8)
	t.set_constant(&"separation", &"HBoxContainer", 8)
	t.set_default_font_size(16)


static func _bar_track(dark: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = dark
	s.set_border_width_all(1)
	s.border_color = edge
	s.set_corner_radius_all(4)
	return s


static func _bar_fill(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(3)
	return s


static func _progress_variants(t: Theme) -> void:
	t.set_type_variation(&"CombatHpBar", &"ProgressBar")
	t.set_stylebox(&"background", &"CombatHpBar", _bar_track(Color(0.05, 0.1, 0.08, 1), Color(0.12, 0.2, 0.15, 1)))
	t.set_stylebox(&"fill", &"CombatHpBar", _bar_fill(Color(0.22, 0.88, 0.42, 1)))

	t.set_type_variation(&"CombatFocusBar", &"ProgressBar")
	t.set_stylebox(
		&"background", &"CombatFocusBar", _bar_track(Color(0.06, 0.09, 0.16, 1), Color(0.14, 0.2, 0.32, 1))
	)
	t.set_stylebox(&"fill", &"CombatFocusBar", _bar_fill(Color(0.38, 0.62, 1, 1)))
