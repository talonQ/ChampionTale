extends RefCounted
class_name BattleStatus
## 异常状态 ID 与规则常量（纯数据 / 骰子；不引用场景）。


enum Kind {
	## 回合轮替时（全员行动完毕后）按最大生命比例受伤。
	POISON,
	## 行动结算前有概率无法行动（仍参与排序）；不消耗当次技能的专注。
	PARALYSIS,
}

const POISON_MAX_HP_FRACTION_PER_ROUND: float = 0.16
## 与常见宝可梦设定一致：当次行动无法执行的概率。
const PARALYSIS_ACTION_FAIL_CHANCE: float = 0.5


static func roll_paralysis_blocks_action() -> bool:
	return randf() < PARALYSIS_ACTION_FAIL_CHANCE


static func status_display_name(kind: Kind) -> String:
	match kind:
		Kind.POISON:
			return "中毒"
		Kind.PARALYSIS:
			return "麻痹"
		_:
			return "异常"
