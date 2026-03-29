extends Resource
class_name SkillOnHitEffect
## 技能命中目标时可叠加的异常（由检查器配置，便于扩展更多种类）。

const _BS := preload("res://battle/battle_status.gd")

@export var status: _BS.Kind = _BS.Kind.POISON
@export_range(0.0, 1.0) var chance: float = 1.0
