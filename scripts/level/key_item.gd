class_name KeyItem
extends Area3D
## A key the level's gate needs: a battery or a gear. It appears where an arena
## was won, under a pillar of light you can see from across the room.

signal collected

@export var look := "battery"  # battery, gear
@export var color := Color(1.0, 0.8, 0.25)

var _model: Node3D
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.6
	shape.shape = s
	add_child(shape)
	_model = Node3D.new()
	add_child(_model)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.7
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	if look == "gear":
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.45
		torus.outer_radius = 0.9
		ring.mesh = torus
		ring.material_override = mat
		ring.rotation_degrees = Vector3(90, 0, 0)
		_model.add_child(ring)
		for i in 10:
			var tooth := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.28, 0.32, 0.28)
			tooth.mesh = b
			tooth.material_override = mat
			var a := TAU * i / 10.0
			tooth.position = Vector3(cos(a), sin(a), 0) * 1.0
			tooth.rotation.z = a
			_model.add_child(tooth)
	else:
		var body := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 1.7
		body.mesh = cyl
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.08, 0.1)
		dark.metallic = 0.4
		dark.roughness = 0.3
		body.material_override = dark
		_model.add_child(body)
		var band := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.47
		bc.bottom_radius = 0.47
		bc.height = 0.7
		band.mesh = bc
		band.material_override = mat
		band.position.y = 0.45
		_model.add_child(band)
		var tip := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.16
		tc.bottom_radius = 0.16
		tc.height = 0.2
		tip.mesh = tc
		tip.material_override = mat
		tip.position.y = 0.95
		_model.add_child(tip)
	var beam := MeshInstance3D.new()  # a pillar of light, visible from afar
	var bm := CylinderMesh.new()
	bm.top_radius = 0.9
	bm.bottom_radius = 0.6
	bm.height = 40.0
	beam.mesh = bm
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.18)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = beam_mat
	beam.position.y = 20.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 2.5
	light.omni_range = 6.0
	add_child(light)
	body_entered.connect(_on_body)
	Game.sfx("star", 2.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_model.rotation.y += delta * 1.8
	_model.position.y = sin(_t * 2.0) * 0.25


func _on_body(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	Game.sfx("counter")
	Game.shake(0.3)
	Fx.sparks(global_position, Vector3.UP, Color(color.r * 3.0, color.g * 3.0, color.b * 3.0), 50, 12.0)
	Fx.ring(global_position - Vector3.UP * 0.8, 4.0, Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0), 0.4)
	collected.emit()
	queue_free()
