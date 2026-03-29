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


static func apply_rest(
	actor: BattleUnitRuntime,
	on_unit_changed: Callable,
	on_turn_completed: Callable = Callable(),
) -> Array[String]:
	var para := _lines_if_paralysis_skips_turn(actor, on_turn_completed)
	if not para.is_empty():
		return para
	var before := actor.focus
	actor.add_focus(REST_FOCUS_RECOVERY)
	actor.acted_this_round = true
	if on_turn_completed.is_valid():
		on_turn_completed.call(actor)
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
	on_turn_completed: Callable = Callable(),
	on_hp_healed: Callable = Callable(),
) -> Array[String]:
	var out: Array[String] = []
	var opener := "%s 使出了 %s！" % [short_name(actor), skill.display_name]
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		if targets.is_empty():
			actor.acted_this_round = true
			if on_turn_completed.is_valid():
				on_turn_completed.call(actor)
			return [opener + " 但没有可攻击的目标。"]
	if skill.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		if targets.is_empty():
			actor.acted_this_round = true
			if on_turn_completed.is_valid():
				on_turn_completed.call(actor)
			return [opener + " 但没有可选的友方目标。"]
		var ally := targets[0]
		if not ally.is_alive() or ally.is_player_side != actor.is_player_side:
			actor.acted_this_round = true
			if on_turn_completed.is_valid():
				on_turn_completed.call(actor)
			return [opener + " 目标无效。"]
	var para := _lines_if_paralysis_skips_turn(actor, on_turn_completed)
	if not para.is_empty():
		return _prepend_opener_if_needed(opener, para)
	actor.spend_focus(skill.focus_cost)
	if on_unit_changed.is_valid():
		on_unit_changed.call(actor)
	if on_after_caster_spent.is_valid():
		on_after_caster_spent.call(actor, skill, targets)
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		var target := targets[0]
		if BattleSkillResolver.roll_hit(skill):
			var parts: Array[String] = []
			if skill.deals_damage:
				var dmg := BattleSkillResolver.compute_damage(actor, skill, target)
				BattleSkillResolver.apply_damage(target, dmg)
				var tail := "击中了 %s，造成 %d 点伤害！" % [short_name(target), dmg]
				if not target.is_alive():
					tail += " %s 倒下了！" % short_name(target)
				parts.append(tail)
			else:
				parts.append("击中了 %s。" % short_name(target))
			if target.is_alive() and skill.target_speed_delta != 0:
				target.spd_mod += skill.target_speed_delta
				if skill.target_speed_delta > 0:
					parts.append(
						"%s 的速度提升了！（当前速度 %d）" % [short_name(target), target.effective_spd()]
					)
				else:
					parts.append(
						"%s 的速度降低了！（当前速度 %d）" % [short_name(target), target.effective_spd()]
					)
			if on_unit_changed.is_valid():
				on_unit_changed.call(target)
			if target.is_alive():
				_append_on_hit_status_effects(skill, target, parts, on_unit_changed)
			out.append(opener + "\n" + "\n".join(PackedStringArray(parts)))
		else:
			out.append(opener + "\n但是没有命中！（专注仍会消耗）")
	elif skill.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		var target := targets[0]
		var ally_hit := (not skill.deals_damage) or BattleSkillResolver.roll_hit(skill)
		var parts: Array[String] = []
		if skill.deals_damage:
			if ally_hit:
				var dmg := BattleSkillResolver.compute_damage(actor, skill, target)
				BattleSkillResolver.apply_damage(target, dmg)
				var tail := "击中了 %s，造成 %d 点伤害！" % [short_name(target), dmg]
				if not target.is_alive():
					tail += " %s 失去了战斗能力！" % short_name(target)
				parts.append(tail)
				if on_unit_changed.is_valid():
					on_unit_changed.call(target)
			else:
				out.append(opener + "\n但是没有命中！（专注仍会消耗）")
		else:
			if skill.restore_target_focus_max_fraction > 0.0:
				var raw_gain := int(
					round(float(target.focus_max) * float(skill.restore_target_focus_max_fraction))
				)
				var before_f := target.focus
				var actual := mini(raw_gain, target.focus_max - target.focus)
				if actual > 0:
					target.add_focus(actual)
					parts.append(
						"%s 恢复了 %d 点专注！（%d → %d / %d）"
						% [short_name(target), actual, before_f, target.focus, target.focus_max]
					)
				else:
					parts.append("%s 的专注已满。" % short_name(target))
			else:
				parts.append("选中了 %s。" % short_name(target))
			if on_unit_changed.is_valid():
				on_unit_changed.call(target)
		if ally_hit and target.is_alive() and skill.target_speed_delta != 0:
			target.spd_mod += skill.target_speed_delta
			if skill.target_speed_delta > 0:
				parts.append(
					"%s 的速度提升了！（当前速度 %d）" % [short_name(target), target.effective_spd()]
				)
			else:
				parts.append(
					"%s 的速度降低了！（当前速度 %d）" % [short_name(target), target.effective_spd()]
				)
			if on_unit_changed.is_valid():
				on_unit_changed.call(target)
		if ally_hit and target.is_alive():
			_append_on_hit_status_effects(skill, target, parts, on_unit_changed)
		if not parts.is_empty() and out.is_empty():
			out.append(opener + "\n" + "\n".join(PackedStringArray(parts)))
	elif skill.target_kind == SkillData.TargetKind.NONE:
		var primary: String
		if skill.heal_self_max_hp_fraction > 0.0:
			var raw_heal := int(round(float(actor.hp_max) * float(skill.heal_self_max_hp_fraction)))
			var heal_amt := mini(raw_heal, actor.hp_max - actor.hp)
			actor.hp = mini(actor.hp_max, actor.hp + heal_amt)
			if on_unit_changed.is_valid():
				on_unit_changed.call(actor)
			if heal_amt > 0 and on_hp_healed.is_valid():
				on_hp_healed.call(actor, heal_amt)
			primary = "%s 恢复了 %d 点生命！（%d / %d）" % [
				short_name(actor),
				heal_amt,
				actor.hp,
				actor.hp_max,
			]
		else:
			primary = "%s 集中精神……" % short_name(actor)
		out.append(opener + "\n" + primary)
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
	if on_turn_completed.is_valid():
		on_turn_completed.call(actor)
	return out


static func apply_between_round_status_damage(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	var lines: Array[String] = []
	for u in units:
		if not u.is_alive():
			continue
		if not u.has_status(BattleStatus.Kind.POISON):
			continue
		var raw := int(
			round(float(u.hp_max) * float(BattleStatus.POISON_MAX_HP_FRACTION_PER_ROUND))
		)
		var dmg := maxi(1, raw)
		BattleSkillResolver.apply_damage(u, dmg)
		if on_unit_changed.is_valid():
			on_unit_changed.call(u)
		lines.append(
			"%s 因中毒损失了 %d 点体力！（%d / %d）"
			% [short_name(u), dmg, u.hp, u.hp_max]
		)
		if not u.is_alive():
			lines.append("%s 倒下了！" % short_name(u))
	return lines


static func _lines_if_paralysis_skips_turn(
	actor: BattleUnitRuntime,
	on_turn_completed: Callable,
) -> Array[String]:
	if not actor.has_status(BattleStatus.Kind.PARALYSIS):
		return []
	if not BattleStatus.roll_paralysis_blocks_action():
		return []
	actor.acted_this_round = true
	if on_turn_completed.is_valid():
		on_turn_completed.call(actor)
	return ["%s 因麻痹而无法行动。" % short_name(actor)]


static func _prepend_opener_if_needed(opener: String, lines: Array[String]) -> Array[String]:
	if lines.is_empty():
		return lines
	var merged: Array[String] = []
	merged.append(opener + "\n" + lines[0])
	for i in range(1, lines.size()):
		merged.append(lines[i])
	return merged


static func _append_on_hit_status_effects(
	skill: SkillData,
	target: BattleUnitRuntime,
	parts: Array[String],
	on_unit_changed: Callable,
) -> void:
	for fx in skill.on_hit_status_effects:
		if fx == null:
			continue
		if randf() > fx.chance:
			continue
		var k: BattleStatus.Kind = fx.status
		if target.has_status(k):
			continue
		target.set_status(k, true)
		if on_unit_changed.is_valid():
			on_unit_changed.call(target)
		parts.append(
			"%s 中了%s！" % [short_name(target), BattleStatus.status_display_name(k)]
		)


static func alive_player_side(units: Array[BattleUnitRuntime]) -> Array[BattleUnitRuntime]:
	var out: Array[BattleUnitRuntime] = []
	for u in units:
		if u.is_alive() and u.is_player_side:
			out.append(u)
	return out


static func alive_allies_on_same_side(
	actor: BattleUnitRuntime,
	units: Array[BattleUnitRuntime],
) -> Array[BattleUnitRuntime]:
	var out: Array[BattleUnitRuntime] = []
	for u in units:
		if u.is_alive() and u.is_player_side == actor.is_player_side:
			out.append(u)
	return out


static func build_enemy_action_lines(
	actor: BattleUnitRuntime,
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable,
	on_after_caster_spent: Callable = Callable(),
	on_turn_completed: Callable = Callable(),
	on_hp_healed: Callable = Callable(),
) -> PackedStringArray:
	var candidates: Array[SkillData] = []
	for s in actor.skills:
		if not actor.can_use_skill(s):
			continue
		if s.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
			if alive_player_side(units).is_empty():
				continue
			candidates.append(s)
		elif s.target_kind == SkillData.TargetKind.SINGLE_ALLY:
			if alive_allies_on_same_side(actor, units).is_empty():
				continue
			candidates.append(s)
		elif s.target_kind == SkillData.TargetKind.NONE:
			candidates.append(s)
	if candidates.is_empty():
		return PackedStringArray(apply_rest(actor, on_unit_changed, on_turn_completed))
	candidates.sort_custom(func(a: SkillData, b: SkillData) -> bool: return a.power > b.power)
	var skill: SkillData = candidates[0]
	if skill.target_kind == SkillData.TargetKind.NONE:
		return PackedStringArray(
			apply_skill(
				actor,
				skill,
				[],
				on_unit_changed,
				on_after_caster_spent,
				on_turn_completed,
				on_hp_healed,
			)
		)
	if skill.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		var allies := alive_allies_on_same_side(actor, units)
		allies.sort_custom(func(a: BattleUnitRuntime, b: BattleUnitRuntime) -> bool:
			var ra := float(a.focus) / float(maxi(1, a.focus_max))
			var rb := float(b.focus) / float(maxi(1, b.focus_max))
			return ra < rb
		)
		return PackedStringArray(
			apply_skill(
				actor,
				skill,
				[allies[0]],
				on_unit_changed,
				on_after_caster_spent,
				on_turn_completed,
				on_hp_healed,
			)
		)
	var pts := alive_player_side(units)
	pts.sort_custom(func(a: BattleUnitRuntime, b: BattleUnitRuntime) -> bool: return a.hp < b.hp)
	return PackedStringArray(
		apply_skill(
			actor,
			skill,
			[pts[0]],
			on_unit_changed,
			on_after_caster_spent,
			on_turn_completed,
			on_hp_healed,
		)
	)
