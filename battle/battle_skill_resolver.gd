class_name BattleSkillResolver
extends RefCounted

const _Traits := preload("res://battle/battle_trait_resolver.gd")


static func roll_hit(skill: SkillData) -> bool:
	return randf() <= skill.hit_chance


static func compute_damage(attacker: BattleUnitRuntime, skill: SkillData, target: BattleUnitRuntime) -> int:
	var power: int = _Traits.effective_skill_power(attacker, skill)
	var raw: int = attacker.effective_atk() + power - target.effective_def()
	raw = _Traits.modify_raw_damage_swift(attacker, target, skill, raw)
	return maxi(1, raw)


static func apply_damage(target: BattleUnitRuntime, amount: int) -> void:
	target.hp = maxi(0, target.hp - amount)
