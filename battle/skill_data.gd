class_name SkillData
extends Resource

const _SkillOnHitEffect := preload("res://battle/skill_on_hit_effect.gd")

enum TargetKind {
	NONE,
	SINGLE_ENEMY,
	## 己方场上单体（含施术者自身）。
	SINGLE_ALLY,
}

## 伤害技能用于选取 **物攻/物防** 或 **特攻/特防**；变化类不参与攻防配对（见 `docx/battle-stat-stages.md`）。
enum MoveCategory {
	PHYSICAL,
	SPECIAL,
	STATUS,
}

@export var id: StringName
@export var display_name: String = "技能"
@export_multiline var description: String = ""
@export var focus_cost: int = 0
@export_range(0.0, 1.0) var hit_chance: float = 1.0
@export var power: int = 0
@export var cooldown_rounds: int = 0
@export var target_kind: TargetKind = TargetKind.SINGLE_ENEMY
@export var move_category: MoveCategory = MoveCategory.PHYSICAL
## 为 false 时不造成伤害（单体敌方/友方仍掷命中；命中后可触发速度阶段、`on_hit_status_effects`）。
@export var deals_damage: bool = true
## 仅 `TargetKind.NONE`：按最大生命比例治疗自身，不超过 `hp_max`；不掷命中。
@export_range(0.0, 1.0) var heal_self_max_hp_fraction: float = 0.0
## 仅 `TargetKind.SINGLE_ALLY`：按**目标**最大专注比例为其回复专注，不超过其专注上限；不造成伤害时不掷命中。
@export_range(0.0, 1.0) var restore_target_focus_max_fraction: float = 0.0
## 施放后使自身 **速度能力阶段** 变化（本场持续，clamp ±6）。
@export var self_speed_stage_delta: int = 0
## 命中可结算目标后，使其 **速度能力阶段** 变化（本场持续）。
@export var target_speed_stage_delta: int = 0
## 命中可结算的目标后依次判定；与速度阶段等在同一结算段内执行。
@export var on_hit_status_effects: Array[_SkillOnHitEffect] = []
