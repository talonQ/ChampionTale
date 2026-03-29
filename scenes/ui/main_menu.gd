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
		_scene_transition.fade_to_scene(SCENE_COMBAT)
	else:
		get_tree().change_scene_to_file(SCENE_COMBAT)


func _on_codex_pressed() -> void:
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_CODEX)
	else:
		get_tree().change_scene_to_file(SCENE_CODEX)


func _on_settings_pressed() -> void:
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_SETTINGS)
	else:
		get_tree().change_scene_to_file(SCENE_SETTINGS)


func _on_quit_pressed() -> void:
	get_tree().quit()
