class_name ChampionSceneTransition
extends CanvasLayer
## Autoload：场景切换时淡入淡出（全屏遮罩），不随 `change_scene` 卸载。
## 在工程 `项目 → Autoload` 中应命名为 `SceneTransition`。


@export_range(0.05, 1.5, 0.01, "suffix:s") var fade_out_sec: float = 0.22
@export_range(0.05, 1.5, 0.01, "suffix:s") var fade_in_sec: float = 0.26

var _overlay: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.06, 0.08, 0.12, 1.0)
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func fade_to_scene(scene_path: String) -> void:
	if _busy:
		return
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_overlay, "modulate:a", 1.0, fade_out_sec)
	await tw.finished
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneTransition: 无法加载场景：%s" % scene_path)
		_busy = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw_fail := create_tween()
		tw_fail.tween_property(_overlay, "modulate:a", 0.0, fade_in_sec)
		return
	_overlay.modulate.a = 1.0
	var tw2 := create_tween()
	tw2.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_property(_overlay, "modulate:a", 0.0, fade_in_sec)
	await tw2.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
