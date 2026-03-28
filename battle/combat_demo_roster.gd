class_name CombatDemoRoster
extends RefCounted
## 将 CombatEncounterDefinition / BattleUnitDefinition 转为运行时 BattleUnitRuntime。


const DEFAULT_ENCOUNTER := preload("res://battle/definitions/demo_encounter.tres")


static func create_units(encounter: CombatEncounterDefinition = null) -> Array[BattleUnitRuntime]:
	var enc: CombatEncounterDefinition = encounter if encounter != null else DEFAULT_ENCOUNTER
	var out: Array[BattleUnitRuntime] = []
	for def in enc.roster:
		if def != null:
			out.append(runtime_from_definition(def))
	return out


static func create_units_from_random_pool(
	pool: CombatRandomPoolDefinition,
	rng: RandomNumberGenerator,
) -> Array[BattleUnitRuntime]:
	if pool == null:
		push_warning("CombatDemoRoster: random_pool 为空，使用默认遭遇。")
		return create_units(null)
	var need := pool.players_to_field + pool.enemies_to_field
	var picked := _pick_n_without_replacement(pool.unit_pool, need, rng)
	if picked.size() < need:
		push_warning("CombatDemoRoster: 随机池人数不足，使用默认遭遇。")
		return create_units(null)
	var picked_p: Array[BattleUnitDefinition] = []
	for i in range(pool.players_to_field):
		picked_p.append(picked[i])
	var picked_e: Array[BattleUnitDefinition] = []
	for i in range(pool.enemies_to_field):
		picked_e.append(picked[pool.players_to_field + i])
	var out: Array[BattleUnitRuntime] = []
	var slot := 1
	for def in picked_p:
		out.append(runtime_from_template(def, slot, true))
		slot += 1
	slot = 3
	for def in picked_e:
		out.append(runtime_from_template(def, slot, false))
		slot += 1
	return out


static func _pick_n_without_replacement(
	pool: Array[BattleUnitDefinition],
	n: int,
	rng: RandomNumberGenerator,
) -> Array[BattleUnitDefinition]:
	var p: Array[BattleUnitDefinition] = []
	for x in pool:
		if x != null:
			p.append(x)
	if p.is_empty():
		return []
	n = mini(maxi(n, 0), p.size())
	if n == 0:
		return []
	for i in range(p.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: BattleUnitDefinition = p[i]
		p[i] = p[j]
		p[j] = t
	p.resize(n)
	return p


static func runtime_from_template(
	def: BattleUnitDefinition,
	battle_slot_id: int,
	player_side: bool,
) -> BattleUnitRuntime:
	var u := BattleUnitRuntime.new()
	u.id = battle_slot_id
	u.is_player_side = player_side
	u.visual_asset_id = def.visual_id if def.visual_id > 0 else def.unit_id
	u.display_name = def.display_name
	u.level = def.level
	u.hp_max = def.hp_max
	u.hp = def.hp_max
	u.atk_base = def.atk_base
	u.def_base = def.def_base
	u.spd_base = def.spd_base
	u.focus_max = def.focus_max
	u.focus = def.focus_max
	u.skills = []
	for s in def.skills:
		if s != null:
			u.skills.append(s)
	return u


static func runtime_from_definition(def: BattleUnitDefinition) -> BattleUnitRuntime:
	var u := BattleUnitRuntime.new()
	u.id = def.unit_id
	u.visual_asset_id = def.visual_id if def.visual_id > 0 else 0
	u.is_player_side = def.is_player_side
	u.display_name = def.display_name
	u.level = def.level
	u.hp_max = def.hp_max
	u.hp = def.hp_max
	u.atk_base = def.atk_base
	u.def_base = def.def_base
	u.spd_base = def.spd_base
	u.focus_max = def.focus_max
	u.focus = def.focus_max
	u.skills = []
	for s in def.skills:
		if s != null:
			u.skills.append(s)
	return u
