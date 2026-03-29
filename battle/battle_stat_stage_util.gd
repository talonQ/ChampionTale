class_name BattleStatStageUtil
extends RefCounted
## 能力阶段倍率（Gen 6+）：`n≥0` → `(2+n)/2`，`n<0` → `2/(2-n)`；阶段 clamp 在 [−6, +6]。


const STAGE_MIN: int = -6
const STAGE_MAX: int = 6


static func clamp_stage(n: int) -> int:
	return clampi(n, STAGE_MIN, STAGE_MAX)


static func mult_for_stage(stage: int) -> float:
	var s := clamp_stage(stage)
	if s >= 0:
		return (2.0 + float(s)) / 2.0
	return 2.0 / (2.0 - float(s))


## `base_plus_level` 为已含等级等的整数和，再乘阶段倍率并取下整，至少为 1。
static func effective_stat(base_plus_level: int, stage: int) -> int:
	var m := mult_for_stage(stage)
	return maxi(1, int(floor(float(base_plus_level) * m)))
