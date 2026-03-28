class_name SkillData
extends Resource

enum TargetKind {
	NONE,
	SINGLE_ENEMY,
	## 己方场上单体（含施术者自身）。
	SINGLE_ALLY,
}

@export var id: StringName
@export var display_name: String = "技能"
@export_multiline var description: String = ""
@export var focus_cost: int = 0
@export_range(0.0, 1.0) var hit_chance: float = 1.0
@export var power: int = 0
@export var cooldown_rounds: int = 0
@export var target_kind: TargetKind = TargetKind.SINGLE_ENEMY
## 为 false 时不造成伤害（命中仍可触发 target_speed_delta 等）。
@export var deals_damage: bool = true
## 仅 `TargetKind.NONE`：按最大生命比例治疗自身，不超过 `hp_max`；不掷命中。
@export_range(0.0, 1.0) var heal_self_max_hp_fraction: float = 0.0
## 仅 `TargetKind.SINGLE_ALLY`：按**目标**最大专注比例为其回复专注，不超过其专注上限；不造成伤害时不掷命中。
@export_range(0.0, 1.0) var restore_target_focus_max_fraction: float = 0.0
## 施放后给自身叠加的速度修正（本场战斗持续），用于验证「行动后重排」。
@export var self_speed_delta: int = 0
## 命中单体敌方后，对目标叠加的速度修正（本场持续）；负数即减速。
@export var target_speed_delta: int = 0
