class_name CombatRandomPoolDefinition
extends Resource
## 从同一宝可梦池无放回抽取：己方占槽位 1…N，敌方占 N+1…N+M（与 `CombatPrototypeDemo` 中站位一致）。


@export var unit_pool: Array[BattleUnitDefinition] = []
@export_range(1, 6, 1) var players_to_field: int = 3
@export_range(1, 6, 1) var enemies_to_field: int = 3
