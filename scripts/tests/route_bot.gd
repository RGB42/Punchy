class_name RouteBot
extends TestBase
## Plays a level's traversal links like a player would: stick toward the goal,
## jump and climb what is in the way, grapple, release at the top of a swing,
## steer the landing. Arenas are switched off so the route is tested alone.
## A route test extends this, sets `scene`, and calls load_level() first.

var room: Level
var p: Player


func load_level(scene: PackedScene) -> void:
	room = scene.instantiate()
	add_child(room)
	await frames(10)
	p = room.player
	p.scripted = true
	p.camera = null  # aim with `facing`, deterministic
	for a in room.find_children("*", "Arena", true, false):
		(a as Arena).done = true


func place(pos: Vector3, face: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.facing = face.normalized()
	p.move_input = Vector2.ZERO
	p.jump_held = false
	p.view_yaw = 0.0
	p.set_state(Player.State.AIR)
	await seconds(0.5)


func stick_toward(target: Vector3) -> void:
	var d := Vector3(target.x - p.global_position.x, 0, target.z - p.global_position.z)
	if d.length() < 0.3:
		p.move_input = Vector2.ZERO
		return
	d = d.normalized()
	p.move_input = Vector2(d.x, -d.z)


## Steers toward `target` until standing; climbs up any ledge it catches.
func steer_until_ground(target: Vector3, sec: float) -> void:
	for i in int(sec * 120):
		await frames(1)
		stick_toward(target)
		if p.state == Player.State.LEDGE:
			p.jump_pressed = true
		if p.state == Player.State.GROUND and i > 10:
			break
	p.move_input = Vector2.ZERO


## Walks (and drops) toward target until standing within 1.5 of it, or time out.
func walk_to(target: Vector3, sec: float) -> void:
	for i in int(sec * 120):
		await frames(1)
		stick_toward(target)
		var flat := Vector2(target.x - p.global_position.x, target.z - p.global_position.z).length()
		if flat < 1.5 and p.state == Player.State.GROUND:
			break
	p.move_input = Vector2.ZERO
	await seconds(0.3)


## Gets up onto something higher: walks at it, jumps when blocked, double jumps
## at the top of the jump, pulls up ledges. Done when standing at target height.
func climb_to(target: Vector3, sec: float) -> bool:
	for i in int(sec * 120):
		await frames(1)
		stick_toward(target)
		match p.state:
			Player.State.GROUND:
				if p.global_position.y > target.y - 0.4:
					p.move_input = Vector2.ZERO
					return true
				if p.is_on_wall() or i % 40 == 0:
					p.jump_pressed = true
					p.jump_held = true
			Player.State.AIR:
				if p.velocity.y < 0.5 and p._can_double:
					p.jump_pressed = true
			Player.State.LEDGE:
				p.jump_pressed = true
	p.move_input = Vector2.ZERO
	p.jump_held = false
	return p.global_position.y > target.y - 0.4


func pull(point_name: String) -> bool:
	var anchor: Vector3 = room._markers[point_name].global_position
	p.facing = Vector3(anchor.x - p.global_position.x, 0, anchor.z - p.global_position.z).normalized()
	await frames(2)
	if p.grapple_target == null or p.grapple_target.global_position.distance_to(anchor) > 0.5:
		print("  no grapple target for ", point_name, " got ", p.grapple_target)
		return false
	p.grapple_pressed = true
	await frames(2)
	return p.state == Player.State.GRAPPLE_PULL


## release_near > 0: let go once within that distance of the target (dropping onto it)
## instead of at the top of the forward arc.
func swing(point_name: String, toward: Vector3, release_near := 0.0) -> bool:
	var anchor: Vector3 = room._markers[point_name].global_position
	p.facing = Vector3(anchor.x - p.global_position.x, 0, anchor.z - p.global_position.z).normalized()
	await frames(2)
	if p.grapple_target == null or p.grapple_target.global_position.distance_to(anchor) > 0.5:
		print("  no grapple target for ", point_name, " got ", p.grapple_target)
		return false
	p.grapple_pressed = true
	await frames(2)
	var started := p.state == Player.State.GRAPPLE_SWING
	# pump toward the goal, let go near the top of the forward arc
	var passed := false
	for i in 600:
		await frames(1)
		if p.state != Player.State.GRAPPLE_SWING:
			break
		stick_toward(toward)
		var to_goal := Vector3(toward.x - p.global_position.x, 0, toward.z - p.global_position.z)
		var ahead := Vector3(p.global_position.x - anchor.x, 0, p.global_position.z - anchor.z).dot(to_goal.normalized())
		if ahead > 2.0:
			passed = true
		var near := release_near > 0.0 and to_goal.length() < release_near
		if near or (release_near <= 0.0 and passed and p.velocity.y < 0.5):
			p.jump_pressed = true
			break
	return started
