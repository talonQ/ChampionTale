extends RefCounted
class_name BattleTextUtil
## 战报用短名等纯文本工具（无循环依赖，可被规则层任意引用）。


static func unit_short_name(u: BattleUnitRuntime) -> String:
	var n := u.display_name
	var p := n.find("·")
	if p != -1 and p + 1 < n.length():
		return n.substr(p + 1).strip_edges()
	return n
