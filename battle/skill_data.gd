class_name SkillData
extends Resource

enum TargetKind {
	NONE,
	SINGLE_ENEMY,
}

@export var id: StringName
@export var display_name: String = "技能"
@export var focus_cost: int = 0
@export_range(0.0, 1.0) var hit_chance: float = 1.0
@export var power: int = 0
@export var cooldown_rounds: int = 0
@export var target_kind: TargetKind = TargetKind.SINGLE_ENEMY
## 施放后给自身叠加的速度修正（本场战斗持续），用于验证「行动后重排」。
@export var self_speed_delta: int = 0
