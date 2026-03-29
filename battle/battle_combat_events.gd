extends RefCounted
class_name BattleCombatEvents
## 技能 / 伤害等结算事件名（StringName）。供特性等订阅：`event_sink.call(event, ctx, payload)`。


const SKILL_RESOLVE_STARTED := &"skill_resolve_started"
## 已通过目标校验与麻痹判定，已扣专注并调用 `on_after_caster_spent` 之后。
const FOCUS_SPENT := &"focus_spent"
## 单体目标因技能受到伤害（已写入 HP）；`payload` 含 `target`, `damage`, `hp_before`, `hp_after`。
const TARGET_TOOK_DAMAGE_FROM_SKILL := &"target_took_damage_from_skill"
## 施术者因技能回复生命（已写入 HP）；含 `heal_amount`, `hp_before`, `hp_after`。
const CASTER_HEALED_SELF := &"caster_healed_self"
## 无目标技能主段结束（治疗/集中精神等已应用）。
const SELF_SKILL_PRIMARY_DONE := &"self_skill_primary_done"
## 单体敌 / 单体友主段结束（含未命中时仅一条未命中台词的情况）。
const TARGETED_SKILL_PRIMARY_DONE := &"targeted_skill_primary_done"
## 整条 `apply_skill` 即将返回（冷却、自身速度、战报段已写入 `ctx.segments`）。
const SKILL_RESOLVE_FINISHED := &"skill_resolve_finished"
