@tool
class_name GrapplePoint
extends Node3D
## Something the grappling hook can bite into: a lamp hook, a plant stem, a knob.
## PULL zips the figure to the point and flings it up and over; SWING hangs it on
## a rope below the point.

enum Mode { PULL, SWING }

@export var mode := Mode.PULL:
	set(v):
		mode = v
		_build()

var _ring: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("grapple_point")
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.42
		_ring.mesh = torus
		_mat = StandardMaterial3D.new()
		_mat.emission_enabled = true
		_ring.material_override = _mat
		add_child(_ring)
	var col := Color(1.0, 0.75, 0.2) if mode == Mode.PULL else Color(0.3, 0.85, 1.0)
	_mat.albedo_color = col
	_mat.emission = col
	_mat.emission_energy_multiplier = 1.2
	_ring.rotation_degrees = Vector3(90, 0, 0) if mode == Mode.PULL else Vector3.ZERO


## Brighter while it is the current target.
func set_highlight(on: bool) -> void:
	_mat.emission_energy_multiplier = 4.0 if on else 1.2
	_ring.scale = Vector3.ONE * (1.35 if on else 1.0)
