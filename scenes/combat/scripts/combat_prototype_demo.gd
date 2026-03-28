extends Node
## 战斗原型场景根节点：串联 **CombatTurnState（规则）** 与 **表现层控制器**（台词、条、3D 槽位）。

const BAR_OFFSET_WORLD_Y := 2.15

@export_group("Battle text (typewriter)")
@export_range(4.0, 120.0, 1.0, "suffix:字/秒") var battle_text_chars_per_second: float = 18.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var battle_text_read_pause_sec: float = 1.5

@export_group("Unit bars")
@export_range(0.0, 3.0, 0.05, "suffix:s") var unit_bar_tween_duration_sec: float = 0.45

const _SLOT_SCENE := preload("res://scenes/combat/battle_creature_slot.tscn")
const _CombatTurnState := preload("res://battle/combat_turn_state.gd")
const _CombatDemoRoster := preload("res://battle/combat_demo_roster.gd")
const _CombatActionExecutor := preload("res://battle/combat_action_executor.gd")
const _CombatNarrationController := preload("res://scenes/combat/scripts/combat_narration_controller.gd")
const _CombatUnitBarsController := preload("res://scenes/combat/scripts/combat_unit_bars_controller.gd")
const _CombatBattlePick := preload("res://scenes/combat/scripts/combat_battle_pick.gd")
const _CombatUnitTooltipText := preload("res://scenes/combat/scripts/combat_unit_tooltip_text.gd")
const _VISUAL_BY_UNIT_ID := {
	1: preload("res://assets/pokemon/khazix_avatar.tscn"),
	2: preload("res://assets/pokemon/malphite_avatar.tscn"),
	3: preload("res://assets/pokemon/hecarim_avatar.tscn"),
	4: preload("res://assets/pokemon/fizz_avatar.tscn"),
}
const _SLOT_POSITION := {
	1: Vector3(-2.2, 0, 3.5),
	2: Vector3(2.2, 0, 3.5),
	3: Vector3(-2.2, 0, -3.5),
	4: Vector3(2.2, 0, -3.5),
}

@onready var _battle_message: RichTextLabel = %BattleMessageText
@onready var _btn_rest: Button = %BtnRest
@onready var _skill_buttons: HBoxContainer = %SkillButtons
@onready var _actions: VBoxContainer = %ActionsPanel
@onready var _actions_bar: HBoxContainer = %ActionsBar
@onready var _battle_tooltip: PanelContainer = %BattleTooltip
@onready var _tooltip_text: RichTextLabel = %TooltipText
@onready var _battle_hud_root: Control = %BattleHudRoot
@onready var _unit_bars_root: Control = %UnitBarsRoot
@onready var _camera_3d: Camera3D = %BattleCamera
@onready var _battle_field: Node3D = %BattleField

var _state = _CombatTurnState.new()
var _narration
var _bars

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


func _ready() -> void:
	_battle_message.bbcode_enabled = false
	_state.units = _CombatDemoRoster.create_units()
	_narration = _CombatNarrationController.new(_battle_message)
	_narration.chars_per_second = battle_text_chars_per_second
	_narration.read_pause_after_line_sec = battle_text_read_pause_sec
	_bars = _CombatUnitBarsController.new(_unit_bars_root, _camera_3d)
	_bars.bar_offset_world_y = BAR_OFFSET_WORLD_Y
	_bars.tween_duration_sec = unit_bar_tween_duration_sec
	_btn_rest.pressed.connect(_on_rest_pressed)
	_spawn_3d_slots()
	_bars.clear_and_rebuild(_state.units)
	_set_actions_enabled(false)
	_narration.start_chain(PackedStringArray(["战斗开始！"]), func() -> void:
		call_deferred("_advance_battle")
	)


func _process(delta: float) -> void:
	_narration.process_frame(delta)
	_bars.update_screen_positions(_state.units, _slots_by_unit_id)
	_update_hover_tooltip()


func _on_unit_stats_changed(u: BattleUnitRuntime) -> void:
	_bars.sync_unit_values(u)


func _notify_slot_skill_cast(actor: BattleUnitRuntime, skill: SkillData, targets: Array[BattleUnitRuntime]) -> void:
	var slot: Variant = _slots_by_unit_id.get(actor.id)
	if slot == null or not slot.has_method("notify_skill_cast"):
		return
	if skill.target_kind == SkillData.TargetKind.SINGLE_ENEMY and not targets.is_empty():
		var target_slot: Variant = _slots_by_unit_id.get(targets[0].id)
		if target_slot is Node3D:
			slot.notify_skill_cast((target_slot as Node3D).global_position)
			return
	slot.notify_skill_cast()


func _set_actions_enabled(on: bool) -> void:
	_actions_bar.visible = true
	_actions_bar.modulate.a = 1.0 if on else 0.0
	_actions_bar.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_actions.visible = true
	_btn_rest.disabled = not on
	for c in _skill_buttons.get_children():
		if c is Button:
			c.disabled = not on


func _sync_ui_after_state() -> void:
	_sync_3d_visuals()
	_bars.sync_all_units(_state.units)


func _spawn_3d_slots() -> void:
	for c in _battle_field.get_children():
		c.queue_free()
	_slots_by_unit_id.clear()
	for u in _state.units:
		var slot: Node3D = _SLOT_SCENE.instantiate()
		_battle_field.add_child(slot)
		var vis: PackedScene = _VISUAL_BY_UNIT_ID.get(u.id, null)
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
		slot.set_highlight(hi)


func _check_battle_end() -> bool:
	if _state.is_battle_ongoing():
		return false
	_set_actions_enabled(false)
	_highlight_actor = null
	_sync_ui_after_state()
	if _state.is_all_player_dead():
		_narration.start_chain(PackedStringArray(["己方失去了战斗能力……"]), Callable())
	else:
		_narration.start_chain(PackedStringArray(["敌方全部倒下了！战斗胜利！"]), Callable())
	return true


func _advance_battle() -> void:
	if _busy or _narration.is_narration_busy():
		return
	if _check_battle_end():
		return
	var next_u = _state.get_next_actor()
	if next_u == null:
		if _state.get_alive_units().is_empty():
			return
		_state.tick_new_round()
		_narration.start_chain(PackedStringArray(["第 %d 回合！" % _state.round_number]), func() -> void:
			call_deferred("_advance_battle")
		)
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
		b.text = "%s (%d专)" % [s.display_name, s.focus_cost]
		var cd := _player_actor.skill_cooldown(s)
		if cd > 0:
			b.text += " CD:%d" % cd
			b.disabled = true
		elif not _player_actor.can_pay_focus(s):
			b.disabled = true
		b.pressed.connect(_on_skill_button_pressed.bind(s))
		_skill_buttons.add_child(b)


func _on_rest_pressed() -> void:
	if _busy or _narration.is_narration_busy() or _player_actor == null:
		return
	_set_actions_enabled(false)
	var lines := _CombatActionExecutor.apply_rest(_player_actor, _on_unit_stats_changed)
	_narration.start_chain(PackedStringArray(lines), func() -> void:
		_finish_player_action()
	)


func _on_skill_button_pressed(skill: SkillData) -> void:
	if _busy or _narration.is_narration_busy() or _player_actor == null:
		return
	if skill.target_kind == SkillData.TargetKind.NONE:
		_set_actions_enabled(false)
		var lines := _CombatActionExecutor.apply_skill(
			_player_actor, skill, [], _on_unit_stats_changed, _notify_slot_skill_cast
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
			func() -> void:
				_pick_phase = _PickPhase.SKILL_TARGET
		)


func _on_enemy_target_pressed(target: BattleUnitRuntime) -> void:
	if _busy or _narration.is_narration_busy() or _pick_phase != _PickPhase.SKILL_TARGET or _pending_skill == null or _player_actor == null:
		return
	if not target.is_alive() or target.is_player_side:
		return
	_pick_phase = _PickPhase.NONE
	var sk := _pending_skill
	_pending_skill = null
	var lines := _CombatActionExecutor.apply_skill(
		_player_actor, sk, [target], _on_unit_stats_changed, _notify_slot_skill_cast
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


func _update_hover_tooltip() -> void:
	if _narration.is_narration_busy():
		return
	var mouse := get_viewport().get_mouse_position()
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		if _battle_tooltip.is_ancestor_of(hovered) or hovered == _battle_tooltip:
			if _battle_tooltip.visible:
				_place_battle_tooltip(mouse)
			return
		if _is_descendant_of(hovered, _battle_hud_root):
			_battle_tooltip.visible = false
			return
	var w3d := get_viewport().get_world_3d()
	var u := _CombatBattlePick.ray_pick_unit(mouse, _camera_3d, w3d)
	if u == null or not u.is_alive():
		_battle_tooltip.visible = false
		return
	_tooltip_text.clear()
	_tooltip_text.append_text(_CombatUnitTooltipText.format_bbcode(u))
	_battle_tooltip.visible = true
	_battle_tooltip.reset_size()
	_place_battle_tooltip(mouse)


func _place_battle_tooltip(mouse: Vector2) -> void:
	var pad := Vector2(14, 14)
	var psz: Vector2 = _battle_tooltip.size
	var vp := get_viewport().get_visible_rect().size
	var pos := mouse + pad
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
	if picked and not picked.is_player_side and picked.is_alive():
		get_viewport().set_input_as_handled()
		_on_enemy_target_pressed(picked)


func debug_peek_next_actor() -> BattleUnitRuntime:
	var el: Array[BattleUnitRuntime] = _state.eligible_for_round()
	if el.is_empty():
		return null
	_state.sort_eligible_by_speed(el)
	return el[0]
