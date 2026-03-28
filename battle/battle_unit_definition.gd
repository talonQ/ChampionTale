class_name BattleUnitDefinition
extends Resource
## 战斗外配置的单位模板（检查器 / .tres）；运行时由 CombatDemoRoster 转为 BattleUnitRuntime。


@export var unit_id: int = 1
## 对应场景里模型表（如 1=卡兹克）；固定遭遇里战场槽位按 roster 顺序另计，此项仍作默认模型键。≤0 的 visual_id 时用 unit_id 取模型。
@export var visual_id: int = 0
@export var is_player_side: bool = true
@export var display_name: String = "单位"
@export var level: int = 1
@export var hp_max: int = 100
@export var atk_base: int = 10
@export var def_base: int = 5
@export var spd_base: int = 10
@export var focus_max: int = 30
@export var skills: Array[SkillData] = []
