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
	return (
		"[b]%s[/b]  %s  Lv.%d\n"
		% [u.display_name, side, u.level]
		+ "HP [b]%d[/b] / %d\n" % [u.hp, u.hp_max]
		+ "专注 [b]%d[/b] / %d  ·  速度 [b]%d[/b]\n" % [u.focus, u.focus_max, u.effective_spd()]
		+ "攻击 %d  ·  防御 %d" % [u.effective_atk(), u.effective_def()]
		+ state
	)
