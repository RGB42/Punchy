extends RouteBot
## The kitchen route, link by link: drawers up to the worktop, faucet across the
## sink, hood hook, herb pot swing to the upper cabinets, along them to the
## fridge, pot rack and lamp swings to the table, then the cookie jar. Plus the
## two hazards: the sink resets you, the hot plate burns.

const ROOM := preload("res://scenes/kitchen.tscn")
const TOP := 10.8


func run() -> void:
	await load_level(ROOM)
	await test_drawers()
	await test_sink_faucet()
	await test_hood()
	await test_herb_swing()
	await test_cabinets_to_fridge()
	await test_swings_to_table()
	await test_cookie_jar()
	await test_water_resets()
	await test_hot_plate_burns()


func test_drawers() -> void:
	await place(Vector3(13.3, 0.1, -13.0), Vector3.FORWARD)
	var ok := await climb_to(Vector3(13.3, TOP, -23.0), 8.0)
	check(ok and p.global_position.z < -19.8, "drawers_to_worktop", "pos=%s" % p.global_position)


func test_sink_faucet() -> void:
	await place(Vector3(-1.5, TOP + 0.1, -23.0), Vector3.LEFT)
	var ok := await pull("grapple_pull_faucet")
	await steer_until_ground(Vector3(-15.0, TOP, -23.0), 3.0)
	check(ok and p.global_position.x < -12.0 and absf(p.global_position.y - TOP) < 0.4, "faucet_over_sink",
		"pulled=%s pos=%s" % [ok, p.global_position])


func test_hood() -> void:
	await place(Vector3(-14.0, TOP + 0.1, -22.0), Vector3.LEFT)
	var ok := await pull("grapple_pull_hood")
	await steer_until_ground(Vector3(-20.0, 21.0, -24.0), 3.0)
	check(ok and absf(p.global_position.y - 21.0) < 0.4, "hook_onto_hood", "pulled=%s pos=%s" % [ok, p.global_position])


func test_herb_swing() -> void:
	await place(Vector3(-16.0, 21.1, -24.0), Vector3.RIGHT)
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.2)
	var ok := await swing("grapple_swing_herbs", Vector3(6.0, 25.8, -25.0))
	await seconds(0.15)
	var pulled := await pull("grapple_pull_cabinet")
	await steer_until_ground(Vector3(6.0, 25.8, -25.0), 3.0)
	p.jump_held = false
	check(ok and pulled and absf(p.global_position.y - 25.8) < 0.4 and p.global_position.x > 1.0, "herb_swing_then_pull_to_cabinets",
		"swung=%s pulled=%s pos=%s" % [ok, pulled, p.global_position])


func test_cabinets_to_fridge() -> void:
	await place(Vector3(12.0, 25.9, -24.0), Vector3.RIGHT)
	await walk_to(Vector3(23.4, 21.6, -23.0), 5.0)
	check(absf(p.global_position.y - 21.6) < 0.4 and p.global_position.x > 19.8, "cabinets_to_fridge", "pos=%s" % p.global_position)


func test_swings_to_table() -> void:
	await place(Vector3(21.0, 21.7, -20.5), Vector3(-1, 0, 1))
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.15)
	var ok1 := await swing("grapple_swing_rack", Vector3(2.0, 20.0, 4.0))
	await seconds(0.15)
	var ok2 := await drop_from_lamp()
	await steer_until_ground(Vector3(2.0, 9.0, 6.0), 4.0)
	p.jump_held = false
	var on_table := absf(p.global_position.y - 9.0) < 0.4 and absf(p.global_position.x - 2.0) < 7.2 \
		and absf(p.global_position.z - 6.0) < 4.8
	check(ok1 and ok2 and on_table, "rack_and_lamp_to_table", "rack=%s lamp=%s pos=%s" % [ok1, ok2, p.global_position])


func test_cookie_jar() -> void:
	room._open_goal()
	await place(Vector3(2.0, 9.1, 6.0), Vector3.RIGHT)
	await steer_until_ground(room._pos("goal"), 3.0)
	for i in 120:
		await frames(1)
		stick_toward(room._pos("goal"))
		if room._won:
			break
	check(room._won, "cookie_jar_goal", "pos=%s" % p.global_position)


func test_water_resets() -> void:
	room._won = false
	Game._slowmo_until = 0  # the cookie-jar win's slow motion would skew the safe spot
	await place(Vector3(-1.0, TOP + 0.1, -22.5), Vector3.LEFT)
	await seconds(0.6)  # becomes the safe spot
	var hp := p.combat.health
	p.global_position = Vector3(-7.4, TOP + 1.0, -23.4)  # drop into the basin
	p.velocity = Vector3.ZERO
	p.set_state(Player.State.AIR)
	await seconds(1.0)
	check(p.combat.health < hp and p.global_position.y > TOP - 0.5 and p.global_position.x > -3.0, "sink_water_resets",
		"hp %.0f->%.0f pos=%s" % [hp, p.combat.health, p.global_position])


func test_hot_plate_burns() -> void:
	p.combat.heal_full()
	p.element = "frost"  # fire does not burn Blaze, by design
	await place(Vector3(-17.5, TOP + 0.3, -21.6), Vector3.LEFT)
	await seconds(1.0)
	var burned := p.combat.health < PlayerCombat.MAX_HEALTH
	check(burned, "hot_plate_burns", "hp=%.1f" % p.combat.health)

## The lamp hangs right over the table: hold still and let go at a turning
## point while above the table top, then drop onto it.
func drop_from_lamp() -> bool:
	var anchor: Vector3 = room._markers["grapple_swing_lamp"].global_position
	p.facing = Vector3(anchor.x - p.global_position.x, 0, anchor.z - p.global_position.z).normalized()
	await frames(2)
	if p.grapple_target == null or p.grapple_target.global_position.distance_to(anchor) > 0.5:
		return false
	p.grapple_pressed = true
	await frames(2)
	if p.state != Player.State.GRAPPLE_SWING:
		return false
	p.move_input = Vector2.ZERO
	var last_vy := p.velocity.y
	for i in 900:
		await frames(1)
		var over := absf(p.global_position.x - 2.0) < 6.0 and absf(p.global_position.z - 6.0) < 4.0
		if last_vy > 0.0 and p.velocity.y <= 0.0 and over:
			p.grapple_pressed = true  # let go without the jump boost
			return true
		last_vy = p.velocity.y
	return false
