class_name Star
extends Area3D
## A golden collectible star: spins, bobs, glows, and pops when touched.

signal collected

var _mesh: MeshInstance3D
var _t := randf() * TAU
var _base_y := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	shape.shape = s
	add_child(shape)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _star_mesh(0.6, 0.27, 0.16)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.78, 0.2)
	m.metallic = 0.8
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.2)
	m.emission_energy_multiplier = 1.5
	_mesh.material_override = m
	add_child(_mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.4)
	light.light_energy = 1.2
	light.omni_range = 3.5
	add_child(light)
	_base_y = position.y
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y += delta * 2.2
	_mesh.position.y = sin(_t * 2.0) * 0.15


func _on_body(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	Game.sfx("star")
	Fx.sparks(global_position, Vector3.UP, Color(3.0, 2.4, 0.8), 30, 9.0)
	Fx.ring(global_position - Vector3.UP * 0.5, 2.0, Color(3.0, 2.4, 0.8, 1.0), 0.3)
	collected.emit()
	queue_free()


## A flat five-pointed star with thickness, built once.
static func _star_mesh(r_out: float, r_in: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0))
	for side in [1.0, -1.0]:
		var tip := Vector3(0, 0, depth * side)
		for i in 10:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[(i + 1) % 10]
			if side > 0:
				st.add_vertex(tip)
				st.add_vertex(b)
				st.add_vertex(a)
			else:
				st.add_vertex(tip)
				st.add_vertex(a)
				st.add_vertex(b)
	st.generate_normals()
	return st.commit()
