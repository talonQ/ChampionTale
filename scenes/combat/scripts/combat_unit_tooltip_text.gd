class_name CombatUnitTooltipText
extends RefCounted
## 悬停单位说明文案（BBCode），与布局/拾取无关。


static func format_bbcode(u: BattleUnitRuntime) -> String:
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
	var trait_line := _traits_bbcode_line(u)
	if not trait_line.is_empty():
		state += "\n" + trait_line
	return (
		"[b]%s[/b]  %s  Lv.%d\n"
		% [u.display_name, side, u.level]
		+ "HP [b]%d[/b] / %d\n" % [u.hp, u.hp_max]
		+ "专注 [b]%d[/b] / %d  ·  速度 [b]%d[/b]\n" % [u.focus, u.focus_max, u.effective_spd()]
		+ "攻击 %d  ·  防御 %d" % [u.effective_atk(), u.effective_def()]
		+ state
	)


static func _status_bbcode_line(u: BattleUnitRuntime) -> String:
	var bits: PackedStringArray = []
	if u.has_status(BattleStatus.Kind.POISON):
		bits.append("[color=#a6e3a1]中毒[/color]")
	if u.has_status(BattleStatus.Kind.PARALYSIS):
		bits.append("[color=#ffe08a]麻痹[/color]")
	if bits.is_empty():
		return ""
	return "状态：" + " · ".join(bits)


static func _traits_bbcode_line(u: BattleUnitRuntime) -> String:
	if u.traits.is_empty():
		return ""
	var bits: PackedStringArray = []
	for trait_res in u.traits:
		if trait_res == null:
			continue
		bits.append("[color=#c9b8ff]「%s」[/color]" % trait_res.display_name)
	if bits.is_empty():
		return ""
	return "特性：" + " ".join(bits)
