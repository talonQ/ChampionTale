class_name CombatActionExecutor
extends RefCounted
## 技能 / 休息的结算与战报文案生成（只改 BattleUnitRuntime + SkillData，不碰场景节点）。
## 技能主流程由 `SkillResolvePipeline` 分阶段执行；本类保留入口与休息、回合间异常等。


const _Pipeline := preload("res://battle/skill_resolve_pipeline.gd")
const _BattleTextUtil := preload("res://battle/battle_text_util.gd")
const _SkillResolveBlocks := preload("res://battle/skill_resolve_blocks.gd")

const REST_FOCUS_RECOVERY := 15


static func short_name(u: BattleUnitRuntime) -> String:
	return _BattleTextUtil.unit_short_name(u)


static func apply_rest(
	actor: BattleUnitRuntime,
	on_unit_changed: Callable,
	on_turn_completed: Callable = Callable(),
) -> Array[String]:
	var para: Array[String] = _SkillResolveBlocks.lines_if_paralysis_skips_turn(
		actor,
		on_turn_completed,
	)
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
	event_sink: Callable = Callable(),
) -> Array[String]:
	return _Pipeline.apply_skill(
		actor,
		skill,
		targets,
		on_unit_changed,
		on_after_caster_spent,
		on_turn_completed,
		on_hp_healed,
		event_sink,
	)


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


## 回合末特性：回复力、专注力、力量代价等（与中毒 DOT 同一大轮替时机内、在其后执行）。
static func apply_between_round_trait_passives(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	return BattleTraitResolver.apply_round_end_passives(units, on_unit_changed)


static func apply_between_round_trait_regen(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	return apply_between_round_trait_passives(units, on_unit_changed)


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
