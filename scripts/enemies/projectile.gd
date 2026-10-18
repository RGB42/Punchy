extends Node3D
## A cork fired by a tin soldier. Flies straight, hurts the player, pops on
## walls. A counter while it is close knocks it back at whoever fired it.

const LIFETIME := 3.0
const HIT_RADIUS := 0.75

var velocity := Vector3.ZERO
var damage := 10.0
var shooter: Node3D
var deflected := false
var _age := 0.0


func _ready() -> void:
	add_to_group("projectile")
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.09
	c.bottom_radius = 0.12
	c.height = 0.28
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.55, 0.32)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.2)
	mat.emission_energy_multiplier = 0.6
	m.material_override = mat
	m.rotation_degrees = Vector3(90, 0, 0)
	add_child(m)
	_face()


func _face() -> void:
	if velocity.length() > 0.1:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.RIGHT)


## Close, alive and coming at the player: a counter now sends it back.
func is_counterable(player: Node3D) -> bool:
	if deflected:
		return false
	var to := player.global_position + Vector3.UP * 1.1 - global_position
	return to.length() < 5.0 and velocity.dot(to) > 0.0


func deflect() -> void:
	deflected = true
	var aim := global_position - velocity.normalized() * 10.0
	if is_instance_valid(shooter):
		aim = shooter.global_position + Vector3.UP * 1.2
	velocity = (aim - global_position).normalized() * velocity.length() * 1.4
	damage *= 2.5
	_face()
	Fx.sparks(global_position, velocity, Color(3.0, 1.5, 0.4), 16, 8.0)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var wall := get_world_3d().direct_space_state.intersect_ray(q)
	if not wall.is_empty():
		Fx.sparks(wall.position, wall.normal, Color(2.0, 1.4, 0.8), 8, 5.0)
		queue_free()
		return
	global_position = to
	if deflected:
		for n in get_tree().get_nodes_in_group("enemy"):
			var e := n as Enemy
			if e.is_alive() and (e.global_position + Vector3.UP * 1.0 * e.size).distance_to(to) < HIT_RADIUS + 0.4 * e.size:
				e.take_hit({"damage": damage, "knock": 10.0, "launch": 4.0, "dir": (velocity * Vector3(1, 0, 1)).normalized(), "breaks_guard": true})
				Game.sfx("hit_heavy")
				Game.hitstop(0.08)
				queue_free()
				return
	else:
		var p := get_tree().get_first_node_in_group("player") as Player
		if p and (p.global_position + Vector3.UP * 1.0).distance_to(to) < HIT_RADIUS:
			if p.take_hit(damage, global_position - velocity.normalized()):
				queue_free()
		# a rolling player is invulnerable: the cork flies on past
