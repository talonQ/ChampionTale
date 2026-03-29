class_name SkillResolveBlocks
extends RefCounted
## 技能结算共用积木（麻痹、命中后异常、目标速度等），供流水线组合调用。

const _BT := preload("res://battle/battle_text_util.gd")


static func lines_if_paralysis_skips_turn(
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
	return ["%s 因麻痹而无法行动。" % _BT.unit_short_name(actor)]


static func prepend_opener_if_needed(opener: String, lines: Array[String]) -> Array[String]:
	if lines.is_empty():
		return lines
	var merged: Array[String] = []
	merged.append(opener + "\n" + lines[0])
	for i in range(1, lines.size()):
		merged.append(lines[i])
	return merged


static func append_on_hit_status_effects(
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
			"%s 中了%s！" % [_BT.unit_short_name(target), BattleStatus.status_display_name(k)]
		)


static func append_target_speed_lines(
	skill: SkillData,
	target: BattleUnitRuntime,
	parts: Array[String],
	on_unit_changed: Callable,
) -> void:
	if not target.is_alive() or skill.target_speed_delta == 0:
		return
	target.spd_mod += skill.target_speed_delta
	if skill.target_speed_delta > 0:
		parts.append(
			"%s 的速度提升了！（当前速度 %d）" % [_BT.unit_short_name(target), target.effective_spd()]
		)
	else:
		parts.append(
			"%s 的速度降低了！（当前速度 %d）" % [_BT.unit_short_name(target), target.effective_spd()]
		)
	if on_unit_changed.is_valid():
		on_unit_changed.call(target)
