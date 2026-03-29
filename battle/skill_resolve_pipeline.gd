class_name SkillResolvePipeline
extends RefCounted
## 技能结算流水线：阶段顺序固定，主效果按 `target_kind` 分派，便于插钩子与扩展特性。

const _Ctx := preload("res://battle/skill_resolve_context.gd")
const _Blocks := preload("res://battle/skill_resolve_blocks.gd")
const _BT := preload("res://battle/battle_text_util.gd")
const _Events := preload("res://battle/battle_combat_events.gd")


static func apply_skill(
	actor: BattleUnitRuntime,
	skill: SkillData,
	targets: Array[BattleUnitRuntime],
	on_unit_changed: Callable,
	on_after_caster_spent: Callable = Callable(),
	on_turn_completed: Callable = Callable(),
	on_hp_healed: Callable = Callable(),
	event_sink: Callable = Callable(),
) -> Array[String]:
	var ctx: SkillResolveContext = _Ctx.new()
	ctx.actor = actor
	ctx.skill = skill
	ctx.targets = targets
	ctx.on_unit_changed = on_unit_changed
	ctx.on_after_caster_spent = on_after_caster_spent
	ctx.on_turn_completed = on_turn_completed
	ctx.on_hp_healed = on_hp_healed
	ctx.event_sink = event_sink
	ctx.opener = "%s 使出了 %s！" % [_BT.unit_short_name(actor), skill.display_name]

	var bad_targets := _phase_validate_targets(ctx)
	if not bad_targets.is_empty():
		return bad_targets

	var para: Array[String] = _Blocks.lines_if_paralysis_skips_turn(actor, on_turn_completed)
	if not para.is_empty():
		return _Blocks.prepend_opener_if_needed(ctx.opener, para)

	ctx.emit(_Events.SKILL_RESOLVE_STARTED, {})
	_phase_spend_and_hooks(ctx)

	match skill.target_kind:
		SkillData.TargetKind.SINGLE_ENEMY:
			_resolve_single_enemy(ctx)
			ctx.emit(_Events.TARGETED_SKILL_PRIMARY_DONE, {"target": ctx.targets[0]})
		SkillData.TargetKind.SINGLE_ALLY:
			_resolve_single_ally(ctx)
			ctx.emit(_Events.TARGETED_SKILL_PRIMARY_DONE, {"target": ctx.targets[0]})
		SkillData.TargetKind.NONE:
			_resolve_self_skill(ctx)
			ctx.emit(_Events.SELF_SKILL_PRIMARY_DONE, {})

	_phase_self_speed(ctx)
	_phase_cooldown(ctx)
	_phase_ensure_opener(ctx)
	_mark_turn_done(ctx)
	ctx.emit(_Events.SKILL_RESOLVE_FINISHED, {"segments": ctx.segments.duplicate()})
	return ctx.segments


static func _mark_turn_done(ctx: SkillResolveContext) -> void:
	ctx.actor.acted_this_round = true
	if ctx.on_turn_completed.is_valid():
		ctx.on_turn_completed.call(ctx.actor)


static func _phase_validate_targets(ctx: SkillResolveContext) -> Array[String]:
	var sk := ctx.skill
	var actor := ctx.actor
	var opener := ctx.opener
	if sk.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		if ctx.targets.is_empty():
			_mark_turn_done(ctx)
			return [opener + " 但没有可攻击的目标。"]
	if sk.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		if ctx.targets.is_empty():
			_mark_turn_done(ctx)
			return [opener + " 但没有可选的友方目标。"]
		var ally := ctx.targets[0]
		if not ally.is_alive() or ally.is_player_side != actor.is_player_side:
			_mark_turn_done(ctx)
			return [opener + " 目标无效。"]
	return []


static func _phase_spend_and_hooks(ctx: SkillResolveContext) -> void:
	var actor := ctx.actor
	var sk := ctx.skill
	actor.spend_focus(sk.focus_cost)
	if ctx.on_unit_changed.is_valid():
		ctx.on_unit_changed.call(actor)
	if ctx.on_after_caster_spent.is_valid():
		ctx.on_after_caster_spent.call(actor, sk, ctx.targets)
	ctx.emit(_Events.FOCUS_SPENT, {"focus_spent": sk.focus_cost})


static func _resolve_single_enemy(ctx: SkillResolveContext) -> void:
	var sk := ctx.skill
	var actor := ctx.actor
	var target := ctx.targets[0]
	var opener := ctx.opener
	if not BattleSkillResolver.roll_hit(sk):
		ctx.segments.append(opener + "\n但是没有命中！（专注仍会消耗）")
		return
	var parts: Array[String] = []
	if sk.deals_damage:
		var hp_before := target.hp
		var dmg := BattleSkillResolver.compute_damage(actor, sk, target)
		BattleSkillResolver.apply_damage(target, dmg)
		ctx.emit(
			_Events.TARGET_TOOK_DAMAGE_FROM_SKILL,
			{"target": target, "damage": dmg, "hp_before": hp_before, "hp_after": target.hp},
		)
		var tail := "击中了 %s，造成 %d 点伤害！" % [_BT.unit_short_name(target), dmg]
		if not target.is_alive():
			tail += " %s 倒下了！" % _BT.unit_short_name(target)
		parts.append(tail)
	else:
		parts.append("击中了 %s。" % _BT.unit_short_name(target))
	_Blocks.append_target_speed_lines(sk, target, parts, ctx.on_unit_changed)
	if ctx.on_unit_changed.is_valid():
		ctx.on_unit_changed.call(target)
	if target.is_alive():
		_Blocks.append_on_hit_status_effects(sk, target, parts, ctx.on_unit_changed)
		BattleTraitResolver.append_poison_skin_after_damage(actor, target, sk, parts, ctx.on_unit_changed)
	ctx.segments.append(opener + "\n" + "\n".join(PackedStringArray(parts)))


static func _resolve_single_ally(ctx: SkillResolveContext) -> void:
	var sk := ctx.skill
	var actor := ctx.actor
	var target := ctx.targets[0]
	var opener := ctx.opener
	var ally_hit := (not sk.deals_damage) or BattleSkillResolver.roll_hit(sk)
	var parts: Array[String] = []
	var out: Array[String] = []
	if sk.deals_damage:
		if ally_hit:
			var hp_before := target.hp
			var dmg := BattleSkillResolver.compute_damage(actor, sk, target)
			BattleSkillResolver.apply_damage(target, dmg)
			ctx.emit(
				_Events.TARGET_TOOK_DAMAGE_FROM_SKILL,
				{"target": target, "damage": dmg, "hp_before": hp_before, "hp_after": target.hp},
			)
			var tail := "击中了 %s，造成 %d 点伤害！" % [_BT.unit_short_name(target), dmg]
			if not target.is_alive():
				tail += " %s 失去了战斗能力！" % _BT.unit_short_name(target)
			parts.append(tail)
			if ctx.on_unit_changed.is_valid():
				ctx.on_unit_changed.call(target)
		else:
			out.append(opener + "\n但是没有命中！（专注仍会消耗）")
	else:
		if sk.restore_target_focus_max_fraction > 0.0:
			var raw_gain := int(
				round(float(target.focus_max) * float(sk.restore_target_focus_max_fraction))
			)
			var before_f := target.focus
			var actual := mini(raw_gain, target.focus_max - target.focus)
			if actual > 0:
				target.add_focus(actual)
				parts.append(
					"%s 恢复了 %d 点专注！（%d → %d / %d）"
					% [_BT.unit_short_name(target), actual, before_f, target.focus, target.focus_max]
				)
			else:
				parts.append("%s 的专注已满。" % _BT.unit_short_name(target))
		else:
			parts.append("选中了 %s。" % _BT.unit_short_name(target))
		if ctx.on_unit_changed.is_valid():
			ctx.on_unit_changed.call(target)
	if ally_hit and target.is_alive():
		_Blocks.append_target_speed_lines(sk, target, parts, ctx.on_unit_changed)
	if ally_hit and target.is_alive():
		_Blocks.append_on_hit_status_effects(sk, target, parts, ctx.on_unit_changed)
		BattleTraitResolver.append_poison_skin_after_damage(actor, target, sk, parts, ctx.on_unit_changed)
	if not parts.is_empty() and out.is_empty():
		out.append(opener + "\n" + "\n".join(PackedStringArray(parts)))
	ctx.segments.append_array(out)


static func _resolve_self_skill(ctx: SkillResolveContext) -> void:
	var sk := ctx.skill
	var actor := ctx.actor
	var opener := ctx.opener
	var primary: String
	if sk.heal_self_max_hp_fraction > 0.0:
		var hp_before := actor.hp
		var raw_heal := int(round(float(actor.hp_max) * float(sk.heal_self_max_hp_fraction)))
		var heal_amt := mini(raw_heal, actor.hp_max - actor.hp)
		actor.hp = mini(actor.hp_max, actor.hp + heal_amt)
		if ctx.on_unit_changed.is_valid():
			ctx.on_unit_changed.call(actor)
		if heal_amt > 0 and ctx.on_hp_healed.is_valid():
			ctx.on_hp_healed.call(actor, heal_amt)
		ctx.emit(
			_Events.CASTER_HEALED_SELF,
			{"heal_amount": heal_amt, "hp_before": hp_before, "hp_after": actor.hp},
		)
		primary = "%s 恢复了 %d 点生命！（%d / %d）" % [
			_BT.unit_short_name(actor),
			heal_amt,
			actor.hp,
			actor.hp_max,
		]
	else:
		primary = "%s 集中精神……" % _BT.unit_short_name(actor)
	ctx.segments.append(opener + "\n" + primary)


static func _phase_self_speed(ctx: SkillResolveContext) -> void:
	var sk := ctx.skill
	var actor := ctx.actor
	var opener := ctx.opener
	if sk.self_speed_stage_delta == 0:
		return
	actor.add_speed_stage(sk.self_speed_stage_delta)
	var spd_line: String
	if sk.self_speed_stage_delta > 0:
		spd_line = "%s 的速度能力提升了！（当前速度 %d，阶段 %+d）" % [_BT.unit_short_name(actor), actor.effective_spd(), actor.spd_stage]
	else:
		spd_line = "%s 的速度能力降低了！（当前速度 %d，阶段 %+d）" % [_BT.unit_short_name(actor), actor.effective_spd(), actor.spd_stage]
	if ctx.segments.is_empty():
		ctx.segments.append(opener + "\n" + spd_line)
	else:
		ctx.segments.append(spd_line)


static func _phase_cooldown(ctx: SkillResolveContext) -> void:
	var sk := ctx.skill
	var actor := ctx.actor
	if sk.cooldown_rounds <= 0:
		return
	actor.skill_cooldown_remaining[sk.id] = sk.cooldown_rounds
	ctx.segments.append("%s 进入冷却（%d 回合）。" % [sk.display_name, sk.cooldown_rounds])


static func _phase_ensure_opener(ctx: SkillResolveContext) -> void:
	if ctx.segments.is_empty():
		ctx.segments.append(ctx.opener)
