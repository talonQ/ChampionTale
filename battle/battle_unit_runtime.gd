class_name BattleUnitRuntime
extends RefCounted

const _BattleStatStageUtil := preload("res://battle/battle_stat_stage_util.gd")

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
var spatk_base: int = 10
var spdef_base: int = 5

var atk_stage: int = 0
var def_stage: int = 0
var spd_stage: int = 0
var spatk_stage: int = 0
var spdef_stage: int = 0

var focus: int = 30
var focus_max: int = 30

var skills: Array[SkillData] = []
## 本场携带的特性（自 `BattleUnitDefinition` 拷贝 Resource 引用）。
var traits: Array[TraitData] = []
## skill_id -> 剩余冷却回合数（按战斗回合递减）
var skill_cooldown_remaining: Dictionary = {}
var acted_this_round: bool = false
## BattleStatus.Kind -> true；本场战斗持续，直至被解除。
var active_statuses: Dictionary = {}

## 同速重排时使用的临时随机键，由战斗控制器每轮写入。
var sort_tiebreak: float = 0.0

## 伤害结算：威力阶段钩子 `{ "p": int, "c": Callable }`，`p` 越小越早执行。
var _trait_skill_power_hooks: Array[Dictionary] = []
## 伤害结算：粗伤阶段钩子（在 atk+power-def 之后）。
var _trait_raw_damage_hooks: Array[Dictionary] = []


func visual_lookup_id() -> int:
	return visual_asset_id if visual_asset_id > 0 else id


func is_alive() -> bool:
	return hp > 0


func effective_atk() -> int:
	return _BattleStatStageUtil.effective_stat(atk_base + level, atk_stage)


func effective_def() -> int:
	return _BattleStatStageUtil.effective_stat(def_base + level, def_stage)


func effective_spd() -> int:
	return _BattleStatStageUtil.effective_stat(spd_base + level, spd_stage)


func effective_spatk() -> int:
	return _BattleStatStageUtil.effective_stat(spatk_base + level, spatk_stage)


func effective_spdef() -> int:
	return _BattleStatStageUtil.effective_stat(spdef_base + level, spdef_stage)


func add_attack_stage(delta: int) -> void:
	atk_stage = _BattleStatStageUtil.clamp_stage(atk_stage + delta)


func add_defense_stage(delta: int) -> void:
	def_stage = _BattleStatStageUtil.clamp_stage(def_stage + delta)


func add_speed_stage(delta: int) -> void:
	spd_stage = _BattleStatStageUtil.clamp_stage(spd_stage + delta)


func add_spatk_stage(delta: int) -> void:
	spatk_stage = _BattleStatStageUtil.clamp_stage(spatk_stage + delta)


func add_spdef_stage(delta: int) -> void:
	spdef_stage = _BattleStatStageUtil.clamp_stage(spdef_stage + delta)


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


func clear_trait_damage_hooks() -> void:
	_trait_skill_power_hooks.clear()
	_trait_raw_damage_hooks.clear()


## `hook(ctx: BattleDamageModifyContext) -> void`
func register_trait_skill_power_hook(priority: int, hook: Callable) -> void:
	_trait_skill_power_hooks.append({"p": priority, "c": hook})
	_trait_skill_power_hooks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["p"]) < int(b["p"]))


## `hook(ctx: BattleDamageModifyContext) -> void`
func register_trait_raw_damage_hook(priority: int, hook: Callable) -> void:
	_trait_raw_damage_hooks.append({"p": priority, "c": hook})
	_trait_raw_damage_hooks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["p"]) < int(b["p"]))


func run_trait_skill_power_hooks(ctx: Variant) -> void:
	for entry in _trait_skill_power_hooks:
		var c: Callable = entry["c"]
		if c.is_valid():
			c.call(ctx)


func run_trait_raw_damage_hooks(ctx: Variant) -> void:
	for entry in _trait_raw_damage_hooks:
		var c: Callable = entry["c"]
		if c.is_valid():
			c.call(ctx)
