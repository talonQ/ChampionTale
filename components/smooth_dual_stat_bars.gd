class_name SmoothDualStatBars
extends RefCounted
## 用 Tween 将两条 ProgressBar 的 value 平滑过渡到目标比例（0～max_value）。
## 不依赖战斗类型；需要传入可 create_tween 的 Node（一般为条所在的 Control 祖先）。

const DEFAULT_DURATION_SEC := 0.42
const DEFAULT_TRANS := Tween.TRANS_CUBIC
const DEFAULT_EASE := Tween.EASE_OUT

var _host: Node
var _hp_bar: ProgressBar
var _focus_bar: ProgressBar
var _tween: Tween = null


func _init(p_host: Node, hp_bar: ProgressBar, focus_bar: ProgressBar) -> void:
	_host = p_host
	_hp_bar = hp_bar
	_focus_bar = focus_bar


func snap_to(hp_value: float, focus_value: float) -> void:
	_kill_active_tween()
	if is_instance_valid(_hp_bar):
		_hp_bar.value = hp_value
	if is_instance_valid(_focus_bar):
		_focus_bar.value = focus_value


## 同时过渡 HP 与专注；duration_sec ≤ 0 时等价于 snap_to。
func tween_to(hp_value: float, focus_value: float, duration_sec: float = DEFAULT_DURATION_SEC) -> void:
	var hp_t := hp_value
	var fo_t := focus_value
	if is_instance_valid(_hp_bar):
		hp_t = clampf(hp_value, _hp_bar.min_value, _hp_bar.max_value)
	if is_instance_valid(_focus_bar):
		fo_t = clampf(focus_value, _focus_bar.min_value, _focus_bar.max_value)
	if duration_sec <= 0.0 or not is_instance_valid(_host):
		snap_to(hp_t, fo_t)
		return
	_kill_active_tween()
	_tween = _host.create_tween()
	_tween.set_parallel(true)
	if is_instance_valid(_hp_bar):
		_tween.tween_property(_hp_bar, "value", hp_t, duration_sec).set_trans(DEFAULT_TRANS).set_ease(DEFAULT_EASE)
	if is_instance_valid(_focus_bar):
		_tween.tween_property(_focus_bar, "value", fo_t, duration_sec).set_trans(DEFAULT_TRANS).set_ease(DEFAULT_EASE)


func _kill_active_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
