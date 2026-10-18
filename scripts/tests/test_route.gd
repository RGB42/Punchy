extends TestBase
## Plays every traversal link of the kids' room like a player would (stick toward
## the goal, grapple, release at the top of the swing, steer the landing) and
## checks each one ends standing on the next platform. Arenas are disabled so the
## route is tested on its own.

const ROOM := preload("res://scenes/kids_room.tscn")

var room: Node3D
var p: Player


func run() -> void:
	room = ROOM.instantiate()
	add_child(room)
	await frames(10)
	p = room.player
	p.scripted = true
	p.camera = null  # aim with `facing`, deterministic
	for a in room.find_children("*", "Arena", true, false):
		(a as Arena).done = true
	await test_leave_wardrobe()
	await test_ladder()
	await test_plant_swing()
	await test_lamp_and_mobile()
	await test_window()


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


func swing(point_name: String, toward: Vector3) -> bool:
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
		if passed and p.velocity.y < 0.5:
			p.jump_pressed = true
			break
	return started


func test_leave_wardrobe() -> void:
	await place(room._pos("spawn_player"), Vector3.FORWARD)
	p.jump_pressed = true
	p.jump_held = true
	await steer_until_ground(Vector3(17.4, 0, 12), 3.0)
	p.jump_held = false
	await steer_until_ground(Vector3(17.4, 0, 12), 2.0)
	check(p.global_position.y < 0.5 and p.global_position.z < 19.5, "leave_wardrobe", "pos=%s" % p.global_position)


func test_ladder() -> void:
	await place(Vector3(-11, 0.2, 17.4), Vector3.LEFT)
	p.move_input = Vector2(-1, 0)
	p.jump_pressed = true
	var climbing := false
	for i in 1200:
		await frames(1)
		if p.state == Player.State.CLIMB:
			climbing = true
			p.move_input = Vector2(0, 1)
		if p.state == Player.State.CLIMB_UP:
			p.move_input = Vector2.ZERO
		if climbing and p.state == Player.State.GROUND:
			break
		if i > 60 and not climbing:
			break
	await steer_until_ground(Vector3(-20, 0, 10), 1.5)
	check(climbing and p.global_position.y > 19.5, "ladder_to_loft_bed", "climbed=%s pos=%s" % [climbing, p.global_position])


func test_plant_swing() -> void:
	await place(Vector3(-21, 20.9, 0.5), Vector3.FORWARD)
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.2)
	var ok := await swing("grapple_swing_plant", Vector3(-17, 21.6, -23.4))
	await steer_until_ground(Vector3(-17, 21.6, -23.4), 3.0)
	p.jump_held = false
	check(ok and absf(p.global_position.y - 21.6) < 0.4 and p.global_position.z < -19.8, "plant_swing_to_shelf", "pos=%s" % p.global_position)


func test_lamp_and_mobile() -> void:
	await place(Vector3(-10.6, 21.7, -22), Vector3(1, 0, 1))
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.15)
	var ok1 := await swing("grapple_swing_lamp", Vector3(13, 20, -15))
	await seconds(0.15)
	var ok2 := await swing("grapple_swing_mobile", Vector3(22, 9, -16))
	await steer_until_ground(Vector3(22, 9, -16), 4.0)
	p.jump_held = false
	var on_desk := p.global_position.x > 17.4 and p.global_position.y > 8.8
	check(ok1 and ok2 and on_desk, "lamp_mobile_to_desk", "lamp=%s mobile=%s pos=%s" % [ok1, ok2, p.global_position])


func test_window() -> void:
	room._open_goal()
	await place(Vector3(19, 9.1, -22), Vector3.LEFT)
	p.facing = (room._pos("grapple_pull_window") - p.global_position).normalized()
	await frames(2)
	p.grapple_pressed = true
	await seconds(1.0)
	await steer_until_ground(Vector3(2, 13.2, -26), 3.0)
	check(room._won, "window_reached_goal", "pos=%s won=%s" % [p.global_position, room._won])
