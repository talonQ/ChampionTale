class_name CombatActionExecutor
extends RefCounted
## 技能 / 休息的结算与战报文案生成（只改 BattleUnitRuntime + SkillData，不碰场景节点）。


const REST_FOCUS_RECOVERY := 15


static func short_name(u: BattleUnitRuntime) -> String:
	var n := u.display_name
	var p := n.find("·")
	if p != -1 and p + 1 < n.length():
		return n.substr(p + 1).strip_edges()
	return n


static func apply_rest(actor: BattleUnitRuntime, on_unit_changed: Callable) -> Array[String]:
	var before := actor.focus
	actor.add_focus(REST_FOCUS_RECOVERY)
	actor.acted_this_round = true
	if on_unit_changed.is_valid():
		on_unit_changed.call(actor)
	return [
		"%s 稍作休息，专注从 %d 恢复到了 %d。" % [short_name(actor), before, actor.focus],
	]


static func apply_skill(
	actor: BattleUnitRuntime,
	skill: SkillData,
	targets: Array[BattleUnitRuntime],
	on_unit_changed: Callable,
	on_after_caster_spent: Callable = Callable(),
) -> Array[String]:
	var out: Array[String] = []
	var opener := "%s 使出了 %s！" % [short_name(actor), skill.display_name]
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		if targets.is_empty():
			actor.acted_this_round = true
			return [opener + " 但没有可攻击的目标。"]
	actor.spend_focus(skill.focus_cost)
	if on_unit_changed.is_valid():
		on_unit_changed.call(actor)
	if on_after_caster_spent.is_valid():
		on_after_caster_spent.call(actor, skill, targets)
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		var target := targets[0]
		if BattleSkillResolver.roll_hit(skill):
			var dmg := BattleSkillResolver.compute_damage(actor, skill, target)
			BattleSkillResolver.apply_damage(target, dmg)
			if on_unit_changed.is_valid():
				on_unit_changed.call(target)
			var tail := "击中了 %s，造成 %d 点伤害！" % [short_name(target), dmg]
			if not target.is_alive():
				tail += " %s 倒下了！" % short_name(target)
			out.append(opener + "\n" + tail)
		else:
			out.append(opener + "\n但是没有命中！（专注仍会消耗）")
	elif skill.target_kind == SkillData.TargetKind.NONE:
		out.append(opener + "\n%s 集中精神……" % short_name(actor))
	if skill.self_speed_delta != 0:
		actor.spd_mod += skill.self_speed_delta
		var spd_line: String
		if skill.self_speed_delta > 0:
			spd_line = "%s 的速度提升了！（当前速度 %d）" % [short_name(actor), actor.effective_spd()]
		else:
			spd_line = "%s 的速度降低了！（当前速度 %d）" % [short_name(actor), actor.effective_spd()]
		if out.is_empty():
			out.append(opener + "\n" + spd_line)
		else:
			out.append(spd_line)
	if skill.cooldown_rounds > 0:
		actor.skill_cooldown_remaining[skill.id] = skill.cooldown_rounds
		out.append("%s 进入冷却（%d 回合）。" % [skill.display_name, skill.cooldown_rounds])
	if out.is_empty():
		out.append(opener)
	actor.acted_this_round = true
	return out


static func alive_player_side(units: Array[BattleUnitRuntime]) -> Array[BattleUnitRuntime]:
	var out: Array[BattleUnitRuntime] = []
	for u in units:
		if u.is_alive() and u.is_player_side:
			out.append(u)
	return out


static func build_enemy_action_lines(
	actor: BattleUnitRuntime,
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable,
	on_after_caster_spent: Callable = Callable(),
) -> PackedStringArray:
	var candidates: Array[SkillData] = []
	for s in actor.skills:
		if not actor.can_use_skill(s):
			continue
		if s.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
			if alive_player_side(units).is_empty():
				continue
			candidates.append(s)
		elif s.target_kind == SkillData.TargetKind.NONE:
			candidates.append(s)
	if candidates.is_empty():
		return PackedStringArray(apply_rest(actor, on_unit_changed))
	candidates.sort_custom(func(a: SkillData, b: SkillData) -> bool: return a.power > b.power)
	var skill: SkillData = candidates[0]
	if skill.target_kind == SkillData.TargetKind.NONE:
		return PackedStringArray(apply_skill(actor, skill, [], on_unit_changed, on_after_caster_spent))
	var pts := alive_player_side(units)
	pts.sort_custom(func(a: BattleUnitRuntime, b: BattleUnitRuntime) -> bool: return a.hp < b.hp)
	return PackedStringArray(apply_skill(actor, skill, [pts[0]], on_unit_changed, on_after_caster_spent))
