class_name BattleTraitHookInstaller
extends RefCounted
## 在单位生成后，把各 `TraitData` 的伤害相关逻辑注册到 `BattleUnitRuntime` 的钩子上。
## 新增伤害类特性：在此 `match` 增加分支并调用私有 `_register_*`（或独立脚本中的 install）。


static func install_for_unit(u: BattleUnitRuntime) -> void:
	u.clear_trait_damage_hooks()
	var seen_power_kind: Dictionary = {}
	var seen_raw_kind: Dictionary = {}
	for trait_res in u.traits:
		if trait_res == null:
			continue
		match trait_res.kind:
			TraitData.Kind.BULLY_FULL_HP_DOUBLE_POWER:
				if seen_power_kind.get(trait_res.kind, false):
					continue
				seen_power_kind[trait_res.kind] = true
				_register_bully_double_power(u, trait_res)
			TraitData.Kind.SWIFT_SPEED_GAP:
				if seen_raw_kind.get(trait_res.kind, false):
					continue
				seen_raw_kind[trait_res.kind] = true
				_register_swift_speed_gap(u, trait_res)
			_:
				pass


static func _register_bully_double_power(owner: BattleUnitRuntime, _trait: TraitData) -> void:
	owner.register_trait_skill_power_hook(
		100,
		func(ctx: Variant) -> void:
			if ctx.attacker != owner:
				return
			if not ctx.skill.deals_damage:
				return
			if owner.hp >= owner.hp_max:
				ctx.skill_power *= 2
	)


static func _register_swift_speed_gap(owner: BattleUnitRuntime, trait_data: TraitData) -> void:
	owner.register_trait_raw_damage_hook(
		50,
		func(ctx: Variant) -> void:
			if ctx.attacker != owner:
				return
			if not ctx.skill.deals_damage:
				return
			var sa := owner.effective_spd()
			var sd: int = ctx.defender.effective_spd()
			if sa <= sd:
				return
			var delta: int = sa - sd
			var bonus: float = minf(
				trait_data.swift_max_damage_mult_bonus,
				float(delta) * trait_data.swift_damage_mult_per_speed_point,
			)
			ctx.raw_damage = int(round(float(ctx.raw_damage) * (1.0 + bonus)))
	)
