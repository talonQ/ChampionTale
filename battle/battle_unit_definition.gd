class_name BattleUnitDefinition
extends Resource
## 战斗外配置的单位模板（检查器 / .tres）；运行时由 CombatDemoRoster 转为 BattleUnitRuntime。

const _TraitData := preload("res://battle/trait_data.gd")

@export var unit_id: int = 1
## 对应场景里模型表（如 1=卡兹克）；固定遭遇里战场槽位按 roster 顺序另计，此项仍作默认模型键。≤0 的 visual_id 时用 unit_id 取模型。
@export var visual_id: int = 0
@export var is_player_side: bool = true
@export var display_name: String = "单位"
@export var level: int = 1
@export var hp_max: int = 100
@export var atk_base: int = 10
@export var def_base: int = 5
## 种族值特攻；小于 0 时图鉴显示为与 `atk_base` 相同（战斗数值暂不区分物/特）。
@export var spatk_base: int = -1
## 种族值特防；小于 0 时图鉴显示为与 `def_base` 相同。
@export var spdef_base: int = -1
@export var spd_base: int = 10
@export var focus_max: int = 30
## 可学习技能池；生成战斗单位时从中无放回随机挑选至多 2 个作为本场携带技能（不含「休息」）。
@export var learnable_skills: Array[SkillData] = []
## 兼容旧资源：仅当 `learnable_skills` 为空时，按顺序取自此处，仍最多 2 个。
@export var skills: Array[SkillData] = []
## 该宝可梦绑定的特性（通常 0～1 个；多个时按顺序各规则自行处理）。
@export var traits: Array[_TraitData] = []
