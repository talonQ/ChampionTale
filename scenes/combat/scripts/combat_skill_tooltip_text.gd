class_name CombatSkillTooltipText
extends RefCounted


static func format_rest_bbcode() -> String:
	var lines: PackedStringArray = []
	lines.append("[b]休息[/b]")
	lines.append("")
	lines.append("本回合不进行攻击，恢复专注。")
	lines.append("")
	lines.append(
		"恢复量：[b]%d[/b]（不超过专注上限）" % CombatActionExecutor.REST_FOCUS_RECOVERY
	)
	return "\n".join(lines)


static func format_skill_bbcode(skill: SkillData, actor: BattleUnitRuntime) -> String:
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]" % skill.display_name)
	lines.append("")
	var tgt := "单体敌方"
	if skill.target_kind == SkillData.TargetKind.NONE:
		tgt = "自身 / 无目标"
	lines.append("目标：%s" % tgt)
	if skill.deals_damage:
		lines.append("威力：[b]%d[/b]" % skill.power)
	else:
		lines.append("威力：—（不造成伤害）")
	lines.append("专注消耗：[b]%d[/b]" % skill.focus_cost)
	lines.append("命中：%d%%" % int(round(skill.hit_chance * 100.0)))
	if skill.cooldown_rounds > 0:
		lines.append("冷却：[b]%d[/b] 回合" % skill.cooldown_rounds)
	if skill.self_speed_delta != 0:
		lines.append("自身速度：%+d" % skill.self_speed_delta)
	if skill.target_speed_delta != 0:
		lines.append("命中目标速度：%+d" % skill.target_speed_delta)
	if actor != null:
		var cd := actor.skill_cooldown(skill)
		if cd > 0:
			lines.append("[color=#ff8888]剩余冷却：%d 回合[/color]" % cd)
		if not actor.can_pay_focus(skill):
			lines.append("[color=#ff8888]专注不足[/color]")
	var desc: String = skill.description.strip_edges()
	if not desc.is_empty():
		lines.append("")
		lines.append(desc)
	return "\n".join(lines)
