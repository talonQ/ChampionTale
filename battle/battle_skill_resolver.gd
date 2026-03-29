class_name BattleSkillResolver
extends RefCounted

const _DmgCtx := preload("res://battle/battle_damage_modify_context.gd")


static func roll_hit(skill: SkillData) -> bool:
	return randf() <= skill.hit_chance


static func compute_damage(attacker: BattleUnitRuntime, skill: SkillData, target: BattleUnitRuntime) -> int:
	var ctx = _DmgCtx.new()
	ctx.attacker = attacker
	ctx.defender = target
	ctx.skill = skill
	ctx.skill_power = skill.power
	if skill.deals_damage:
		attacker.run_trait_skill_power_hooks(ctx)
	var atk_stat: int
	var def_stat: int
	match skill.move_category:
		1: ## SkillData.MoveCategory.SPECIAL
			atk_stat = attacker.effective_spatk()
			def_stat = target.effective_spdef()
		2: ## SkillData.MoveCategory.STATUS
			## 变化类若仍造成伤害，按物攻/物防处理（通常 `deals_damage` 为 false）。
			atk_stat = attacker.effective_atk()
			def_stat = target.effective_def()
		_:
			atk_stat = attacker.effective_atk()
			def_stat = target.effective_def()
	ctx.raw_damage = atk_stat + ctx.skill_power - def_stat
	if skill.deals_damage:
		attacker.run_trait_raw_damage_hooks(ctx)
	return maxi(1, ctx.raw_damage)


static func apply_damage(target: BattleUnitRuntime, amount: int) -> void:
	target.hp = maxi(0, target.hp - amount)
