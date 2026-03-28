class_name CreatureAnimationDriver
extends Node
## 通用 3D 角色动画驱动：在子树中查找 AnimationPlayer，按逻辑状态切换片段并做混合过渡。
## 不依赖任何战斗/玩法类型，仅通过动画名候选列表匹配 GLB 导入后的片段名。

signal attack_finished
signal death_finished

@export_group("Blending")
@export var blend_time: float = 0.22

@export_group("Animation name candidates")
## 按顺序尝试，直到找到 AnimationPlayer 中存在的片段（支持 animation library 全名）。
@export var idle_names: PackedStringArray = PackedStringArray(["Idle", "idle", "IDLE"])
@export var attack_names: PackedStringArray = PackedStringArray(["Attack", "attack", "ATTACK", "Punch", "punch"])
@export var death_names: PackedStringArray = PackedStringArray(["Death", "death", "DEATH", "Die", "die", "Defeat"])

var _player: AnimationPlayer
var _attack_anim_playing: StringName = &""
var _death_anim_playing: StringName = &""
var _dead_locked: bool = false
var _attack_cb: Callable = Callable()
var _death_cb: Callable = Callable()
var _idle_resolved: StringName = &""
var _attack_resolved: StringName = &""
var _death_resolved: StringName = &""


func _ready() -> void:
	_player = _find_animation_player(get_parent())
	if _player == null:
		push_warning("CreatureAnimationDriver: 未找到 AnimationPlayer（%s）" % str(get_path()))
		return
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	_cache_resolved_names()
	play_idle()


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var r := _find_animation_player(c)
		if r != null:
			return r
	return null


func _cache_resolved_names() -> void:
	if _player == null:
		return
	_idle_resolved = _resolve_first_existing(idle_names)
	_attack_resolved = _resolve_first_existing(attack_names)
	_death_resolved = _resolve_first_existing(death_names)
	_apply_idle_loop_in_code()


## Idle 必须在待机状态下循环；与 GLB 导入时的 loop 标记无关，在运行时写死为 LOOP_LINEAR。
func _apply_idle_loop_in_code() -> void:
	if _idle_resolved.is_empty():
		return
	var anim: Animation = _player.get_animation(_idle_resolved)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR


func _resolve_first_existing(candidates: PackedStringArray) -> StringName:
	for raw in candidates:
		var n := StringName(raw)
		if _player.has_animation(n):
			return n
	# 模糊：候选子串匹配列表中的全名
	var list := _player.get_animation_list()
	for raw in candidates:
		var key := raw.to_lower()
		for full in list:
			if key.is_empty():
				continue
			if String(full).to_lower().contains(key):
				return full
	return StringName()


func has_death_animation() -> bool:
	return not _death_resolved.is_empty()


func reset_to_alive() -> void:
	_dead_locked = false
	_death_anim_playing = &""
	_attack_anim_playing = &""
	_attack_cb = Callable()
	_death_cb = Callable()
	play_idle()


func play_idle() -> void:
	if _player == null or _dead_locked:
		return
	if _idle_resolved.is_empty():
		return
	# 再次保证：从 Attack 切回 Idle 时若资源被重置仍维持循环。
	_apply_idle_loop_in_code()
	_attack_anim_playing = &""
	_player.play(_idle_resolved, blend_time)


func play_attack(on_finished: Callable = Callable()) -> void:
	if _player == null or _dead_locked:
		if on_finished.is_valid():
			on_finished.call()
		return
	if _attack_resolved.is_empty():
		if on_finished.is_valid():
			on_finished.call()
		return
	_attack_cb = on_finished
	_attack_anim_playing = _attack_resolved
	_player.play(_attack_resolved, blend_time)


func play_death(on_finished: Callable = Callable()) -> void:
	if _player == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	if _dead_locked:
		if on_finished.is_valid():
			on_finished.call()
		return
	if _death_resolved.is_empty():
		_dead_locked = true
		if on_finished.is_valid():
			on_finished.call()
		return
	_death_cb = on_finished
	_death_anim_playing = _death_resolved
	_player.play(_death_resolved, blend_time)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _attack_anim_playing:
		_attack_anim_playing = &""
		play_idle()
		attack_finished.emit()
		var cb := _attack_cb
		_attack_cb = Callable()
		if cb.is_valid():
			cb.call()
	elif anim_name == _death_anim_playing:
		_death_anim_playing = &""
		_dead_locked = true
		death_finished.emit()
		var cb := _death_cb
		_death_cb = Callable()
		if cb.is_valid():
			cb.call()
