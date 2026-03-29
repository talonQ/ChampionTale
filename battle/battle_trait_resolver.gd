class_name BattleTraitResolver
extends RefCounted
## 特性规则：改威力/伤害、回合末回复、命中后中毒等（只操作运行时单位与 TraitData）。


const _BT := preload("res://battle/battle_text_util.gd")


static func append_poison_skin_after_damage(
	attacker: BattleUnitRuntime,
	target: BattleUnitRuntime,
	skill: SkillData,
	parts: Array[String],
	on_unit_changed: Callable,
) -> void:
	if not skill.deals_damage or not target.is_alive():
		return
	for trait_res in attacker.traits:
		if trait_res == null or trait_res.kind != TraitData.Kind.POISON_SKIN:
			continue
		if randf() > trait_res.poison_skin_chance:
			continue
		if target.has_status(BattleStatus.Kind.POISON):
			return
		target.set_status(BattleStatus.Kind.POISON, true)
		if on_unit_changed.is_valid():
			on_unit_changed.call(target)
		parts.append(
			"%s 的特性「%s」使 %s 中毒了！"
			% [_BT.unit_short_name(attacker), trait_res.display_name, _BT.unit_short_name(target)]
		)
		return


static func apply_round_end_regen(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	var lines: Array[String] = []
	for u in units:
		if not u.is_alive():
			continue
		for trait_res in u.traits:
			if trait_res == null or trait_res.kind != TraitData.Kind.REGEN_END_ROUND:
				continue
			var raw_heal := int(round(float(u.hp_max) * trait_res.regen_max_hp_fraction))
			var healed := mini(raw_heal, u.hp_max - u.hp)
			if healed <= 0:
				break
			u.hp = mini(u.hp_max, u.hp + healed)
			if on_unit_changed.is_valid():
				on_unit_changed.call(u)
			lines.append(
				"%s 的特性「%s」恢复了 %d 点体力！（%d / %d）"
				% [_BT.unit_short_name(u), trait_res.display_name, healed, u.hp, u.hp_max]
			)
			break
	return lines
