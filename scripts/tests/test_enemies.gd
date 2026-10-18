extends TestBase
## The enemy roster: tin soldier corks (hit, and countered back), doll speed,
## and the king's armour, slam shockwave and summons.

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
	await test_cork_hits()
	await test_cork_counter()
	await test_doll_is_quick()
	await test_king_armour()
	await test_king_slam()
	await test_king_summons_and_guard_falls()
	await test_robot_armour()
	await test_dino_tail()
	await test_dragon_bite_counter()
	await test_dragon_breath()
	await test_dragon_dive()
	await test_dragon_summons_dinos()


func test_robot_armour() -> void:
	await reset_player()
	var r := await spawn("robot", Vector3(0, 0, -3))
	r._enter(Enemy.State.STRAFE)
	var hp := r.health
	r.take_hit({"damage": 10.0, "knock": 5.0, "dir": Vector3.FORWARD})
	await frames(2)
	var light_ok := r.state == Enemy.State.STRAFE and r.health < hp
	r.take_hit({"damage": 24.0, "knock": 7.0, "launch": 13.0, "dir": Vector3.FORWARD, "breaks_guard": true})
	await frames(2)
	check(light_ok and r.state == Enemy.State.AIRBORNE, "robot_armour",
		"light_ok=%s after heavy=%s" % [light_ok, Enemy.State.keys()[r.state]])


func test_dino_tail() -> void:
	await reset_player()
	var d := await spawn("dino", Vector3(0, 0, -2.5))
	d._attack = "tail"
	d._start_windup()
	await real_wait(d.windup_time + 0.5)
	var hit_ground := p.combat.health < PlayerCombat.MAX_HEALTH
	await reset_player()
	d = await spawn("dino", Vector3(0, 0, -2.5))
	d._attack = "tail"
	d._start_windup()
	await real_wait(d.windup_time - 0.15)
	p.jump_pressed = true
	p.jump_held = true
	await real_wait(0.6)
	p.jump_held = false
	check(hit_ground and p.combat.health == PlayerCombat.MAX_HEALTH, "dino_tail_jumpable",
		"hit_on_ground=%s hp_after_jump=%.0f" % [hit_ground, p.combat.health])


func spawn_dragon(offset: Vector3) -> Dragon:
	var d := Dragon.new()
	d.aggro_range = 0.0
	d.position = HOME + offset
	d.rotation.y = PI
	gym.add_child(d)
	await frames(3)
	d.player = p
	return d


func test_dragon_bite_counter() -> void:
	await reset_player()
	var d := await spawn_dragon(Vector3(0, 0, -4))
	d._attack = "bite"
	d._start_windup()
	await frames(8)
	check(d.is_counterable(), "dragon_bite_counterable")
	p.counter_pressed = true
	await real_wait(0.5)
	check(d.state == Enemy.State.STAGGER and p.combat.health == PlayerCombat.MAX_HEALTH, "dragon_countered",
		"state=%s hp=%.0f" % [Enemy.State.keys()[d.state], p.combat.health])
	d.queue_free()


func test_dragon_breath() -> void:
	await reset_player()
	var d := await spawn_dragon(Vector3(0, 0, -6))
	d._attack = "breath"
	d._start_windup()
	check(not d.is_counterable(), "dragon_breath_not_counterable")
	await real_wait(d.windup_time + 1.0)
	check(p.combat.health < PlayerCombat.MAX_HEALTH, "dragon_breath_burns", "hp=%.0f" % p.combat.health)
	d.queue_free()


func test_dragon_dive() -> void:
	await reset_player()
	var d := await spawn_dragon(Vector3(0, 0, -6))
	d._attack = "dive"
	d._start_windup()
	var peak := 0.0
	var marked := false
	for i in int((d.windup_time + 2.6) * 120):
		await frames(1)
		peak = maxf(peak, d.global_position.y - d.home.y)
		marked = marked or is_instance_valid(d._marker)
	check(peak > 6.0 and marked and absf(d.global_position.y - d.home.y) < 0.6, "dragon_dive",
		"peak=%.1f marked=%s back_down=%.2f" % [peak, marked, d.global_position.y - d.home.y])
	check(p.combat.health < PlayerCombat.MAX_HEALTH, "dragon_dive_hits_grounded", "hp=%.0f" % p.combat.health)
	d.queue_free()


func test_dragon_summons_dinos() -> void:
	await reset_player()
	var d := await spawn_dragon(Vector3(0, 0, -7))
	d._enter(Enemy.State.STRAFE)
	d.health = d.max_health * 0.4
	d._pick_boss_attack(7.0)
	await frames(3)
	var kinds := d._summons.map(func(e: Enemy) -> String: return e.kind)
	check(kinds == ["dino", "dino"], "dragon_summons_dinos", "summoned=%s" % [kinds])
	d.take_hit({"damage": 9999.0, "dir": Vector3.FORWARD, "breaks_guard": true})
	await real_wait(0.3)
	check(not is_instance_valid(d) or not d.is_alive(), "dragon_dies")


func reset_player() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for c in get_tree().get_nodes_in_group("projectile"):
		c.queue_free()
	p.global_position = HOME
	p.velocity = Vector3.ZERO
	p.facing = Vector3.FORWARD
	p.move_input = Vector2.ZERO
	p.set_state(Player.State.AIR)
	p.combat.heal_full()
	p.combat._invuln = 0.0
	Game._slowmo_until = 0  # a boss death's slow motion must not leak into the next test
	await seconds(0.5)


func spawn(kind: String, offset: Vector3) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.aggro_range = 0.0
	e.position = HOME + offset
	e.rotation.y = PI
	gym.add_child(e)
	await frames(3)
	e.player = p
	return e


func real_wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func test_cork_hits() -> void:
	await reset_player()
	var s := await spawn("soldier", Vector3(0, 0, -10))
	s._attack = "shoot"
	s._start_windup()
	await real_wait(s.windup_time + 1.0)
	check(p.combat.health < PlayerCombat.MAX_HEALTH, "cork_hits_player", "hp=%.0f" % p.combat.health)


func test_cork_counter() -> void:
	await reset_player()
	var s := await spawn("soldier", Vector3(0, 0, -10))
	s._attack = "shoot"
	s._start_windup()
	var countered := false
	for i in 400:
		await frames(1)
		if p.combat.counterable_projectile():
			p.counter_pressed = true
			countered = true
			break
	await real_wait(1.0)
	var hurt := not is_instance_valid(s) or s.health < s.max_health
	check(countered and hurt and p.combat.health == PlayerCombat.MAX_HEALTH, "cork_countered_back",
		"countered=%s soldier_hurt=%s player_hp=%.0f" % [countered, hurt, p.combat.health])


func test_doll_is_quick() -> void:
	await reset_player()
	var d := await spawn("doll", Vector3(0, 0, -3))
	var k := await spawn("knight", Vector3(3, 0, -3))
	check(d.windup_time < k.windup_time * 0.7 and d.move_speed > k.move_speed, "doll_faster_than_knight",
		"windup %.2f vs %.2f" % [d.windup_time, k.windup_time])


func test_king_armour() -> void:
	await reset_player()
	var king := await spawn("king", Vector3(0, 0, -5))
	king._enter(Enemy.State.STRAFE)
	var hp := king.health
	king.take_hit({"damage": 10.0, "knock": 5.0, "dir": Vector3.FORWARD, "breaks_guard": false})
	await frames(2)
	var light_ok := king.state == Enemy.State.STRAFE
	king._yaw = 0.0  # facing away: the shield cannot block
	king.take_hit({"damage": 24.0, "knock": 7.0, "launch": 13.0, "dir": Vector3.FORWARD, "breaks_guard": true})
	await frames(2)
	check(light_ok and king.state == Enemy.State.STAGGER and king.health < hp, "king_armour",
		"after light=%s after heavy=%s hp %.0f->%.0f" % [light_ok, Enemy.State.keys()[king.state], hp, king.health])


func test_king_slam() -> void:
	await reset_player()
	var king := await spawn("king", Vector3(0, 0, -5))
	king._attack = "slam"
	king._start_windup()
	await real_wait(king.windup_time * 1.4 + 1.0)
	check(p.combat.health < PlayerCombat.MAX_HEALTH, "king_slam_wave_hits_grounded", "hp=%.0f" % p.combat.health)


func test_king_summons_and_guard_falls() -> void:
	await reset_player()
	var king := await spawn("king", Vector3(0, 0, -6))
	king._enter(Enemy.State.STRAFE)
	king.health = king.max_health * 0.4
	king._pick_boss_attack(6.0)
	await frames(3)
	var guards := king._summons.size()
	king.take_hit({"damage": 9999.0, "dir": Vector3.FORWARD, "breaks_guard": true})
	await real_wait(0.3)
	var alive := 0
	for e in king._summons:
		if is_instance_valid(e) and e.is_alive():
			alive += 1
	check(guards == 2 and alive == 0, "king_summons_then_guard_falls", "summoned=%d still_alive=%d" % [guards, alive])
