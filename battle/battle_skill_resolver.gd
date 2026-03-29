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
	ctx.raw_damage = attacker.effective_atk() + ctx.skill_power - target.effective_def()
	if skill.deals_damage:
		attacker.run_trait_raw_damage_hooks(ctx)
	return maxi(1, ctx.raw_damage)


static func apply_damage(target: BattleUnitRuntime, amount: int) -> void:
	target.hp = maxi(0, target.hp - amount)
