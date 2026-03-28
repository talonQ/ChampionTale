class_name BattleSkillResolver
extends RefCounted


static func roll_hit(skill: SkillData) -> bool:
	return randf() <= skill.hit_chance


static func compute_damage(attacker: BattleUnitRuntime, skill: SkillData, target: BattleUnitRuntime) -> int:
	var raw := attacker.effective_atk() + skill.power - target.effective_def()
	return maxi(1, raw)


static func apply_damage(target: BattleUnitRuntime, amount: int) -> void:
	target.hp = maxi(0, target.hp - amount)
