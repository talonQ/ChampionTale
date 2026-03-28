extends Node3D
## 战斗场上单个单位的 3D 占位：可视化 + 射线可点的碰撞代理。
## 动画由子节点 CreatureAnimationDriver 处理，与战斗数值逻辑解耦。
## 行动高亮：把网格加入第 2 渲染层，由 OutlineMaskViewport 专照该层，与 MonsterTale 相同管线。

const _ANIM_DRIVER_SCRIPT := preload("res://components/creature_animation_driver.gd")
## 主相机仅照第 1 层；描边开启时再打开第 2 层给 Outline 相机。
const OUTLINE_RENDER_LAYER := 2

var unit: BattleUnitRuntime
## CreatureAnimationDriver（components/creature_animation_driver.gd）
var _anim_driver: Node = null
var _death_sequence_started: bool = false
var _saved_rotation_deg: Vector3 = Vector3.ZERO
var _facing_override_active: bool = false


func setup(p_unit: BattleUnitRuntime, visual_scene: PackedScene) -> void:
	unit = p_unit
	_set_outline_layer_on_meshes(false)
	var proxy := get_node(^"PickProxy") as StaticBody3D
	proxy.set_meta(&"battle_unit", p_unit)
	var vis := get_node(^"Visual") as Node3D
	for c in vis.get_children():
		c.queue_free()
	_anim_driver = null
	_death_sequence_started = false
	if visual_scene:
		var inst := visual_scene.instantiate()
		vis.add_child(inst)
		var existing: Node = inst.find_child("CreatureAnimationDriver", true, false)
		if existing != null and existing.get_script() == _ANIM_DRIVER_SCRIPT:
			_anim_driver = existing
		else:
			var driver: Node = _ANIM_DRIVER_SCRIPT.new()
			driver.name = "CreatureAnimationDriver"
			inst.add_child(driver)
			_anim_driver = driver
	_force_mesh_main_layer_only(vis)


## 可选传入目标世界坐标（通常取对方槽位）：仅绕 Y 朝向目标，攻击动画结束后恢复进入攻击前的 rotation_degrees。
func notify_skill_cast(target_world_optional: Variant = null) -> void:
	if target_world_optional is Vector3:
		if not _facing_override_active:
			_saved_rotation_deg = rotation_degrees
		_face_world_on_horizontal_plane(target_world_optional as Vector3)
		_facing_override_active = true
	if _anim_driver != null and _anim_driver.has_method("play_attack"):
		_anim_driver.play_attack(Callable(self, "_restore_facing_after_attack"))
	elif _facing_override_active:
		rotation_degrees = _saved_rotation_deg
		_facing_override_active = false


func _face_world_on_horizontal_plane(world_point: Vector3) -> void:
	var self_pos := global_position
	var look := Vector3(world_point.x, self_pos.y, world_point.z)
	var flat_self := Vector3(self_pos.x, 0, self_pos.z)
	var flat_look := Vector3(look.x, 0, look.z)
	if flat_self.is_equal_approx(flat_look):
		return
	var keep_xz := rotation_degrees
	look_at(look, Vector3.UP)
	rotation_degrees.x = keep_xz.x
	rotation_degrees.z = keep_xz.z
	# look_at 对齐的是节点 -Z → 目标；多数 GLB 角色正面在 +Z，需绕 Y 补 180° 才是「面向」目标。
	rotation_degrees.y += 180.0


func _restore_facing_after_attack() -> void:
	if _facing_override_active:
		rotation_degrees = _saved_rotation_deg
		_facing_override_active = false


func set_turn_highlight(active: bool) -> void:
	var vis := get_node_or_null(^"Visual") as Node3D
	if vis != null:
		vis.scale = Vector3.ONE
	_set_outline_layer_on_meshes(active)


func _set_outline_layer_on_meshes(on: bool) -> void:
	var vis := get_node_or_null(^"Visual") as Node3D
	if vis == null:
		return
	for mi in _collect_mesh_instances(vis):
		mi.set_layer_mask_value(OUTLINE_RENDER_LAYER, on)


## 仅第 1 层，供主相机渲染；关闭第 2 层避免误入描边 RT。
static func _force_mesh_main_layer_only(root: Node) -> void:
	for mi in _collect_mesh_instances(root):
		mi.layers = 0x1
		mi.set_layer_mask_value(OUTLINE_RENDER_LAYER, false)


static func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "", true, false):
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
	return out


func set_visual_alive(alive: bool) -> void:
	var vis := get_node_or_null(^"Visual") as Node3D
	var proxy := get_node_or_null(^"PickProxy") as StaticBody3D
	if vis == null or proxy == null:
		return
	if alive:
		_death_sequence_started = false
		vis.visible = true
		proxy.collision_layer = 2
		if _anim_driver != null and _anim_driver.has_method("reset_to_alive"):
			_anim_driver.reset_to_alive()
		return
	if _death_sequence_started:
		return
	_death_sequence_started = true
	if _anim_driver != null and _anim_driver.has_method("has_death_animation") and _anim_driver.has_death_animation():
		_anim_driver.play_death(Callable(self, "_apply_dead_visual"))
	else:
		_apply_dead_visual()


func _apply_dead_visual() -> void:
	var vis := get_node_or_null(^"Visual") as Node3D
	var proxy := get_node_or_null(^"PickProxy") as StaticBody3D
	if vis:
		vis.visible = false
	if proxy:
		proxy.collision_layer = 0


func get_pick_body() -> StaticBody3D:
	return get_node(^"PickProxy") as StaticBody3D
