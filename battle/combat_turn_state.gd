class_name CombatTurnState
extends RefCounted
## 回合顺序与回合数等纯战斗状态（无 UI、无 3D）。


var units: Array[BattleUnitRuntime] = []
var round_number: int = 1


func get_alive_units() -> Array[BattleUnitRuntime]:
	var out: Array[BattleUnitRuntime] = []
	for u in units:
		if u.is_alive():
			out.append(u)
	return out


func eligible_for_round() -> Array[BattleUnitRuntime]:
	var out: Array[BattleUnitRuntime] = []
	for u in get_alive_units():
		if not u.acted_this_round:
			out.append(u)
	return out


func sort_eligible_by_speed(eligible: Array[BattleUnitRuntime]) -> void:
	for u in eligible:
		u.sort_tiebreak = randf()
	eligible.sort_custom(func(a: BattleUnitRuntime, b: BattleUnitRuntime) -> bool:
		var sa := a.effective_spd()
		var sb := b.effective_spd()
		if sa != sb:
			return sa > sb
		return a.sort_tiebreak > b.sort_tiebreak
	)


func get_next_actor() -> BattleUnitRuntime:
	var el := eligible_for_round()
	if el.is_empty():
		return null
	sort_eligible_by_speed(el)
	return el[0]


func tick_new_round() -> void:
	for u in units:
		u.acted_this_round = false
	for u in get_alive_units():
		for s in u.skills:
			var k: StringName = s.id
			var rem: int = int(u.skill_cooldown_remaining.get(k, 0))
			if rem > 0:
				u.skill_cooldown_remaining[k] = rem - 1
	round_number += 1


enum BattleOutcome { ONGOING, ALL_PLAYER_DEAD, ALL_ENEMY_DEAD }


func battle_outcome() -> BattleOutcome:
	var p_alive := false
	var e_alive := false
	for u in get_alive_units():
		if u.is_player_side:
			p_alive = true
		else:
			e_alive = true
	if not p_alive:
		return BattleOutcome.ALL_PLAYER_DEAD
	if not e_alive:
		return BattleOutcome.ALL_ENEMY_DEAD
	return BattleOutcome.ONGOING


func is_battle_ongoing() -> bool:
	return battle_outcome() == BattleOutcome.ONGOING


func is_all_player_dead() -> bool:
	return battle_outcome() == BattleOutcome.ALL_PLAYER_DEAD


func is_all_enemy_dead() -> bool:
	return battle_outcome() == BattleOutcome.ALL_ENEMY_DEAD
