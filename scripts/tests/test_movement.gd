extends TestBase
## Drives the figure through the gym and measures what the design promises:
## jump heights, dash distance, ledge grab + climb up, free climbing, grapple.

const GYM := preload("res://scenes/gym.tscn")
const G := preload("res://scripts/level/gym.gd")

var p: Player


func run() -> void:
	var gym := GYM.instantiate()
	gym.spawn_enemies = false
	add_child(gym)
	await frames(5)
	p = gym.get_node("Player")
	p.scripted = true
	await test_jump()
	await test_double_jump()
	await test_air_dash()
	await test_ledge()
	await test_climb()
	await test_grapple_pull()
	await test_swing()
	await test_fall_respawn()


func place(pos: Vector3, face := Vector3.FORWARD) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.facing = face
	p.move_input = Vector2.ZERO
	p.jump_held = false
	p.view_yaw = 0.0
	p.set_state(Player.State.AIR)
	await seconds(0.6)


func peak_rise(sec: float, on_frame := Callable()) -> float:
	var y0 := p.global_position.y
	var top := y0
	for i in int(sec * Engine.physics_ticks_per_second):
		if on_frame.is_valid():
			on_frame.call(i)
		await frames(1)
		top = maxf(top, p.global_position.y)
	return top - y0


func test_jump() -> void:
	await place(G.SPAWN)
	p.jump_pressed = true
	p.jump_held = true
	var rise := await peak_rise(1.0)
	check(absf(rise - Player.JUMP_APEX) < 0.15, "jump_apex", "rise=%.2f want %.2f" % [rise, Player.JUMP_APEX])
	await place(G.SPAWN)
	p.jump_pressed = true
	p.jump_held = false
	rise = await peak_rise(1.0)
	check(rise < Player.JUMP_APEX * 0.7, "short_hop", "tap rise=%.2f" % rise)


func test_double_jump() -> void:
	await place(G.SPAWN)
	p.jump_pressed = true
	p.jump_held = true
	var apex_frame := int(sqrt(2.0 * Player.GRAVITY_UP * Player.JUMP_APEX) / Player.GRAVITY_UP * Engine.physics_ticks_per_second)
	var rise := await peak_rise(1.6, func(i: int) -> void:
		if i == apex_frame:
			p.jump_pressed = true)
	var want := Player.JUMP_APEX + Player.DOUBLE_APEX
	check(absf(rise - want) < 0.25, "double_jump_apex", "rise=%.2f want %.2f" % [rise, want])
	await seconds(0.4)
	check(p.state == Player.State.GLIDE or p.state == Player.State.GROUND, "glide_on_hold", "state=%s" % Player.State.keys()[p.state])
	await seconds(2.0)
	p.jump_held = false


func test_air_dash() -> void:
	await place(G.SPAWN + Vector3(-12, 0, 0))
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.3)
	p.move_input = Vector2(0, 1)
	var z0 := p.global_position.z
	var x0 := p.global_position.x
	p.dodge_pressed = true
	await frames(1)
	check(p.state == Player.State.DASH, "dash_starts", "state=%s" % Player.State.keys()[p.state])
	await seconds(Player.DASH_TIME)
	var dist := Vector2(p.global_position.x - x0, p.global_position.z - z0).length()
	var want := Player.DASH_SPEED * Player.DASH_TIME
	check(absf(dist - want) < 0.8, "dash_distance", "dist=%.2f want %.2f" % [dist, want])
	p.move_input = Vector2.ZERO


func test_ledge() -> void:
	var wall_front: float = G.LEDGE_WALL.pos.z + G.LEDGE_WALL.size.z / 2.0
	await place(Vector3(0, 0.1, wall_front + 1.2))
	p.move_input = Vector2(0, 1)
	p.jump_pressed = true
	p.jump_held = true
	var grabbed := false
	for i in 120:
		await frames(1)
		if p.state == Player.State.LEDGE:
			grabbed = true
			break
	check(grabbed, "ledge_grab", "state=%s y=%.2f" % [Player.State.keys()[p.state], p.global_position.y])
	if not grabbed:
		return
	p.move_input = Vector2.ZERO
	p.jump_held = false
	await seconds(0.25)
	p.jump_pressed = true
	await seconds(Player.CLIMB_UP_TIME + 0.4)
	var top: float = G.LEDGE_WALL.pos.y + G.LEDGE_WALL.size.y / 2.0
	check(p.state == Player.State.GROUND and absf(p.global_position.y - top) < 0.2, "ledge_climb_up",
		"state=%s y=%.2f want %.2f" % [Player.State.keys()[p.state], p.global_position.y, top])


func test_climb() -> void:
	var front: float = G.CLIMB_WALL.pos.z + G.CLIMB_WALL.size.z / 2.0
	await place(Vector3(G.CLIMB_WALL.pos.x, 0.1, front + 1.0))
	p.move_input = Vector2(0, 1)
	p.jump_pressed = true
	var climbing := false
	for i in 90:
		await frames(1)
		if p.state == Player.State.CLIMB:
			climbing = true
			break
	check(climbing, "climb_attach", "state=%s" % Player.State.keys()[p.state])
	if not climbing:
		return
	for i in 600:
		await frames(1)
		if p.state == Player.State.CLIMB_UP:
			p.move_input = Vector2.ZERO
		if p.state == Player.State.GROUND or p.state == Player.State.AIR:
			break
	await seconds(0.3)
	var top: float = G.CLIMB_WALL.pos.y + G.CLIMB_WALL.size.y / 2.0
	check(p.state == Player.State.GROUND and absf(p.global_position.y - top) < 0.2, "climb_to_top",
		"state=%s y=%.2f want %.2f" % [Player.State.keys()[p.state], p.global_position.y, top])
	p.move_input = Vector2.ZERO


func test_grapple_pull() -> void:
	await place(G.PULL_POINT + Vector3(0, -12.7, 12), Vector3.FORWARD)
	await frames(2)
	check(p.grapple_target != null, "grapple_target_found")
	if p.grapple_target == null:
		return
	p.grapple_pressed = true
	await frames(2)
	check(p.state == Player.State.GRAPPLE_PULL, "grapple_pull_starts", "state=%s" % Player.State.keys()[p.state])
	await seconds(2.0)
	var top: float = G.TOWER.pos.y + G.TOWER.size.y / 2.0
	check(absf(p.global_position.y - top) < 0.3 and p.state == Player.State.GROUND, "grapple_pull_lands_on_top",
		"state=%s y=%.2f want %.2f" % [Player.State.keys()[p.state], p.global_position.y, top])
	p.move_input = Vector2.ZERO


func test_swing() -> void:
	var a_top: float = G.SWING_A.pos.y + G.SWING_A.size.y / 2.0
	await place(Vector3(30, a_top + 0.1, -1.5), Vector3.FORWARD)
	p.move_input = Vector2(0, 1)
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.25)
	p.grapple_pressed = true
	await frames(2)
	check(p.state == Player.State.GRAPPLE_SWING, "swing_starts", "state=%s target=%s" % [Player.State.keys()[p.state], p.grapple_target])
	# Pump forward and let go once past the anchor, like a player would.
	var worst := 0.0
	for i in 360:
		await frames(1)
		if p.state != Player.State.GRAPPLE_SWING:
			break
		var d := (p.global_position + Vector3.UP * 2.0 - G.SWING_POINT).length()
		worst = maxf(worst, d - p._rope_len)
		if p.global_position.z < G.SWING_POINT.z - 3.0 and p.velocity.y < 1.0:
			break
	check(worst < 0.3, "rope_holds", "overshoot=%.2f" % worst)
	p.jump_pressed = true
	p.jump_held = false
	var b_mid: float = G.SWING_B.pos.z
	for i in 300:
		await frames(1)
		var dz := b_mid - p.global_position.z
		p.move_input = Vector2(0, clampf(-dz, -1.0, 1.0))
		if p.state == Player.State.GROUND:
			break
	p.move_input = Vector2.ZERO
	var b_top: float = G.SWING_B.pos.y + G.SWING_B.size.y / 2.0
	check(absf(p.global_position.y - b_top) < 0.3, "swing_reaches_far_side",
		"y=%.2f z=%.2f want y %.2f" % [p.global_position.y, p.global_position.z, b_top])


func test_fall_respawn() -> void:
	await place(G.SPAWN)
	await seconds(1.0)
	p.global_position = Vector3(200, -40, 200)
	await frames(2)
	check(p.global_position.y > -1.0, "respawn_after_fall", "y=%.2f" % p.global_position.y)
