class_name BattleUnitRuntime
extends RefCounted

var id: int = 0
## 与 `_VISUAL_BY_UNIT_ID` 对应；≤0 时用 `id`（固定遭遇与旧数据兼容）。
var visual_asset_id: int = 0
var is_player_side: bool = true
var display_name: String = "Unit"
var level: int = 1

var hp: int = 100
var hp_max: int = 100

var atk_base: int = 10
var def_base: int = 5
var spd_base: int = 10

var atk_mod: int = 0
var def_mod: int = 0
var spd_mod: int = 0

var focus: int = 30
var focus_max: int = 30

var skills: Array[SkillData] = []
## skill_id -> 剩余冷却回合数（按战斗回合递减）
var skill_cooldown_remaining: Dictionary = {}
var acted_this_round: bool = false
## BattleStatus.Kind -> true；本场战斗持续，直至被解除。
var active_statuses: Dictionary = {}

## 同速重排时使用的临时随机键，由战斗控制器每轮写入。
var sort_tiebreak: float = 0.0


func visual_lookup_id() -> int:
	return visual_asset_id if visual_asset_id > 0 else id


func is_alive() -> bool:
	return hp > 0


func effective_atk() -> int:
	return maxi(1, atk_base + atk_mod + level)


func effective_def() -> int:
	return maxi(1, def_base + def_mod)


func effective_spd() -> int:
	return maxi(1, spd_base + spd_mod)


func skill_cooldown(skill: SkillData) -> int:
	return int(skill_cooldown_remaining.get(skill.id, 0))


func can_pay_focus(skill: SkillData) -> bool:
	return focus >= skill.focus_cost


func can_use_skill(skill: SkillData) -> bool:
	return is_alive() and skill_cooldown(skill) <= 0 and can_pay_focus(skill)


func add_focus(amount: int) -> void:
	focus = mini(focus_max, focus + amount)


func spend_focus(amount: int) -> void:
	focus = maxi(0, focus - amount)


func has_status(kind: BattleStatus.Kind) -> bool:
	return active_statuses.get(kind, false)


func set_status(kind: BattleStatus.Kind, enabled: bool) -> void:
	if enabled:
		active_statuses[kind] = true
	else:
		active_statuses.erase(kind)
