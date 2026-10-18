extends TestBase
## Frost and Volt: their models load and their powers do what the select
## screen promises.

const GYM := preload("res://scenes/gym.tscn")
const G := preload("res://scripts/level/gym.gd")
const HOME := Vector3(0, 0.1, 10)

var p: Player
var gym: Node3D


func run() -> void:
	await load_hero("frost")
	await test_frost_freezes()
	await test_frozen_takes_double()
	await test_ice_platform()
	await load_hero("volt")
	await test_chain_lightning()
	await test_blink()
	await load_hero("stone")
	await test_quake()
	await test_rock_grip()
	await load_hero("venom")
	await test_poison_cloud()
	await test_vine()
	await load_hero("gale")
	await test_tornado()
	await test_updraft()
	await load_hero("shade")
	await test_shadow_chain()
	await test_phase_up()
	await test_select_screen()
	Game.hero = "blaze"


func test_select_screen() -> void:
	gym.queue_free()
	var sel: Node3D = (load("res://scenes/hero_select.tscn") as PackedScene).instantiate()
	add_child(sel)
	await frames(3)
	var all_free := Heroes.ALL.all(func(h: Dictionary) -> bool: return not h.get("locked", false))
	sel._select(6)
	sel.choose()
	check(all_free and sel._leaving and Game.hero == "shade", "select_all_seven", "hero=%s" % Game.hero)
	sel.set_process(false)
	sel.get_tree().paused = false


func load_hero(id: String) -> void:
	if gym:
		gym.queue_free()
		await frames(2)
	Game.hero = id
	gym = GYM.instantiate()
	gym.spawn_enemies = false
	add_child(gym)
	await frames(5)
	p = gym.get_node("Player")
	p.scripted = true
	p.camera = null  # aim with facing, deterministic
	check(p.element == id and p.visual.get_child(0).name != "", "model_" + id, "element=%s" % p.element)


func reset_player(pos := HOME) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.facing = Vector3.FORWARD
	p.move_input = Vector2.ZERO
	p.set_state(Player.State.AIR)
	p.combat.heal_full()
	await seconds(0.5)


func spawn(offset: Vector3, hp := 100.0) -> Enemy:
	var e := Enemy.new()
	e.aggro_range = 0.0
	e.max_health = hp
	e.position = HOME + offset
	e.rotation.y = PI
	gym.add_child(e)
	await frames(3)
	return e


func real_wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func test_frost_freezes() -> void:
	await reset_player()
	var a := await spawn(Vector3(1.0, 0, -3))
	var b := await spawn(Vector3(-1.2, 0, -4.5))
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.6)
	check(a.state == Enemy.State.FROZEN and b.state == Enemy.State.FROZEN, "frost_blast_freezes",
		"a=%s b=%s" % [Enemy.State.keys()[a.state], Enemy.State.keys()[b.state]])


func test_frozen_takes_double() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -3))
	e._freeze(3.0)
	var hp := e.health
	e.take_hit({"damage": 10.0, "dir": Vector3.FORWARD})
	check(is_equal_approx(hp - e.health, 20.0) and e.state != Enemy.State.FROZEN, "frozen_shatters_double",
		"lost=%.0f state=%s" % [hp - e.health, Enemy.State.keys()[e.state]])


func test_ice_platform() -> void:
	await reset_player()
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.4)
	var y := p.global_position.y
	p.power_pressed = true
	await seconds(1.5)
	p.jump_held = false
	p.jump_pressed = true
	await seconds(0.3)
	var recharged := p._can_rocket
	await seconds(1.0)
	check(not recharged, "ice_no_staircase", "can_rocket after landing on ice=%s" % recharged)
	check(p.global_position.y > 1.5 and absf(p.global_position.y - y) < 1.5,
		"ice_platform_holds", "y=%.2f (cast at %.2f) state=%s" % [p.global_position.y, y, Player.State.keys()[p.state]])
	await seconds(3.5)
	check(p.global_position.y < 0.5, "ice_platform_melts", "y=%.2f" % p.global_position.y)


func test_chain_lightning() -> void:
	await reset_player()
	var a := await spawn(Vector3(0, 0, -4))
	var b := await spawn(Vector3(4, 0, -7))
	var c := await spawn(Vector3(8, 0, -9))
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.4)
	var all := [a, b, c].all(func(e: Enemy) -> bool: return e.health < 100.0)
	var stunned := [a, b, c].all(func(e: Enemy) -> bool: return e.state == Enemy.State.STAGGER)
	check(all and stunned, "chain_hits_three", "hp=%.0f/%.0f/%.0f" % [a.health, b.health, c.health])


func test_blink() -> void:
	await reset_player(Vector3(-12, 0.1, 10))
	p.jump_pressed = true
	await seconds(0.25)
	var z0 := p.global_position.z
	p.move_input = Vector2(0, 1)
	p.power_pressed = true
	await frames(2)
	p.move_input = Vector2.ZERO
	var moved := z0 - p.global_position.z
	check(absf(moved - Player.BLINK_DIST) < 1.0, "blink_open_space", "moved=%.2f" % moved)
	# toward the ledge wall (front face z=-13.5): stops in front of it
	await reset_player(Vector3(0, 0.1, -9))
	p.jump_pressed = true
	await seconds(0.25)
	p.move_input = Vector2(0, 1)
	p.power_pressed = true
	await frames(2)
	p.move_input = Vector2.ZERO
	var wall_z: float = G.LEDGE_WALL.pos.z + G.LEDGE_WALL.size.z / 2.0
	check(p.global_position.z > wall_z, "blink_stops_at_wall", "z=%.2f wall=%.2f" % [p.global_position.z, wall_z])

func test_quake() -> void:
	await reset_player()
	var a := await spawn(Vector3(3, 0, 0))
	var b := await spawn(Vector3(-3, 0, -2))
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.6)
	check(a.state == Enemy.State.AIRBORNE and b.state == Enemy.State.AIRBORNE, "quake_launches_all_around",
		"a=%s b=%s" % [Enemy.State.keys()[a.state], Enemy.State.keys()[b.state]])
	await real_wait(1.5)


func test_rock_grip() -> void:
	# the gym's ledge wall is not climbable; Stone grips it anyway
	var wall_front: float = G.LEDGE_WALL.pos.z + G.LEDGE_WALL.size.z / 2.0
	await reset_player(Vector3(0, 0.1, wall_front + 0.8))
	p.jump_pressed = true
	await seconds(0.15)
	p.power_pressed = true
	await frames(2)
	var gripped := p.state == Player.State.CLIMB and p._gripping and not p._can_rocket
	await seconds(Player.GRIP_TIME + 0.3)
	check(gripped and p.state != Player.State.CLIMB, "rock_grip_any_wall",
		"gripped=%s state=%s can_rocket=%s" % [gripped, Player.State.keys()[p.state], p._can_rocket])


func test_poison_cloud() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -5))
	e._enter(Enemy.State.STRAFE)
	e.player = p
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.5)
	var hp := e.health
	e._cooldown = 0.0
	var attacked := false
	for i in 120:
		await frames(1)
		attacked = attacked or e.state in [Enemy.State.APPROACH, Enemy.State.WINDUP, Enemy.State.ATTACK]
	check(e._poison_t > 0.0 and e.health < hp and not attacked, "poison_drains_and_pacifies",
		"poison=%.1f hp %.1f->%.1f attacked=%s" % [e._poison_t, hp, e.health, attacked])


func test_vine() -> void:
	# aim at the tall block and get pulled up to it
	await reset_player(Vector3(-8, 0.1, 2))
	p.jump_pressed = true
	await seconds(0.2)
	p.facing = (G.TALL_BLOCK.pos + Vector3(0, 1.5, 0) - (p.global_position + Vector3.UP * 1.5)).normalized()
	var y0 := p.global_position.y
	p.power_pressed = true
	await frames(2)
	var pulling := p.state == Player.State.GRAPPLE_PULL
	await seconds(0.5)
	check(pulling and p.global_position.y > y0 + 1.5 and p.state == Player.State.CLIMB, "vine_pulls_anywhere",
		"pulling=%s rose=%.1f state=%s" % [pulling, p.global_position.y - y0, Player.State.keys()[p.state]])


func test_tornado() -> void:
	await reset_player()
	var a := await spawn(Vector3(5, 0, 0))
	var d0 := a.global_position.distance_to(p.global_position)
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.45)
	check(a.state == Enemy.State.AIRBORNE, "tornado_lifts", "state=%s" % Enemy.State.keys()[a.state])
	await real_wait(1.5)
	var d1 := Vector2(a.global_position.x - p.global_position.x, a.global_position.z - p.global_position.z).length()
	check(d1 < d0, "tornado_pulls_in", "distance %.1f -> %.1f" % [d0, d1])


func test_updraft() -> void:
	await reset_player()
	p.jump_pressed = true
	await seconds(0.3)
	var y0 := p.global_position.y
	p.power_pressed = true
	await seconds(2.0)
	check(p.state == Player.State.GLIDE and p.global_position.y > y0 + 4.0, "updraft_climbs",
		"state=%s rose=%.1f" % [Player.State.keys()[p.state], p.global_position.y - y0])
	await seconds(4.0)


func test_shadow_chain() -> void:
	await reset_player()
	var a := await spawn(Vector3(0, 0, -4))
	var b := await spawn(Vector3(4, 0, -6))
	var c := await spawn(Vector3(-4, 0, -6))
	c.shielded = true
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(1.0)
	var hit := [a, b, c].all(func(e: Enemy) -> bool: return not is_instance_valid(e) or e.health < 100.0)
	check(hit, "shadow_chain_three_through_shield", "hp=%s" % [[a, b, c].map(func(e: Enemy) -> String: return "%.0f" % e.health if is_instance_valid(e) else "x")])


func test_phase_up() -> void:
	await reset_player()
	p.jump_pressed = true
	await seconds(0.25)
	var y0 := p.global_position.y
	p.power_pressed = true
	await frames(2)
	check(absf(p.global_position.y - y0 - Player.PHASE_HEIGHT) < 0.6, "phase_up", "rose=%.2f" % (p.global_position.y - y0))
