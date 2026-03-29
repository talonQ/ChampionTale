class_name SkillResolveContext
extends RefCounted
## 单次技能结算的共享状态（规则层）；表现层通过 Callable 与 `event_sink` 接入。


var actor: BattleUnitRuntime
var skill: SkillData
var targets: Array[BattleUnitRuntime] = []

## 战报链：与原先 `apply_skill` 返回的 `Array[String]` 一致，一段对应台词链中的一条。
var segments: Array[String] = []

var opener: String = ""

var on_unit_changed: Callable
var on_after_caster_spent: Callable
var on_turn_completed: Callable
var on_hp_healed: Callable
## `func(event: StringName, ctx: SkillResolveContext, payload: Dictionary) -> void`
var event_sink: Callable = Callable()


func emit(event_name: StringName, payload: Dictionary = {}) -> void:
	if not event_sink.is_valid():
		return
	payload["actor"] = actor
	payload["skill"] = skill
	payload["targets"] = targets
	event_sink.call(event_name, self, payload)
