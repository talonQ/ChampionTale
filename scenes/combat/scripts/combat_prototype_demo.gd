extends Node
## 战斗原型场景根节点：串联 **CombatTurnState（规则）** 与 **表现层控制器**（台词、条、3D 槽位）。

@export_group("Battle text (typewriter)")
@export_range(4.0, 120.0, 1.0, "suffix:字/秒") var battle_text_chars_per_second: float = 18.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var battle_text_read_pause_sec: float = 1.5

@export_group("Unit bars")
@export_range(0.0, 3.0, 0.05, "suffix:s") var unit_bar_tween_duration_sec: float = 0.45
@export_range(0.5, 8.0, 0.05, "suffix:m") var unit_bar_world_offset_y: float = 2.15
@export_range(48.0, 220.0, 1.0, "suffix:px") var unit_bar_panel_min_width: float = 60.0
@export_range(24.0, 100.0, 1.0, "suffix:px") var unit_bar_panel_min_height: float = 16.0
@export_range(48.0, 220.0, 1.0, "suffix:px") var unit_bar_hp_width: float = 40.0
@export_range(6.0, 28.0, 0.5, "suffix:px") var unit_bar_hp_height: float = 5.0
@export_range(48.0, 220.0, 1.0, "suffix:px") var unit_bar_focus_width: float = 40.0
@export_range(6.0, 24.0, 0.5, "suffix:px") var unit_bar_focus_height: float = 3.0
@export_range(0, 16, 1) var unit_bar_row_separation: int = 1
@export_range(0.0, 32.0, 0.5, "suffix:px") var unit_bar_screen_margin_px: float = 4.0

@export_group("Turn order strip")
@export_range(32, 96, 1, "suffix:px") var turn_order_icon_size: int = 44
@export_range(0, 24, 1, "suffix:px") var turn_order_separation: int = 8
@export_range(0.0, 1.5, 0.02, "suffix:s") var turn_order_anim_duration_sec: float = 0.38

@export_group("Battle data")
## 留空则使用 `battle/definitions/demo_encounter.tres`；可在检查器指定其它 CombatEncounterDefinition。
@export var encounter: CombatEncounterDefinition
## 开启后从 `random_pool.unit_pool` 无放回抽取（先己方槽 1…N，再敌方 N+1…）。
@export var use_random_roster: bool = false
@export var random_pool: CombatRandomPoolDefinition
## 非负时固定种子便于复现；负值则每次开局随机。
@export var random_seed: int = -1

const _SLOT_SCENE := preload("res://scenes/combat/battle_creature_slot.tscn")
const _HEAL_BURST_VFX := preload("res://scenes/vfx/heal_burst_vfx.tscn")
const _CombatTurnState := preload("res://battle/combat_turn_state.gd")
const _CombatDemoRoster := preload("res://battle/combat_demo_roster.gd")
const _CombatActionExecutor := preload("res://battle/combat_action_executor.gd")
const _CombatNarrationController := preload("res://scenes/combat/scripts/combat_narration_controller.gd")
const _CombatUnitBarsController := preload("res://scenes/combat/scripts/combat_unit_bars_controller.gd")
const _CombatBattlePick := preload("res://scenes/combat/scripts/combat_battle_pick.gd")
const _CombatUnitTooltipText := preload("res://scenes/combat/scripts/combat_unit_tooltip_text.gd")
const _CombatSkillTooltipText := preload("res://scenes/combat/scripts/combat_skill_tooltip_text.gd")
const _CombatTurnOrderStrip := preload("res://scenes/combat/scripts/combat_turn_order_strip.gd")
const _BattleUiTheme := preload("res://ui/themes/champion_battle_theme.gd")
## 行动条圆圈内贴图（与 visual_lookup_id 对应）；由 `portrait.png`（自 WebP 转换）；缺项则用名字首字占位。
const _STRIP_TEX_BY_VISUAL_ID: Dictionary = {
	1: preload("res://assets/pokemon/khazix/portrait.png"),
	2: preload("res://assets/pokemon/malphite/portrait.png"),
	3: preload("res://assets/pokemon/hecarim/portrait.png"),
	4: preload("res://assets/pokemon/fizz/portrait.png"),
	5: preload("res://assets/pokemon/renekton/portrait.png"),
	6: preload("res://assets/pokemon/trundle/portrait.png"),
	7: preload("res://assets/pokemon/volibear/portrait.png"),
	8: preload("res://assets/pokemon/wukong/portrait.png"),
}
const _VISUAL_BY_UNIT_ID := {
	1: preload("res://assets/pokemon/khazix/avatar.tscn"),
	2: preload("res://assets/pokemon/malphite/avatar.tscn"),
	3: preload("res://assets/pokemon/hecarim/avatar.tscn"),
	4: preload("res://assets/pokemon/fizz/avatar.tscn"),
	5: preload("res://assets/pokemon/renekton/avatar.tscn"),
	6: preload("res://assets/pokemon/trundle/avatar.tscn"),
	7: preload("res://assets/pokemon/volibear/avatar.tscn"),
	8: preload("res://assets/pokemon/wukong/avatar.tscn"),
}
## 各 `unit.id` 在战场上的本地坐标（`BattleField` 子节点）。Z 绝对值越小，敌我两排越近。
@export var slot_position_z: float = 2.6
var _SLOT_POSITION := {
	1: Vector3(-3.6, 0, slot_position_z),
	2: Vector3(0, 0, slot_position_z),
	3: Vector3(3.6, 0, slot_position_z),
	4: Vector3(-3.6, 0, -slot_position_z),
	5: Vector3(0, 0, -slot_position_z),
	6: Vector3(3.6, 0, -slot_position_z),
}
const SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const _SCENE_MAIN_MENU := "res://scenes/ui/main_menu.tscn"

@onready var _battle_message: RichTextLabel = %BattleMessageText
@onready var _btn_rest: Button = %BtnRest
@onready var _skill_buttons: VBoxContainer = %SkillButtons
@onready var _right_action_dock: Control = %RightActionDock
@onready var _battle_tooltip: PanelContainer = %BattleTooltip
@onready var _tooltip_text: RichTextLabel = %TooltipText
@onready var _battle_hud_root: Control = %BattleHudRoot
@onready var _unit_bars_root: Control = %UnitBarsRoot
@onready var _turn_order_strip_root: Control = %TurnOrderStrip
@onready var _camera_3d: Camera3D = %BattleCamera
@onready var _battle_field: Node3D = %BattleField
@onready var _outline_post: Node = $OutlinePost
@onready var _battle_result_layer: CanvasLayer = %BattleResultLayer
@onready var _battle_result_title: Label = %BattleResultTitle
@onready var _battle_result_subtitle: Label = %BattleResultSubtitle
@onready var _battle_result_return: Button = %BattleResultReturnBtn

var _state = _CombatTurnState.new()
var _narration
var _bars
var _turn_strip

var units: Array[BattleUnitRuntime]:
	get:
		return _state.units

var round_number: int:
	get:
		return _state.round_number

var _busy: bool = false
var _player_actor: BattleUnitRuntime
enum _PickPhase { NONE, SKILL_TARGET }
var _pick_phase: _PickPhase = _PickPhase.NONE
var _pending_skill: SkillData
var _highlight_actor: BattleUnitRuntime
var _slots_by_unit_id: Dictionary = {}
var _skill_target_pick_hover_id: int = -1
var _scene_transition: ChampionSceneTransition
## 为 true 时 Tooltip 放在指针左侧（右侧技能栏），避免挡住按钮。
var _battle_tooltip_place_left: bool = false


func _ready() -> void:
	_battle_message.bbcode_enabled = false
	_scene_transition = get_tree().root.get_node_or_null("SceneTransition") as ChampionSceneTransition
	_apply_battle_ui_theme()
	var rng := RandomNumberGenerator.new()
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	if use_random_roster and random_pool != null:
		_state.units = _CombatDemoRoster.create_units_from_random_pool(random_pool, rng)
	else:
		_state.units = _CombatDemoRoster.create_units(encounter, rng)
	_narration = _CombatNarrationController.new(_battle_message)
	_narration.chars_per_second = battle_text_chars_per_second
	_narration.read_pause_after_line_sec = battle_text_read_pause_sec
	_bars = _CombatUnitBarsController.new(_unit_bars_root, _camera_3d)
	_bars.bar_offset_world_y = unit_bar_world_offset_y
	_bars.tween_duration_sec = unit_bar_tween_duration_sec
	_bars.panel_min_size = Vector2(unit_bar_panel_min_width, unit_bar_panel_min_height)
	_bars.hp_bar_min_size = Vector2(unit_bar_hp_width, unit_bar_hp_height)
	_bars.focus_bar_min_size = Vector2(unit_bar_focus_width, unit_bar_focus_height)
	_bars.bars_vertical_separation = unit_bar_row_separation
	_bars.screen_anchor_margin_px = unit_bar_screen_margin_px
	_turn_strip = _CombatTurnOrderStrip.new(
		_turn_order_strip_root,
		turn_order_icon_size,
		turn_order_separation,
		turn_order_anim_duration_sec,
	)
	_btn_rest.pressed.connect(_on_rest_pressed)
	_spawn_3d_slots()
	_bars.clear_and_rebuild(_state.units)
	_refresh_turn_order_strip()
	_set_actions_enabled(false)
	_narration.start_chain(PackedStringArray(["战斗开始！"]), func() -> void:
		call_deferred("_advance_battle")
	)
	_battle_result_layer.visible = false
	_battle_result_return.pressed.connect(_on_battle_result_return_pressed)
	var result_panel := _battle_result_layer.get_node_or_null(^"Center/Panel") as PanelContainer
	if result_panel != null:
		result_panel.theme = _BattleUiTheme.build()


func _apply_battle_ui_theme() -> void:
	var ui_theme: Theme = _BattleUiTheme.build()
	_battle_hud_root.theme = ui_theme
	_unit_bars_root.theme = ui_theme
	_battle_tooltip.theme = ui_theme
	_battle_tooltip.theme_type_variation = &"BattleTooltipPanel"
	var top_bar := get_node_or_null(^"TurnOrderLayer/TopBar") as Control
	if top_bar != null:
		top_bar.theme = ui_theme


func _process(delta: float) -> void:
	_narration.process_frame(delta)
	_bars.update_screen_positions(_state.units, _slots_by_unit_id)
	_update_skill_target_pick_highlight()
	_update_hover_tooltip()


func _on_unit_stats_changed(u: BattleUnitRuntime) -> void:
	_bars.sync_unit_values(u)
	_refresh_turn_order_strip()


func _notify_slot_skill_cast(actor: BattleUnitRuntime, skill: SkillData, targets: Array[BattleUnitRuntime]) -> void:
	var slot: Variant = _slots_by_unit_id.get(actor.id)
	if slot == null or not slot.has_method("notify_skill_cast"):
		return
	if (
		(
			skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY
			or skill.target_kind == SkillData.TargetKind.SINGLE_ALLY
		)
		and not targets.is_empty()
	):
		var target_slot: Variant = _slots_by_unit_id.get(targets[0].id)
		if target_slot is Node3D:
			slot.notify_skill_cast((target_slot as Node3D).global_position)
			return
	slot.notify_skill_cast()


func _on_hp_healed_visual(target: BattleUnitRuntime, _amount: int) -> void:
	var slot: Variant = _slots_by_unit_id.get(target.id)
	if slot == null:
		return
	var vfx := _HEAL_BURST_VFX.instantiate() as Node3D
	_battle_field.add_child(vfx)
	vfx.global_position = (slot as Node3D).global_position + Vector3(0.0, 1.05, 0.0)


func _set_actions_enabled(on: bool) -> void:
	_right_action_dock.visible = true
	_right_action_dock.modulate.a = 1.0 if on else 0.0
	_right_action_dock.mouse_filter = Control.MOUSE_FILTER_PASS if on else Control.MOUSE_FILTER_IGNORE
	_btn_rest.disabled = not on
	for c in _skill_buttons.get_children():
		if c is Button:
			c.disabled = not on


func _sync_ui_after_state() -> void:
	_sync_3d_visuals()
	_bars.sync_all_units(_state.units)
	_refresh_turn_order_strip()


func _refresh_turn_order_strip() -> void:
	if _turn_strip == null:
		return
	_turn_strip.sync(
		_state.get_turn_order_strip_units(),
		_highlight_actor,
		Callable(self, "_strip_portrait_for_unit"),
	)


func _strip_portrait_for_unit(u: BattleUnitRuntime) -> Texture2D:
	var v: Variant = _STRIP_TEX_BY_VISUAL_ID.get(u.visual_lookup_id(), null)
	return v as Texture2D


func _on_turn_completed(actor: BattleUnitRuntime) -> void:
	_state.note_turn_completed(actor)


func _spawn_3d_slots() -> void:
	for c in _battle_field.get_children():
		c.queue_free()
	_slots_by_unit_id.clear()
	for u in _state.units:
		var slot: Node3D = _SLOT_SCENE.instantiate()
		_battle_field.add_child(slot)
		var vis: PackedScene = _VISUAL_BY_UNIT_ID.get(u.visual_lookup_id(), null)
		slot.setup(u, vis)
		slot.position = _SLOT_POSITION.get(u.id, Vector3.ZERO)
		if u.is_player_side:
			slot.rotation_degrees = Vector3(0, 180, 0)
		else:
			slot.rotation_degrees = Vector3(0, 0, 0)
		_slots_by_unit_id[u.id] = slot


func _sync_3d_visuals() -> void:
	for u in _state.units:
		var slot = _slots_by_unit_id.get(u.id)
		if slot == null or not slot.has_method("set_visual_alive"):
			continue
		slot.set_visual_alive(u.is_alive())
		var hi: bool = _highlight_actor != null and _highlight_actor.id == u.id and u.is_alive()
		slot.set_turn_highlight(hi)
	_sync_outline_post()


func _sync_outline_post() -> void:
	if _outline_post == null or not _outline_post.has_method(&"set_active"):
		return
	if _highlight_actor != null and _highlight_actor.is_alive():
		_outline_post.set_active(true, _highlight_actor.is_player_side)
	else:
		_outline_post.set_active(false, false)


func _check_battle_end() -> bool:
	if _state.is_battle_ongoing():
		return false
	_set_actions_enabled(false)
	_highlight_actor = null
	_sync_ui_after_state()
	var won := not _state.is_all_player_dead()
	var msg := "敌方全部倒下了！战斗胜利！" if won else "己方失去了战斗能力……"
	_narration.start_chain(
		PackedStringArray([msg]),
		func() -> void:
			_show_battle_result_overlay(won)
	)
	return true


func _show_battle_result_overlay(won: bool) -> void:
	_battle_result_title.text = "胜利" if won else "失败"
	_battle_result_subtitle.text = "你赢得了这场战斗。" if won else "我方全员无法战斗。"
	_battle_result_layer.visible = true
	_busy = true


func _on_battle_result_return_pressed() -> void:
	if _scene_transition != null:
		_scene_transition.fade_to_scene(SCENE_MAIN_MENU)
	else:
		get_tree().change_scene_to_file(SCENE_MAIN_MENU)


func _advance_battle() -> void:
	if _busy or _narration.is_narration_busy():
		return
	if _check_battle_end():
		return
	var next_u = _state.get_next_actor()
	if next_u == null:
		if _state.get_alive_units().is_empty():
			return
		var dot_lines := _CombatActionExecutor.apply_between_round_status_damage(
			_state.units,
			_on_unit_stats_changed,
		)
		var regen_lines := _CombatActionExecutor.apply_between_round_trait_regen(
			_state.units,
			_on_unit_stats_changed,
		)
		var between_round_lines: Array[String] = []
		for s in dot_lines:
			between_round_lines.append(s)
		for s in regen_lines:
			between_round_lines.append(s)
		if not between_round_lines.is_empty():
			_busy = true
			_set_actions_enabled(false)
			_narration.start_chain(between_round_lines, func() -> void:
				_busy = false
				_finish_round_transition_after_dot_damage()
			)
			return
		_finish_round_transition_after_dot_damage()
		return
	_highlight_actor = next_u
	_sync_ui_after_state()
	if next_u.is_player_side:
		var nm := _CombatActionExecutor.short_name(next_u)
		_narration.start_chain(PackedStringArray(["轮到 %s！" % nm]), func() -> void:
			_start_player_turn(next_u)
		)
	else:
		_busy = true
		_set_actions_enabled(false)
		var actor: BattleUnitRuntime = next_u
		var nm := _CombatActionExecutor.short_name(actor)
		_narration.start_chain(
			PackedStringArray(["下一位是 %s！" % nm, "%s 正在思考……" % nm]),
			func() -> void:
				var lines := _CombatActionExecutor.build_enemy_action_lines(
					actor,
					_state.units,
					_on_unit_stats_changed,
					_notify_slot_skill_cast,
					Callable(self, "_on_turn_completed"),
					Callable(self, "_on_hp_healed_visual"),
				)
				_narration.start_chain(lines, func() -> void:
					_busy = false
					_sync_ui_after_state()
					if not _check_battle_end():
						call_deferred("_advance_battle")
				)
		)


func _start_player_turn(actor: BattleUnitRuntime) -> void:
	_player_actor = actor
	_pick_phase = _PickPhase.NONE
	_pending_skill = null
	_set_actions_enabled(true)
	_rebuild_skill_buttons()


func _rebuild_skill_buttons() -> void:
	for c in _skill_buttons.get_children():
		c.queue_free()
	if _player_actor == null:
		return
	for s in _player_actor.skills:
		var b := Button.new()
		b.text = s.display_name
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cd := _player_actor.skill_cooldown(s)
		if cd > 0:
			b.text += " CD:%d" % cd
			b.disabled = true
		elif not _player_actor.can_pay_focus(s):
			b.disabled = true
		b.set_meta(&"skill_tip_skill", s)
		b.set_meta(&"skill_tip_actor", _player_actor)
		b.pressed.connect(_on_skill_button_pressed.bind(s))
		_skill_buttons.add_child(b)


func _on_rest_pressed() -> void:
	if _busy or _narration.is_narration_busy() or _player_actor == null:
		return
	_set_actions_enabled(false)
	var lines := _CombatActionExecutor.apply_rest(
		_player_actor, _on_unit_stats_changed, Callable(self, "_on_turn_completed")
	)
	_narration.start_chain(PackedStringArray(lines), func() -> void:
		_finish_player_action()
	)


func _on_skill_button_pressed(skill: SkillData) -> void:
	if _busy or _narration.is_narration_busy() or _player_actor == null:
		return
	if skill.target_kind == SkillData.TargetKind.NONE:
		_set_actions_enabled(false)
		var lines := _CombatActionExecutor.apply_skill(
			_player_actor,
			skill,
			[],
			_on_unit_stats_changed,
			_notify_slot_skill_cast,
			Callable(self, "_on_turn_completed"),
			Callable(self, "_on_hp_healed_visual"),
		)
		_narration.start_chain(PackedStringArray(lines), func() -> void:
			_finish_player_action()
		)
		return
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		_pending_skill = skill
		_set_actions_enabled(false)
		_narration.start_chain(
			PackedStringArray(["选择 %s 的目标：点击场上的敌方宝可梦。" % skill.display_name]),
			func() -> void: _pick_phase = _PickPhase.SKILL_TARGET,
			0.0,
		)
		return
	if skill.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		_pending_skill = skill
		_set_actions_enabled(false)
		_narration.start_chain(
			PackedStringArray(["选择 %s 的目标：点击场上的己方宝可梦（可选自己）。" % skill.display_name]),
			func() -> void: _pick_phase = _PickPhase.SKILL_TARGET,
			0.0,
		)
		return


func _on_skill_target_pressed(target: BattleUnitRuntime) -> void:
	if _busy or _narration.is_narration_busy() or _pick_phase != _PickPhase.SKILL_TARGET or _pending_skill == null or _player_actor == null:
		return
	if not target.is_alive():
		return
	var sk := _pending_skill
	if sk.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		if target.is_player_side:
			return
	elif sk.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		if target.is_player_side != _player_actor.is_player_side:
			return
	else:
		return
	_set_skill_target_pick_highlight_id(-1)
	_pick_phase = _PickPhase.NONE
	_pending_skill = null
	var lines := _CombatActionExecutor.apply_skill(
		_player_actor,
		sk,
		[target],
		_on_unit_stats_changed,
		_notify_slot_skill_cast,
		Callable(self, "_on_turn_completed"),
		Callable(self, "_on_hp_healed_visual"),
	)
	_narration.start_chain(PackedStringArray(lines), func() -> void:
		_finish_player_action()
	)


func _finish_player_action() -> void:
	_player_actor = null
	_busy = false
	_sync_ui_after_state()
	if _check_battle_end():
		return
	call_deferred("_advance_battle")


func _update_skill_target_pick_highlight() -> void:
	if _pick_phase != _PickPhase.SKILL_TARGET or _pending_skill == null or _player_actor == null:
		_set_skill_target_pick_highlight_id(-1)
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and _is_descendant_of(hovered, _battle_hud_root):
		_set_skill_target_pick_highlight_id(-1)
		return
	var mouse := get_viewport().get_mouse_position()
	var w3d := get_viewport().get_world_3d()
	var u := _CombatBattlePick.ray_pick_unit(mouse, _camera_3d, w3d)
	if u == null or not u.is_alive():
		_set_skill_target_pick_highlight_id(-1)
		return
	var pk := _pending_skill
	var ok := false
	if pk.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		ok = not u.is_player_side
	elif pk.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		ok = u.is_player_side == _player_actor.is_player_side
	if not ok:
		_set_skill_target_pick_highlight_id(-1)
		return
	_set_skill_target_pick_highlight_id(u.id)


func _set_skill_target_pick_highlight_id(unit_id: int) -> void:
	if unit_id == _skill_target_pick_hover_id:
		return
	if _skill_target_pick_hover_id != -1:
		var old_slot: Variant = _slots_by_unit_id.get(_skill_target_pick_hover_id)
		if old_slot != null and old_slot.has_method(&"set_skill_target_hover_highlight"):
			old_slot.set_skill_target_hover_highlight(false)
	_skill_target_pick_hover_id = unit_id
	if unit_id != -1:
		var new_slot: Variant = _slots_by_unit_id.get(unit_id)
		if new_slot != null and new_slot.has_method(&"set_skill_target_hover_highlight"):
			new_slot.set_skill_target_hover_highlight(true)


func _update_hover_tooltip() -> void:
	# 与台词并行刷新；若在 is_narration_busy 时整段 return，会导致提示框不跟鼠标显示/隐藏。
	var mouse := get_viewport().get_mouse_position()
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		if _battle_tooltip.is_ancestor_of(hovered) or hovered == _battle_tooltip:
			if _battle_tooltip.visible:
				_place_battle_tooltip(mouse)
			return
		if _is_descendant_of(hovered, _battle_hud_root):
			var hud_tip := _battle_tooltip_bbcode_for_hud_hover(hovered)
			if hud_tip.is_empty():
				_battle_tooltip.visible = false
				return
			_battle_tooltip_place_left = _is_descendant_of(hovered, _right_action_dock)
			_tooltip_text.clear()
			_tooltip_text.append_text(hud_tip)
			_battle_tooltip.visible = true
			_battle_tooltip.reset_size()
			_place_battle_tooltip(mouse)
			return
	var w3d := get_viewport().get_world_3d()
	var u := _CombatBattlePick.ray_pick_unit(mouse, _camera_3d, w3d)
	if u == null or not u.is_alive():
		_battle_tooltip.visible = false
		return
	_battle_tooltip_place_left = false
	_tooltip_text.clear()
	_tooltip_text.append_text(_CombatUnitTooltipText.format_bbcode(u))
	_battle_tooltip.visible = true
	_battle_tooltip.reset_size()
	_place_battle_tooltip(mouse)


func _place_battle_tooltip(mouse: Vector2) -> void:
	var psz: Vector2 = _battle_tooltip.size
	var vp := get_viewport().get_visible_rect().size
	var pos: Vector2
	if _battle_tooltip_place_left:
		var gap_x := 24.0
		var gap_y := 8.0
		pos.x = mouse.x - psz.x - gap_x
		pos.y = mouse.y - psz.y * 0.35 - gap_y
	else:
		var pad := Vector2(14, 14)
		pos = mouse + pad
	pos.x = clampf(pos.x, 6.0, maxf(6.0, vp.x - psz.x - 6.0))
	pos.y = clampf(pos.y, 6.0, maxf(6.0, vp.y - psz.y - 6.0))
	_battle_tooltip.position = pos


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var n := node
	while n != null:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


func _find_enclosing_button(from: Control) -> Button:
	var n: Node = from
	while n != null:
		if n is Button:
			return n as Button
		n = n.get_parent()
	return null


func _battle_tooltip_bbcode_for_hud_hover(hovered: Control) -> String:
	if _btn_rest != null and _is_descendant_of(hovered, _btn_rest):
		return _CombatSkillTooltipText.format_rest_bbcode()
	var btn := _find_enclosing_button(hovered)
	if btn == null or not btn.has_meta(&"skill_tip_skill"):
		return ""
	var sk: SkillData = btn.get_meta(&"skill_tip_skill") as SkillData
	var act: BattleUnitRuntime = btn.get_meta(&"skill_tip_actor") as BattleUnitRuntime
	if sk == null:
		return ""
	return _CombatSkillTooltipText.format_skill_bbcode(sk, act)


func _unhandled_input(event: InputEvent) -> void:
	if _narration.is_narration_busy():
		return
	if _pick_phase != _PickPhase.SKILL_TARGET or _busy:
		return
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var w3d := get_viewport().get_world_3d()
	var picked := _CombatBattlePick.ray_pick_unit(mb.position, _camera_3d, w3d)
	if picked == null or not picked.is_alive() or _pending_skill == null or _player_actor == null:
		return
	var psk := _pending_skill
	var accept := false
	if psk.target_kind == SkillData.TargetKind.SINGLE_ENEMY:
		accept = not picked.is_player_side
	elif psk.target_kind == SkillData.TargetKind.SINGLE_ALLY:
		accept = picked.is_player_side == _player_actor.is_player_side
	if accept:
		get_viewport().set_input_as_handled()
		_on_skill_target_pressed(picked)


func _finish_round_transition_after_dot_damage() -> void:
	if _check_battle_end():
		return
	_state.tick_new_round()
	_refresh_turn_order_strip()
	_narration.start_chain(PackedStringArray(["第 %d 回合！" % _state.round_number]), func() -> void:
		call_deferred("_advance_battle")
	)


func debug_peek_next_actor() -> BattleUnitRuntime:
	var el: Array[BattleUnitRuntime] = _state.eligible_for_round()
	if el.is_empty():
		return null
	_state.sort_eligible_by_speed(el)
	return el[0]
