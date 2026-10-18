extends RouteBot
## Plays every traversal link of the kids' room (see RouteBot) and checks each
## one ends standing on the next platform.

const ROOM := preload("res://scenes/kids_room.tscn")


func run() -> void:
	await load_level(ROOM)
	await test_leave_wardrobe()
	await test_ladder()
	await test_plant_swing()
	await test_lamp_and_mobile()
	await test_window()

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
