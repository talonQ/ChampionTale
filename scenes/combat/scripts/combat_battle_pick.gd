class_name CombatBattlePick
extends RefCounted
## 屏幕坐标射线拾取带 battle_unit meta 的单位（表现层输入辅助，无战斗规则）。


static func ray_pick_unit(screen_pos: Vector2, camera: Camera3D, world_3d: World3D) -> BattleUnitRuntime:
	if camera == null or not camera.current or world_3d == null:
		return null
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 200.0
	var pq := PhysicsRayQueryParameters3D.create(from, to)
	pq.collide_with_areas = false
	pq.collide_with_bodies = true
	pq.collision_mask = 2
	var hit := world_3d.direct_space_state.intersect_ray(pq)
	if hit.is_empty() or not hit.has("collider"):
		return null
	var col: Variant = hit["collider"]
	if col is CollisionObject3D and col.has_meta(&"battle_unit"):
		return col.get_meta(&"battle_unit") as BattleUnitRuntime
	return null
