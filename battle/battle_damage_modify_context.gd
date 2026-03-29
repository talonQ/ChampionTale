class_name BattleDamageModifyContext
extends RefCounted
## 单次 `compute_damage` 流程内可被特性钩子读写的上下文（规则层，无 Node）。


var attacker: BattleUnitRuntime
var defender: BattleUnitRuntime
var skill: SkillData
## 起始于 `skill.power`；仅对伤害技能会跑「威力阶段」钩子。
var skill_power: int = 0
## 起始于「按技能分类取攻防后的有效值 + skill_power − 守方对应防御」；随后跑「粗伤阶段」钩子。
var raw_damage: int = 0
