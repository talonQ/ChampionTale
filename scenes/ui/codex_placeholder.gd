extends Control

const _BattleUiTheme := preload("res://ui/themes/champion_battle_theme.gd")
const SCENE_MAIN := "res://scenes/ui/main_menu.tscn"


@onready var _btn_back: Button = %BtnBack
var _scene_transition: ChampionSceneTransition


func _ready() -> void:
	theme = _BattleUiTheme.build()
	_scene_transition = get_tree().root.get_node_or_null("SceneTransition") as ChampionSceneTransition
	_btn_back.pressed.connect(_on_back_pressed)


func _on_back_pressed() -> void:
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_MAIN)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN)
