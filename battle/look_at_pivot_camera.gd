@tool
extends Camera3D
## 以 [member target_point] 为中心，按 [member distance]、[member yaw_deg]、[member pitch_deg] 将球面上的点作为机位，并 [code]look_at[/code] 目标。适合战斗俯视。

@export var target_point: Vector3 = Vector3.ZERO:
	set(v):
		target_point = v
		_queue_update()

@export var distance: float = 11.0:
	set(v):
		distance = maxf(0.25, v)
		_queue_update()

## 相对水平面（XZ）的仰角：越大越抬高，越接近俯视。
@export_range(5.0, 89.0, 0.5) var pitch_deg: float = 40.0:
	set(v):
		pitch_deg = clampf(v, 5.0, 89.5)
		_queue_update()

## 绕 Y 轴旋转（0° 时机位在目标 +Z 一侧，朝 -Z 看）。
@export var yaw_deg: float = 0.0:
	set(v):
		yaw_deg = v
		_queue_update()


func _ready() -> void:
	_update_transform()


func _queue_update() -> void:
	call_deferred("_update_transform")


func _update_transform() -> void:
	if not is_inside_tree():
		return
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(yaw_deg)
	var h: float = cos(pitch) * distance
	var y: float = sin(pitch) * distance
	var offset := Vector3(sin(yaw) * h, y, cos(yaw) * h)
	global_position = target_point + offset
	look_at(target_point, Vector3.UP)


func set_target(v: Vector3) -> void:
	target_point = v
