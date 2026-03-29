class_name TraitData
extends Resource
## 宝可梦特性（检查器资源）。`kind` 决定生效逻辑，其余字段仅在同名分组下读取。


enum Kind {
	## 每回合全员行动完毕后，按最大生命比例回复（与中毒 DOT 同一大轮替时机）。
	REGEN_END_ROUND,
	## 满血时，技能威力部分翻倍（仅 `deals_damage` 的技能的 `power` 参与计算）。
	BULLY_FULL_HP_DOUBLE_POWER,
	## 造成伤害的攻击命中后，概率使目标中毒（与技能 `on_hit_status_effects` 独立判定）。
	POISON_SKIN,
	## 仅当己方有效速度高于目标时：按速度差提高伤害（倍率有上限）。
	SWIFT_SPEED_GAP,
	## 每回合全员行动完毕后，按最大专注比例回复专注。
	FOCUS_RESTORE_END_ROUND,
	## 每回合结束时：叠加攻击修正并降低防御修正（本场战斗持续叠加，各实例仅处理首个同类特性）。
	POWER_TOLL_END_ROUND,
}

@export var id: StringName
@export var display_name: String = "特性"
@export_multiline var description: String = ""
@export var kind: Kind = Kind.REGEN_END_ROUND

@export_group("回复力（REGEN_END_ROUND）")
@export_range(0.0, 1.0) var regen_max_hp_fraction: float = 0.08

@export_group("毒性皮肤（POISON_SKIN）")
@export_range(0.0, 1.0) var poison_skin_chance: float = 0.3

@export_group("迅疾（SWIFT_SPEED_GAP）")
## 每 1 点速度优势：`最终伤害倍率 += delta * 本值`（加法倍率，再乘到 raw 上）。
@export_range(0.0, 2.0) var swift_damage_mult_per_speed_point: float = 0.02
## 倍率加成上限（例如 0.5 表示最多 ×1.5）。
@export_range(0.0, 5.0) var swift_max_damage_mult_bonus: float = 0.5

@export_group("专注力（FOCUS_RESTORE_END_ROUND）")
@export_range(0.0, 1.0) var focus_restore_max_fraction: float = 0.16

@export_group("力量代价（POWER_TOLL_END_ROUND）")
## 每回合结束时 **攻击能力阶段** 变化。
@export var power_toll_atk_stage: int = 1
## 每回合结束时 **防御能力阶段** 变化（通常为负）。
@export var power_toll_def_stage: int = -1
