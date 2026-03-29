extends Control

const _BattleUiTheme := preload("res://ui/themes/champion_battle_theme.gd")
const SCENE_COMBAT := "res://scenes/combat/combat_prototype_demo.tscn"
const SCENE_CODEX := "res://scenes/ui/pokedex_screen.tscn"
const SCENE_SETTINGS := "res://scenes/ui/settings_menu.tscn"

@onready var _btn_start: Button = %BtnStart
@onready var _btn_codex: Button = %BtnCodex
@onready var _btn_settings: Button = %BtnSettings
@onready var _btn_quit: Button = %BtnQuit
var _scene_transition: ChampionSceneTransition


func _ready() -> void:
	theme = _BattleUiTheme.build()
	_scene_transition = get_tree().root.get_node_or_null("SceneTransition") as ChampionSceneTransition
	_btn_start.pressed.connect(_on_start_game_pressed)
	_btn_codex.pressed.connect(_on_codex_pressed)
	_btn_settings.pressed.connect(_on_settings_pressed)
	_btn_quit.pressed.connect(_on_quit_pressed)


func _on_start_game_pressed() -> void:
	if _scene_transition != null:
		await _scene_transition.fade_to_scene(SCENE_COMBAT)
	else:
		var err := get_tree().change_scene_to_file(SCENE_COMBAT)
		if err != OK:
			push_error("无法加载战斗场景：%s (%s)" % [SCENE_COMBAT, error_string(err)])


func _on_codex_pressed() -> void:
	if _scene_transition != null:
		await _scene_transition.fade_to_scene(SCENE_CODEX)
	else:
		var err := get_tree().change_scene_to_file(SCENE_CODEX)
		if err != OK:
			push_error("无法加载图鉴场景：%s (%s)" % [SCENE_CODEX, error_string(err)])


func _on_settings_pressed() -> void:
	if _scene_transition != null:
		await _scene_transition.fade_to_scene(SCENE_SETTINGS)
	else:
		var err := get_tree().change_scene_to_file(SCENE_SETTINGS)
		if err != OK:
			push_error("无法加载设置场景：%s (%s)" % [SCENE_SETTINGS, error_string(err)])


func _on_quit_pressed() -> void:
	get_tree().quit()
