class_name CombatOutlinePost
extends Node
## 与 MonsterTale 一致：场景内 SubViewport + Outline 相机只照第 2 渲染层；TextureRect 直接显示 Viewport 纹理，
## 材质着色器用 TEXTURE 的 alpha 做描边（物体在遮罩里为实心 alpha，外为 0，差分得到轮廓）。


const LAYER_MAIN_MASK := 0x1

@onready var _outline_viewport: SubViewport = %"OutlineMaskViewport"
@onready var _outline_camera: Camera3D = %"OutlineCamera"
@onready var _outline_canvas: CanvasLayer = %"OutlinePostCanvas"
@onready var _overlay: TextureRect = %"OutlineOverlay"
@onready var _battle_camera: Camera3D = %"BattleCamera"

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = _overlay.material as ShaderMaterial
	if _mat == null:
		push_error("CombatOutlinePost: OutlineOverlay 需要 ShaderMaterial（outline_postprocess.gdshader）。")
		return
	if _battle_camera != null:
		_battle_camera.cull_mask = LAYER_MAIN_MASK

	_outline_viewport.transparent_bg = true
	_outline_viewport.handle_input_locally = false
	_outline_viewport.gui_disable_input = true
	_outline_viewport.world_3d = get_viewport().world_3d
	if _outline_viewport.world_3d == null:
		call_deferred(&"_deferred_bind_world")

	_outline_camera.current = true
	_outline_camera.cull_mask = 0x2

	_overlay.texture = _outline_viewport.get_texture()

	_sync_outline_camera_from_battle()
	_on_viewport_size_changed()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	set_active(false, false)


func _deferred_bind_world() -> void:
	if _outline_viewport != null and get_viewport().world_3d != null:
		_outline_viewport.world_3d = get_viewport().world_3d


func _process(_delta: float) -> void:
	if not _outline_canvas.visible or _outline_camera == null or _battle_camera == null:
		return
	_sync_outline_camera_from_battle()


func _sync_outline_camera_from_battle() -> void:
	if _outline_camera == null or _battle_camera == null:
		return
	_outline_camera.global_transform = _battle_camera.global_transform
	_outline_camera.fov = _battle_camera.fov
	_outline_camera.near = _battle_camera.near
	_outline_camera.far = _battle_camera.far
	_outline_camera.projection = _battle_camera.projection
	if _battle_camera.attributes != null:
		_outline_camera.attributes = _battle_camera.attributes


func set_active(active: bool, is_player_side: bool) -> void:
	if _outline_viewport == null or _outline_canvas == null or _mat == null:
		return
	if active:
		_sync_outline_camera_from_battle()
	_outline_canvas.visible = active
	_outline_viewport.render_target_update_mode = (
		SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	)
	if active:
		var col := Color(0.15, 0.95, 0.32, 1.0) if is_player_side else Color(0.95, 0.2, 0.18, 1.0)
		_mat.set_shader_parameter(&"outline_color", col)


func _on_viewport_size_changed() -> void:
	if _outline_viewport == null:
		return
	var s := get_viewport().get_visible_rect().size
	_outline_viewport.size = Vector2i(maxi(2, int(s.x)), maxi(2, int(s.y)))
