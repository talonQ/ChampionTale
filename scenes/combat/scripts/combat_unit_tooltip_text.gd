class_name CombatUnitTooltipText
extends RefCounted
## 悬停单位说明文案（BBCode），与布局/拾取无关。

## 右指（阶段提升）、左指（阶段降低）；与 `arrow.png` 成对，由引擎外水平翻转得到（RichTextLabel 的 `[img]` 无法镜像单张图）。
const _ARROW_RIGHT := "res://scenes/ui/textures/arrow.png"
const _ARROW_LEFT := "res://scenes/ui/textures/arrow_left.png"
const _ARROW_W := 14
const _ARROW_H := 14
const _STAGE_UP_COLOR := "#3dcc6a"
const _STAGE_DOWN_COLOR := "#e85555"
## 与 `combat_prototype_demo.tscn` 中 TooltipText 的 `normal_font_size = 14` 对齐，能力数值略小一号。
const _STAT_VALUE_FONT_SIZE := 12


## 名称、数值、状态、回合信息（不含特性）。攻防速等为 **种族基础 + 等级**（阶段前）；阶段用着色箭头表示，不再输出文字阶段行。
static func format_stats_bbcode(u: BattleUnitRuntime) -> String:
	var side := "[color=#6ab0ff]己方[/color]" if u.is_player_side else "[color=#ff8a6a]敌方[/color]"
	var state := ""
	if not u.is_alive():
		state = "\n[color=#888]无法战斗[/color]"
	elif u.acted_this_round:
		state = "\n[color=#aaa]本回合已行动[/color]"
	if u.is_alive():
		var st := _status_bbcode_line(u)
		if not st.is_empty():
			state += "\n" + st
	return (
		"[b]%s[/b]  %s  Lv.%d\n"
		% [u.display_name, side, u.level]
		+ "HP [b]%d[/b] / %d\n" % [u.hp, u.hp_max]
		+ "专注 [b]%d[/b] / %d\n" % [u.focus, u.focus_max]
		+ _stat_line_bbcode("攻击", u.atk_base + u.level, u.atk_stage)
		+ _stat_line_bbcode("防御", u.def_base + u.level, u.def_stage)
		+ _stat_line_bbcode("特攻", u.spatk_base + u.level, u.spatk_stage)
		+ _stat_line_bbcode("特防", u.spdef_base + u.level, u.spdef_stage)
		+ _stat_line_bbcode("速度", u.spd_base + u.level, u.spd_stage)
		+ state
	)


static func _stat_line_bbcode(label: String, base_plus_level: int, stage: int) -> String:
	var arrows := _stage_arrows_bbcode(stage)
	var gap := " " if not arrows.is_empty() else ""
	return "%s [font_size=%d][b]%d[/b][/font_size]%s%s\n" % [label, _STAT_VALUE_FONT_SIZE, base_plus_level, gap, arrows]


static func _stage_arrows_bbcode(stage: int) -> String:
	if stage == 0:
		return ""
	var n: int = mini(absi(stage), 6)
	var path: String = _ARROW_RIGHT if stage > 0 else _ARROW_LEFT
	var col: String = _STAGE_UP_COLOR if stage > 0 else _STAGE_DOWN_COLOR
	var parts: PackedStringArray = []
	parts.resize(n)
	for i in n:
		parts[i] = "[img width=%d height=%d color=%s]%s[/img]" % [_ARROW_W, _ARROW_H, col, path]
	return "".join(parts)


## 特性名与说明；无特性时返回空字符串（不显示第二块 Tooltip）。
static func format_traits_bbcode(u: BattleUnitRuntime) -> String:
	if u.traits.is_empty():
		return ""
	var blocks: PackedStringArray = []
	for trait_res in u.traits:
		if trait_res == null:
			continue
		blocks.append("[b][color=#c9b8ff]特性 · %s[/color][/b]" % trait_res.display_name)
		var desc := trait_res.description.strip_edges()
		if not desc.is_empty():
			blocks.append(desc)
	if blocks.is_empty():
		return ""
	return "\n\n".join(blocks)


## 兼容旧调用；等价于 `format_stats_bbcode`。
static func format_bbcode(u: BattleUnitRuntime) -> String:
	return format_stats_bbcode(u)


static func _status_bbcode_line(u: BattleUnitRuntime) -> String:
	var bits: PackedStringArray = []
	if u.has_status(BattleStatus.Kind.POISON):
		bits.append("[color=#a6e3a1]中毒[/color]")
	if u.has_status(BattleStatus.Kind.PARALYSIS):
		bits.append("[color=#ffe08a]麻痹[/color]")
	if bits.is_empty():
		return ""
	return "状态：" + " · ".join(bits)
