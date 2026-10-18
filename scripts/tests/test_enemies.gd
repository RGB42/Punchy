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
