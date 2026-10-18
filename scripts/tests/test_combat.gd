extends TestBase
## Combat promises from the plan: a combo drops a grunt in <= 4 hits, shields
## block light hits until a heavy breaks them, counters stagger, hitstop never
## exceeds 0.15 s, rolls are invulnerable, slam and flame hit groups.

const GYM := preload("res://scenes/gym.tscn")
const HOME := Vector3(0, 0.1, 10)

var p: Player
var gym: Node3D


func run() -> void:
	gym = GYM.instantiate()
	gym.spawn_enemies = false
	add_child(gym)
	await frames(5)
	p = gym.get_node("Player")
	p.scripted = true
	await test_hitstop_cap()
	await test_combo_kills()
	await test_shield()
	await test_counter()
	await test_enemy_hurts_player()
	await test_roll_iframes()
	await test_slam()
	await test_flame()
	await test_arena()
	await test_finisher()
	await test_ground_finish()
	await test_juggle()
	await test_wall_splat()


func test_finisher() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -5), true, 200.0)
	p.combat._set_combo(PlayerCombat.FINISHER_COMBO)
	check(p.combat.finisher_ready(), "finisher_ready_at_8")
	p.heavy_pressed = true
	var cut := false
	for i in 200:
		await frames(1)
		var cam := gym.get_node("Camera") as PlayerCamera
		cut = cut or cam._cine_t > 0.0
	await real_wait(0.6)
	check(cut, "finisher_camera_cut")
	var dead := not is_instance_valid(e) or not e.is_alive()
	check(dead and p.combat.finisher_at == PlayerCombat.FINISHER_COMBO * 2, "finisher_takes_down",
		"dead=%s next_at=%d" % [dead, p.combat.finisher_at])
	await real_wait(0.6)


func test_ground_finish() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -3))
	e._enter(Enemy.State.DOWN)
	e._t = -5.0  # stay down
	p.attack_pressed = true
	await real_wait(1.0)
	check(not is_instance_valid(e) or not e.is_alive(), "ground_takedown_kills")


func test_juggle() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -2.5), false, 200.0)
	p.heavy_pressed = true
	await real_wait(0.45)
	check(e.state == Enemy.State.AIRBORNE, "uppercut_launches", "state=%s" % Enemy.State.keys()[e.state])
	p.jump_pressed = true
	await frames(2)
	var rising := p.state == Player.State.AIR and p.velocity.y > 5.0
	await real_wait(0.3)
	p.attack_pressed = true
	await real_wait(0.35)
	var hp := e.health
	var height := e.global_position.y - HOME.y
	check(rising and hp < 200.0 - 24.0 and height > 1.5 and e.state == Enemy.State.AIRBORNE, "air_juggle",
		"rising=%s hp=%.0f height=%.1f state=%s" % [rising, hp, height, Enemy.State.keys()[e.state]])
	await real_wait(2.0)


func test_wall_splat() -> void:
	await reset_player()
	# the gym's ledge wall front face is at z = -13.5
	var e := await spawn(Vector3(0, 0, -21.5), false, 40.0)
	e.take_hit({"damage": 1.0, "knock": 14.0, "dir": Vector3.FORWARD})
	await real_wait(0.6)
	check(e.health <= 40.0 - 1.0 - Enemy.SPLAT_DAMAGE + 0.01, "wall_splat_hurts", "hp=%.1f" % e.health)


func test_arena() -> void:
	await reset_player()
	var arena := Arena.new()
	arena.position = Vector3(-30, 0, 30)
	arena.size = Vector3(14, 6, 14)
	arena.waves = [{"count": 2}, {"count": 1}]
	arena.barriers = [Transform3D(Basis.from_scale(Vector3(4, 6, 1)), Vector3(0, 0, 7.5))]
	gym.add_child(arena)
	var cleared := [false]
	arena.cleared.connect(func() -> void: cleared[0] = true)
	await frames(2)
	p.global_position = arena.position + Vector3(0, 0.1, 0)
	await seconds(0.3)
	check(arena.active and arena.wave == 0, "arena_starts", "active=%s wave=%d" % [arena.active, arena.wave])
	var block: StaticBody3D = arena._blocks[0]
	await seconds(0.6)
	check(block.collision_layer == Arena.BARRIER_LAYER and absf(block.position.y) < 0.05, "barrier_up", "y=%.2f" % block.position.y)
	for w in 2:
		await seconds(0.3)
		for e in arena._spawned:
			if is_instance_valid(e) and e.is_alive():
				e.take_hit({"damage": 999.0, "dir": Vector3.FORWARD})
		await seconds(1.6)
	check(cleared[0] and arena.done and block.collision_layer == 0, "arena_clears", "wave=%d cleared=%s" % [arena.wave, cleared[0]])


func reset_player() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	p.global_position = HOME
	p.velocity = Vector3.ZERO
	p.facing = Vector3.FORWARD
	p.move_input = Vector2.ZERO
	p.set_state(Player.State.AIR)
	p.combat.heal_full()
	p.combat._invuln = 0.0
	await seconds(0.5)


## A dummy that never attacks on its own. facing_player turns it toward +Z.
func spawn(offset: Vector3, shielded := false, hp := 40.0) -> Enemy:
	var e := Enemy.new()
	e.shielded = shielded
	e.max_health = hp
	e.aggro_range = 0.0
	e.position = HOME + offset
	e.rotation.y = PI
	gym.add_child(e)
	await frames(3)
	return e


func real_wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func test_hitstop_cap() -> void:
	Game.hitstop(1.0)
	Game.hitstop(0.05)
	var left := Game._hitstop_until - Time.get_ticks_msec()
	check(left <= 150, "hitstop_capped", "frozen for %d ms" % left)
	# Wall clock, not a timer: headless timers count the load-spike frame.
	var until := Game._hitstop_until
	while Time.get_ticks_msec() < until + 20:
		await get_tree().process_frame
	await get_tree().process_frame
	check(is_equal_approx(Engine.time_scale, 1.0), "hitstop_ends", "time_scale=%.2f" % Engine.time_scale)


func test_combo_kills() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -4))
	var presses := 0
	for i in 8:
		if not is_instance_valid(e) or not e.is_alive():
			break
		p.attack_pressed = true
		presses += 1
		await real_wait(0.32)
	var dead := not is_instance_valid(e) or not e.is_alive()
	check(dead and presses <= 4, "combo_kills_grunt", "dead=%s presses=%d combo=%d" % [dead, presses, p.combat.combo])
	await real_wait(1.0)


func test_shield() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -3), true, 60.0)
	p.attack_pressed = true
	await real_wait(0.6)
	check(is_equal_approx(e.health, 60.0), "shield_blocks_jab", "health=%.1f" % e.health)
	await real_wait(0.6)
	p.heavy_pressed = true
	await real_wait(0.8)
	check(not e.shielded and e.health < 60.0, "heavy_breaks_shield", "shielded=%s health=%.1f" % [e.shielded, e.health])


func test_counter() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -2.5))
	e.player = p
	e._enter(Enemy.State.WINDUP)
	await frames(10)
	p.counter_pressed = true
	await real_wait(0.5)
	var staggered := not is_instance_valid(e) or e.state in [Enemy.State.STAGGER, Enemy.State.AIRBORNE, Enemy.State.DOWN, Enemy.State.DEAD]
	check(staggered and p.combat.health == PlayerCombat.MAX_HEALTH, "counter_staggers",
		"state=%s player_hp=%.0f" % [Enemy.State.keys()[e.state] if is_instance_valid(e) else "freed", p.combat.health])


func test_enemy_hurts_player() -> void:
	await reset_player()
	var e := await spawn(Vector3(0, 0, -1.8))
	e.player = p
	e._enter(Enemy.State.WINDUP)
	await real_wait(Enemy.WINDUP_TIME + 0.4)
	check(p.combat.health < PlayerCombat.MAX_HEALTH, "enemy_hits_player", "hp=%.0f" % p.combat.health)


func test_roll_iframes() -> void:
	await reset_player()
	p.dodge_pressed = true
	await frames(12)
	var during := p.combat.is_invulnerable()
	await real_wait(0.4)
	var after := p.combat.is_invulnerable()
	check(during and not after, "roll_iframes", "during=%s after=%s" % [during, after])


func test_slam() -> void:
	await reset_player()
	var a := await spawn(Vector3(2, 0, -1))
	var b := await spawn(Vector3(-2, 0, -1))
	p.jump_pressed = true
	p.jump_held = true
	await seconds(0.35)
	p.heavy_pressed = true
	await real_wait(1.0)
	p.jump_held = false
	var hit_a := not is_instance_valid(a) or a.health < a.max_health
	var hit_b := not is_instance_valid(b) or b.health < b.max_health
	check(hit_a and hit_b, "slam_hits_group", "a=%s b=%s" % [hit_a, hit_b])


func test_flame() -> void:
	await reset_player()
	var a := await spawn(Vector3(1.2, 0, -3))
	var b := await spawn(Vector3(-1.2, 0, -4))
	p.combat._set_energy(100.0)
	p.power_pressed = true
	await real_wait(0.8)
	var hit_a := not is_instance_valid(a) or a.health < a.max_health
	var hit_b := not is_instance_valid(b) or b.health < b.max_health
	check(hit_a and hit_b and is_equal_approx(p.combat.energy, 100.0 - Moves.FLAME["energy"] + PlayerCombat.ENERGY_PER_HIT * 2),
		"flame_hits_cone", "a=%s b=%s energy=%.0f" % [hit_a, hit_b, p.combat.energy])
