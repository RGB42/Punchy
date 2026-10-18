class_name Fx
## One-shot visual effects. Everything here spawns into the current scene and
## cleans itself up. Colours above 1.0 are HDR and bloom through the glow pass.

const DEBRIS_LAYER := 16

static var _spark_mesh: Mesh
static var _shard_mesh: Mesh
static var _puff_mesh: Mesh
static var _add_mat: StandardMaterial3D
static var _shard_mat: StandardMaterial3D
static var _fire_mat: StandardMaterial3D


static func _root() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.current_scene if tree.current_scene else tree.root


static func _init_shared() -> void:
	if _spark_mesh:
		return
	var b := BoxMesh.new()
	b.size = Vector3(0.05, 0.38, 0.05)
	_spark_mesh = b
	var s := BoxMesh.new()
	s.size = Vector3(0.1, 0.06, 0.12)
	_shard_mesh = s
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_puff_mesh = q
	_add_mat = StandardMaterial3D.new()
	_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_mat.vertex_color_use_as_albedo = true
	_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shard_mat = StandardMaterial3D.new()
	_shard_mat.vertex_color_use_as_albedo = true
	_shard_mat.roughness = 0.35
	_fire_mat = _add_mat.duplicate()
	_fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_fire_mat.albedo_texture = _soft_dot()


static func _soft_dot() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


static func _expire(node: Node, sec: float) -> void:
	_root().add_child(node)
	node.get_tree().create_timer(sec, false).timeout.connect(node.queue_free)


static func _burst(pos: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	_init_shared()
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 1.0
	p.position = pos
	return p


static func sparks(pos: Vector3, dir: Vector3, color := Color(3.0, 1.3, 0.35), amount := 26, speed := 15.0) -> void:
	var p := _burst(pos, amount, 0.32)
	p.mesh = _spark_mesh
	p.material_override = _add_mat
	p.particle_flag_align_y = true
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -22, 0)
	p.damping_min = 8.0
	p.damping_max = 14.0
	p.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	_expire(p, 0.6)


static func shards(pos: Vector3, dir: Vector3, color: Color, amount := 8) -> void:
	var p := _burst(pos, amount, 1.1)
	p.mesh = _shard_mesh
	p.material_override = _shard_mat
	p.direction = (dir.normalized() + Vector3.UP * 0.6).normalized()
	p.spread = 45.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.gravity = Vector3(0, -30, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color = color
	_expire(p, 1.3)


static func flash(pos: Vector3, color := Color(1.0, 0.6, 0.25), energy := 6.0, reach := 7.0, time := 0.12) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	_expire(l, time + 0.05)
	l.create_tween().tween_property(l, "light_energy", 0.0, time)


static func ring(pos: Vector3, radius: float, color := Color(3.0, 1.6, 0.6, 1.0), time := 0.32) -> void:
	_init_shared()
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.86
	t.outer_radius = 1.0
	t.rings = 32
	m.mesh = t
	var mat := _add_mat.duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = false
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos + Vector3.UP * 0.1
	m.scale = Vector3.ONE * 0.2
	_expire(m, time + 0.05)
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "scale", Vector3(radius, radius * 0.5, radius), time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, time)


static func _fire_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	g.colors = PackedColorArray([Color(5, 4, 2, 1), Color(4, 1.6, 0.3, 0.9), Color(1.6, 0.35, 0.05, 0.6), Color(0.1, 0.05, 0.05, 0)])
	return g


static func fire(pos: Vector3, dir: Vector3, spread_deg: float, speed: float, amount := 90, size := 0.9, life := 0.45) -> void:
	var p := _burst(pos, amount, life)
	p.explosiveness = 0.75
	p.mesh = _puff_mesh
	p.material_override = _fire_mat
	p.direction = dir.normalized()
	p.spread = spread_deg
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.4
	p.gravity = Vector3(0, 6, 0)
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	p.color_ramp = _fire_ramp()
	p.angle_min = 0.0
	p.angle_max = 360.0
	_expire(p, life + 0.3)


## Fires every effect once out of sight so shaders compile during loading,
## not on the first punch (a stutter there kills the feel of the hit).
static func prewarm() -> void:
	var far := Vector3(0, -60, 0)
	sparks(far, Vector3.UP)
	shards(far, Vector3.UP, Color.WHITE, 2)
	flash(far)
	ring(far, 1.0)
	fire(far, Vector3.UP, 20.0, 5.0, 4)


## A continuous jet for the figure's back thrusters; toggle `emitting`.
static func thruster() -> CPUParticles3D:
	_init_shared()
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 60
	p.lifetime = 0.35
	p.local_coords = false
	p.mesh = _puff_mesh
	p.material_override = _fire_mat
	p.direction = Vector3(0, -0.35, 1)
	p.spread = 12.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, 3, 0)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	p.color_ramp = _fire_ramp()
	return p


## Pops an action figure apart: every mesh becomes a tumbling plastic piece.
static func shatter(figure: Node3D, impulse: Vector3) -> void:
	var meshes: Array[MeshInstance3D] = []
	for n in figure.find_children("*", "MeshInstance3D", true, false):
		meshes.append(n)
	var root := _root()
	for m in meshes:
		var body := RigidBody3D.new()
		body.collision_layer = DEBRIS_LAYER
		body.collision_mask = 1
		body.mass = 0.3
		var xf := m.global_transform
		root.add_child(body)
		body.global_transform = xf
		var aabb := m.get_aabb()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (aabb.size * 0.8).max(Vector3.ONE * 0.06)
		shape.shape = box
		shape.position = aabb.get_center()
		body.add_child(shape)
		m.get_parent().remove_child(m)
		body.add_child(m)
		m.transform = Transform3D.IDENTITY
		var spread := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-1, 1)) * 3.0
		body.apply_central_impulse((impulse + spread) * body.mass)
		body.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.15)
		var tw := body.create_tween()
		tw.tween_interval(randf_range(2.5, 3.5))
		tw.tween_property(m, "scale", Vector3.ONE * 0.01, 0.4)  # never scale the body itself
		tw.tween_callback(body.queue_free)
	figure.visible = false
