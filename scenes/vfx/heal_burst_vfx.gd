extends Node3D
## 战斗用一次性治疗粒子：生成后自动播放并在结束后释放节点。


func _ready() -> void:
	_build_particles()
	_play_all()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(self) and not is_queued_for_deletion():
			queue_free()
	)


func _build_particles() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "HealSparkles"
	particles.amount = 56
	particles.lifetime = 1.05
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.visibility_aabb = AABB(Vector3(-4, -0.5, -4), Vector3(8, 8, 8))

	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.5
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 58.0
	proc.initial_velocity_min = 0.9
	proc.initial_velocity_max = 3.2
	proc.angular_velocity_min = -1.8
	proc.angular_velocity_max = 1.8
	proc.gravity = Vector3(0, 1.8, 0)
	proc.linear_accel_min = -0.4
	proc.linear_accel_max = 0.6
	proc.scale_min = 0.1
	proc.scale_max = 0.26
	proc.color = Color(0.42, 1.0, 0.68, 0.92)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color.WHITE
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat

	particles.process_material = proc
	particles.draw_pass_1 = quad
	add_child(particles)
	particles.finished.connect(_on_particles_finished, CONNECT_ONE_SHOT)


func _play_all() -> void:
	for c in get_children():
		if c is GPUParticles3D:
			var gp := c as GPUParticles3D
			gp.restart()
			gp.emitting = true


func _on_particles_finished() -> void:
	if is_instance_valid(self) and not is_queued_for_deletion():
		queue_free()
