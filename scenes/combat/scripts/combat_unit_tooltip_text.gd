class_name CombatUnitTooltipText
extends RefCounted
## 悬停单位说明文案（BBCode），与布局/拾取无关。


## 名称、数值、状态、回合信息（不含特性）。
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
		+ "专注 [b]%d[/b] / %d  ·  速度 [b]%d[/b]\n" % [u.focus, u.focus_max, u.effective_spd()]
		+ "攻击 %d  ·  防御 %d" % [u.effective_atk(), u.effective_def()]
		+ state
	)


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
