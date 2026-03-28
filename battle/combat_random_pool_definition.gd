class_name CombatRandomPoolDefinition
extends Resource
## 从同一宝可梦池无放回抽取，前若干只上场为己方（槽位 1、2），其余为敌方（槽位 3、4）。


@export var unit_pool: Array[BattleUnitDefinition] = []
@export_range(1, 4, 1) var players_to_field: int = 2
@export_range(1, 4, 1) var enemies_to_field: int = 2
