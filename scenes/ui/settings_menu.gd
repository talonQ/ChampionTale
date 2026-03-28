extends Control

const _BattleUiTheme := preload("res://ui/themes/champion_battle_theme.gd")
const SCENE_MAIN := "res://scenes/ui/main_menu.tscn"

## 预设窗口化分辨率（宽×高）。
const _RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _resolution_option: OptionButton = %ResolutionOption
@onready var _vsync_option: OptionButton = %VsyncOption
var _window_settings: ChampionWindowSettings
var _scene_transition: ChampionSceneTransition


func _ready() -> void:
	theme = _BattleUiTheme.build()
	_window_settings = get_tree().root.get_node_or_null("WindowSettings") as ChampionWindowSettings
	_scene_transition = get_tree().root.get_node_or_null("SceneTransition") as ChampionSceneTransition
	_fill_resolution_options()
	_fill_vsync_options()
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_resolution_option.item_selected.connect(_on_resolution_item_selected)
	_vsync_option.item_selected.connect(_on_vsync_item_selected)
	%BtnBack.pressed.connect(_on_back_pressed)
	_sync_ui_from_window()


func _fill_resolution_options() -> void:
	_resolution_option.clear()
	for r in _RESOLUTIONS:
		_resolution_option.add_item("%d × %d" % [r.x, r.y])


func _fill_vsync_options() -> void:
	_vsync_option.clear()
	_vsync_option.add_item("关闭")
	_vsync_option.add_item("开启")
	_vsync_option.add_item("自适应")


func _sync_ui_from_window() -> void:
	var mode := DisplayServer.window_get_mode()
	var fs := mode != DisplayServer.WINDOW_MODE_WINDOWED
	_fullscreen_check.set_pressed_no_signal(fs)
	var win := get_window()
	var sz := win.size
	var best_i := 0
	var best_d := 999999
	for i in range(_RESOLUTIONS.size()):
		var d: int = absi(sz.x - _RESOLUTIONS[i].x) + absi(sz.y - _RESOLUTIONS[i].y)
		if d < best_d:
			best_d = d
			best_i = i
	_resolution_option.select(best_i)
	var vs := DisplayServer.window_get_vsync_mode()
	_vsync_option.select(clampi(int(vs), 0, 2))
	_update_resolution_enabled()


func _update_resolution_enabled() -> void:
	_resolution_option.disabled = _fullscreen_check.button_pressed


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_apply_selected_resolution()
		get_window().move_to_center()
	_update_resolution_enabled()
	_save_current()


func _on_resolution_item_selected(_index: int) -> void:
	if _fullscreen_check.button_pressed:
		return
	_apply_selected_resolution()
	get_window().move_to_center()
	_save_current()


func _apply_selected_resolution() -> void:
	var i := clampi(_resolution_option.selected, 0, _RESOLUTIONS.size() - 1)
	var r: Vector2i = _RESOLUTIONS[i]
	get_window().size = r


func _on_vsync_item_selected(index: int) -> void:
	var vs: DisplayServer.VSyncMode = index as DisplayServer.VSyncMode
	DisplayServer.window_set_vsync_mode(vs)
	_save_current()


func _save_current() -> void:
	var mode := (
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if _fullscreen_check.button_pressed
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	var sz := get_window().size
	if _fullscreen_check.button_pressed:
		sz = _RESOLUTIONS[clampi(_resolution_option.selected, 0, _RESOLUTIONS.size() - 1)]
	if _window_settings != null:
		_window_settings.save_settings(mode, sz, int(_vsync_option.selected))


func _on_back_pressed() -> void:
	_save_current()
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_MAIN)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN)
