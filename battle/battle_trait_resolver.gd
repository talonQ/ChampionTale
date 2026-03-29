class_name BattleTraitResolver
extends RefCounted
## 特性规则：改威力/伤害、回合末效果、命中后中毒等（只操作运行时单位与 TraitData）。


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


## 中毒 DOT 之后、进入新回合之前：生命回复、专注回复、力量代价等。
static func apply_round_end_passives(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	var lines: Array[String] = []
	for u in units:
		if not u.is_alive():
			continue
		var regen_done := false
		var focus_done := false
		var toll_done := false
		for trait_res in u.traits:
			if trait_res == null:
				continue
			match trait_res.kind:
				TraitData.Kind.REGEN_END_ROUND:
					if regen_done:
						continue
					regen_done = true
					var raw_heal := int(round(float(u.hp_max) * trait_res.regen_max_hp_fraction))
					var healed := mini(raw_heal, u.hp_max - u.hp)
					if healed <= 0:
						continue
					u.hp = mini(u.hp_max, u.hp + healed)
					if on_unit_changed.is_valid():
						on_unit_changed.call(u)
					lines.append(
						"%s 的特性「%s」恢复了 %d 点体力！（%d / %d）"
						% [_BT.unit_short_name(u), trait_res.display_name, healed, u.hp, u.hp_max]
					)
				TraitData.Kind.FOCUS_RESTORE_END_ROUND:
					if focus_done:
						continue
					focus_done = true
					var raw_f := int(round(float(u.focus_max) * trait_res.focus_restore_max_fraction))
					var gained := mini(raw_f, u.focus_max - u.focus)
					if gained <= 0:
						continue
					u.add_focus(gained)
					if on_unit_changed.is_valid():
						on_unit_changed.call(u)
					lines.append(
						"%s 的特性「%s」恢复了 %d 点专注！（%d / %d）"
						% [_BT.unit_short_name(u), trait_res.display_name, gained, u.focus, u.focus_max]
					)
				TraitData.Kind.POWER_TOLL_END_ROUND:
					if toll_done:
						continue
					toll_done = true
					var da: int = trait_res.power_toll_atk_mod
					var dd: int = trait_res.power_toll_def_mod
					u.atk_mod += da
					u.def_mod += dd
					if on_unit_changed.is_valid():
						on_unit_changed.call(u)
					lines.append(
						(
							"%s 的特性「%s」生效：攻击 %+d、防御 %+d（当前有效 攻 %d · 防 %d）"
							% [
								_BT.unit_short_name(u),
								trait_res.display_name,
								da,
								dd,
								u.effective_atk(),
								u.effective_def(),
							]
						)
					)
				_:
					pass
	return lines


## 兼容旧名；请优先使用 `apply_round_end_passives`。
static func apply_round_end_regen(
	units: Array[BattleUnitRuntime],
	on_unit_changed: Callable = Callable(),
) -> Array[String]:
	return apply_round_end_passives(units, on_unit_changed)
