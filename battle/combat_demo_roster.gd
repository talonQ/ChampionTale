class_name CombatDemoRoster
extends RefCounted
## 原型关卡的单位与技能配置（数据层，与场景无关）。


static func _mk_skill(
	p_id: StringName,
	p_name: String,
	p_cost: int,
	p_power: int,
	p_hit: float,
	p_cd: int,
	p_target: SkillData.TargetKind,
	p_spd_delta: int = 0,
) -> SkillData:
	var s := SkillData.new()
	s.id = p_id
	s.display_name = p_name
	s.focus_cost = p_cost
	s.power = p_power
	s.hit_chance = p_hit
	s.cooldown_rounds = p_cd
	s.target_kind = p_target
	s.self_speed_delta = p_spd_delta
	return s


static func create_units() -> Array[BattleUnitRuntime]:
	var u1 := BattleUnitRuntime.new()
	u1.id = 1
	u1.is_player_side = true
	u1.display_name = "训练家·卡兹克"
	u1.level = 6
	u1.hp_max = 72
	u1.hp = 72
	u1.atk_base = 14
	u1.def_base = 6
	u1.spd_base = 18
	u1.focus_max = 40
	u1.focus = 40
	u1.skills = [
		_mk_skill(&"u1_q", "虚空突刺", 8, 12, 0.92, 0, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u1_w", "虚空猛冲", 12, 22, 0.88, 2, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u1_e", "掠行", 6, 0, 1.0, 1, SkillData.TargetKind.NONE, 4),
	]
	var u2 := BattleUnitRuntime.new()
	u2.id = 2
	u2.is_player_side = true
	u2.display_name = "训练家·墨菲特"
	u2.level = 6
	u2.hp_max = 110
	u2.hp = 110
	u2.atk_base = 10
	u2.def_base = 14
	u2.spd_base = 8
	u2.focus_max = 32
	u2.focus = 32
	u2.skills = [
		_mk_skill(&"u2_q", "地震碎片", 6, 10, 0.95, 0, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u2_w", "雷霆拍击", 14, 18, 0.85, 2, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u2_e", "坚定意志", 5, 0, 1.0, 0, SkillData.TargetKind.NONE, 2),
	]
	var u3 := BattleUnitRuntime.new()
	u3.id = 3
	u3.is_player_side = false
	u3.display_name = "野生·赫卡里姆"
	u3.level = 6
	u3.hp_max = 88
	u3.hp = 88
	u3.atk_base = 13
	u3.def_base = 8
	u3.spd_base = 15
	u3.focus_max = 36
	u3.focus = 36
	u3.skills = [
		_mk_skill(&"u3_q", "暴走挥砍", 7, 11, 0.9, 0, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u3_w", "毁灭冲锋", 11, 20, 0.82, 2, SkillData.TargetKind.SINGLE_ENEMY),
	]
	var u4 := BattleUnitRuntime.new()
	u4.id = 4
	u4.is_player_side = false
	u4.display_name = "野生·菲兹"
	u4.level = 6
	u4.hp_max = 68
	u4.hp = 68
	u4.atk_base = 12
	u4.def_base = 7
	u4.spd_base = 16
	u4.focus_max = 38
	u4.focus = 38
	u4.skills = [
		_mk_skill(&"u4_q", "淘气打击", 8, 13, 0.91, 0, SkillData.TargetKind.SINGLE_ENEMY),
		_mk_skill(&"u4_w", "海石三叉戟", 10, 17, 0.86, 1, SkillData.TargetKind.SINGLE_ENEMY),
	]
	var arr: Array[BattleUnitRuntime] = []
	arr.append(u1)
	arr.append(u2)
	arr.append(u3)
	arr.append(u4)
	return arr
