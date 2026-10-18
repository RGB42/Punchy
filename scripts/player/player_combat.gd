class_name PlayerCombat
extends Node
## Freeflow combat for the player figure (Arkham's rhythm, God of War's weight).
##
## An attack picks the enemy the stick points at, lunges to it during the windup
## so the blow lands exactly as the pose snaps, then freezes the world for a few
## frames. Pressing attack again before the recovery ends chains the combo;
## counter cuts into anything when an enemy shows its warning sign; dodge cancels
## recovery. While an attack runs the player is in State.ACTION and this node
## drives its movement through tick_action().

signal combo_changed(count: int)
signal health_changed(value: float, max_value: float)
signal energy_changed(value: float, max_value: float)
signal died

const MAX_HEALTH := 100.0
const MAX_ENERGY := 100.0
const LUNGE_RANGE := 9.0
const LUNGE_SPEED := 30.0
const CLOSE_RANGE := 3.5
const COMBO_TIMEOUT := 2.2
const COUNTER_RANGE := 7.5
const ENERGY_PER_HIT := 8.0
const ROLL_IFRAMES := 0.28
const HURT_TIME := 0.42
const MERCY_TIME := 0.6
const SLAM_SPEED := 48.0
const FINISHER_COMBO := 8  # hits per special takedown
const JUGGLE_WINDOW := 0.9  # s after a launcher in which jump follows the enemy up

var p: Player
var health := MAX_HEALTH
var energy := 0.0
var combo := 0
var finisher_at := FINISHER_COMBO  # combo count that unlocks the next takedown
var _juggle: Enemy
var _juggle_t := 0.0
var _air_start := false
var _aim_target: Enemy  # who a ranged power was aimed at (it does not lunge)

var move: Dictionary = {}
var target: Enemy
var _t := 0.0
var _windup := 0.0
var _hit_done := false
var _buffered := ""
var _chain := 0
var _chain_open := false  # pressing attack now continues the combo
var _combo_t := 0.0
var _invuln := 0.0
var _from := Vector3.ZERO
var _mode := ""  # "", "strike", "slam", "hurt", "whiff"


func _init(player: Player) -> void:
	p = player


func tick_global(delta: float) -> void:
	_combo_t += delta
	_invuln -= delta
	if combo > 0 and _combo_t > COMBO_TIMEOUT:
		_set_combo(0)
	if _chain_open and p.state != Player.State.ACTION:
		_chain_open = false
	_juggle_t -= delta
	if _juggle_t > 0.0 and p.jump_pressed and is_instance_valid(_juggle) and _juggle.is_alive() \
			and _juggle.state == Enemy.State.AIRBORNE:
		_follow_up(_juggle)


func finisher_ready() -> bool:
	return combo >= finisher_at


## Leap after a launched enemy so the air combo can start: arrive level with
## it at the top of the jump.
func _follow_up(e: Enemy) -> void:
	_juggle_t = 0.0
	p.jump_pressed = false
	p._jump_buffer = 0.0
	var rise := maxf(e.global_position.y + 0.6 - p.global_position.y, 2.5)
	var vy := sqrt(2.0 * Player.GRAVITY_UP * rise)
	var flat := _flat(e.global_position - p.global_position)
	var t_apex := vy / Player.GRAVITY_UP
	var h := flat.normalized() * minf((flat.length() - 1.2) / t_apex, 18.0) if flat.length() > 1.2 else Vector3.ZERO
	p.velocity = Vector3(h.x, vy, h.z)
	p.facing = flat.normalized() if flat.length() > 0.1 else p.facing
	p._jumping = false
	p.set_state(Player.State.AIR)
	Game.sfx("double_jump", -4.0)


## Entry point from the movement states. kind: attack, heavy, counter, power.
func try_start(kind: String) -> bool:
	var air := not p.is_on_floor()
	match kind:
		"counter":
			var e := counterable_enemy()
			if e:
				_start(Moves.COUNTER, e)
				return true
			var cork := counterable_projectile()
			if cork:
				cork.deflect()
				_start(Moves.COUNTER, null)
				return true
			return false
		"attack":
			var t := pick_target(LUNGE_RANGE)
			if air and t == null:
				return false
			if t and not air and t.state == Enemy.State.DOWN and not t.boss:
				_start(Moves.GROUND_FINISH, t)
				return true
			_chain = (_chain + 1) % Moves.COMBO.size() if _chain_open else 0
			_start(Moves.COMBO[_chain], t)
			return true
		"heavy":
			if not air and finisher_ready():
				var ft := pick_target(LUNGE_RANGE)
				if ft:
					finisher_at = combo + FINISHER_COMBO
					_start(Moves.TAKEDOWN, ft)
					return true
			if air:
				_start_slam()
			else:
				_start(Moves.HEAVY, pick_target(LUNGE_RANGE * 0.6))
			return true
		"power":
			var pm := power_move()
			if air or energy < pm["energy"]:
				return false
			_set_energy(energy - pm["energy"])
			_start(pm, pick_target(pm["reach"]))  # aims at it; ranged powers never lunge
			return true
	return false


## The ground power of the current hero.
func power_move() -> Dictionary:
	match p.element:
		"frost": return Moves.FROST_BLAST
		"volt": return Moves.CHAIN
		"stone": return Moves.QUAKE
		"venom": return Moves.POISON
		"gale": return Moves.TORNADO
		"shade": return Moves.SHADOW
	return Moves.FLAME


func pick_target(reach: float) -> Enemy:
	var dir := p.wish_dir()
	if dir.length() < 0.2:
		dir = Vector3.ZERO
	var best: Enemy = null
	var best_score := -INF
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if not e.is_alive():
			continue
		var to := e.global_position - p.global_position
		if absf(to.y) > 3.0:
			continue
		to.y = 0
		var d := to.length()
		if d > reach:
			continue
		var score := -d / reach
		if dir != Vector3.ZERO:
			var align := dir.normalized().dot(to / maxf(d, 0.01))
			if align < 0.35 and d > 1.8:
				continue  # outside the stick cone; only point-blank enemies qualify
			score += align * 2.0
		if score > best_score:
			best_score = score
			best = e
	return best


func counterable_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := COUNTER_RANGE
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		var d := e.global_position.distance_to(p.global_position)
		if e.is_counterable() and d < best_d:
			best_d = d
			best = e
	return best


func counterable_projectile() -> Node3D:
	for n in get_tree().get_nodes_in_group("projectile"):
		if n.is_counterable(p):
			return n
	return null


func is_invulnerable() -> bool:
	if _invuln > 0.0:
		return true
	if p.state == Player.State.DASH and p._dash_ground and p._state_t < ROLL_IFRAMES:
		return true
	return p.state == Player.State.ACTION and move == Moves.COUNTER


func _start(m: Dictionary, t: Enemy) -> void:
	move = m
	target = t
	_mode = "strike"
	_t = 0.0
	_hit_done = false
	_buffered = ""
	_from = p.global_position
	_air_start = not p.is_on_floor()
	_windup = m["windup"]
	_aim_target = t
	if t and (m.has("cone") or m.has("chain") or m.has("around") or m.has("cloud") or m.has("shadow")):
		target = null  # ranged: aim, don't lunge
		p.facing = _flat(t.global_position - p.global_position).normalized()
	elif t:
		var gap := _flat(t.global_position - p.global_position).length() - _stand_off()
		_windup = maxf(_windup, gap / LUNGE_SPEED)
		p.facing = _flat(t.global_position - p.global_position).normalized()
	elif p.wish_dir().length() > 0.2:
		p.facing = p.wish_dir().normalized()
	p.set_state(Player.State.ACTION)
	var wind_t := maxf(_windup - 0.045, 0.02)
	p.anim.play([
		{"pose": m["wind"], "time": wind_t, "ease": 0.6},
		{"pose": m["hit"], "time": 0.045, "ease": 0.3},
		{"pose": m["hit"], "time": m["active"]},
	], m["recover"] * 0.9)
	_chain_open = false
	if m == Moves.COUNTER:
		Game.sfx("counter")
	elif not m.has("cone"):
		Game.sfx("swing_heavy" if m.get("finisher", false) else "swing", -5.0)


func _start_slam() -> void:
	move = Moves.SLAM
	target = null
	_mode = "slam"
	_t = 0.0
	_hit_done = false
	_buffered = ""
	p.set_state(Player.State.ACTION)
	p.velocity = Vector3(0, 7.0, 0)
	p.anim.play([{"pose": Poses.TUCK, "time": 0.08, "ease": 0.4}, {"pose": Poses.TUCK, "time": 5.0}], 0.1)
	Game.sfx("swing_heavy", -3.0)


func _stand_off() -> float:
	return clampf(float(move.get("reach", 1.7)) * 0.65, 1.0, 1.4)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)


func tick_action(delta: float) -> void:
	_t += delta
	match _mode:
		"slam": _tick_slam(delta)
		"hurt": _tick_hurt(delta)
		_: _tick_strike(delta)


func _tick_strike(delta: float) -> void:
	var lunging := _t < _windup and is_instance_valid(target) and target.is_alive()
	if lunging:
		var to := _flat(target.global_position - p.global_position)
		var stand := target.global_position - to.normalized() * _stand_off()
		var k := clampf(_t / _windup, 0.0, 1.0)
		# in the air the lunge also closes height, so a juggled enemy can be chased
		var y := lerpf(_from.y, target.global_position.y - 0.2, ease(k, 0.5)) if _air_start else _from.y
		var want := _from.lerp(Vector3(stand.x, _from.y, stand.z), ease(k, 0.5))
		want.y = y
		var v := (want - p.global_position) / delta
		p.velocity = Vector3(v.x, v.y if _air_start else p.velocity.y, v.z)
		p.facing = to.normalized() if to.length() > 0.1 else p.facing
	else:
		var h := _flat(p.velocity).move_toward(Vector3.ZERO, 60.0 * delta)
		p.velocity = Vector3(h.x, p.velocity.y, h.z)
	if p.is_on_floor():
		p.velocity.y = -2.0
	elif lunging and _air_start:
		pass
	elif lunging or _t < _windup + float(move["active"]):
		p.velocity.y = 0.0  # air combo: hang in the air while hitting
	else:
		p.velocity.y -= Player.GRAVITY_DOWN * delta * (0.3 if _air_start else 1.0)
	p.move_and_slide()

	if not _hit_done and _t >= _windup:
		_hit_done = true
		_impact()

	_read_buffer()
	var active_end := _windup + float(move["active"])
	if _t >= _windup:
		_chain_open = true
	if _buffered == "counter" and (counterable_enemy() or counterable_projectile()):
		try_start("counter")
		return
	if _t >= active_end:
		if p.dodge_pressed:
			p._start_dash(true)
			return
		if _buffered != "" and try_start(_buffered):
			return
	if _t >= active_end + float(move["recover"]):
		_end()


func _read_buffer() -> void:
	if p.counter_pressed:
		_buffered = "counter"
	elif p.attack_pressed:
		_buffered = "attack"
	elif p.heavy_pressed:
		_buffered = "heavy"
	elif p.power_pressed:
		_buffered = "power"


func _tick_slam(delta: float) -> void:
	if not _hit_done:
		if _t < 0.14:
			p.velocity.y -= Player.GRAVITY_UP * delta
		else:
			p.velocity = Vector3(0, -SLAM_SPEED, 0)
		p.move_and_slide()
		if p.is_on_floor() and _t > 0.05:
			_hit_done = true
			_t = 0.0
			p.anim.play([{"pose": Moves.SLAM_HIT, "time": 0.03, "ease": 0.3}, {"pose": Moves.SLAM_HIT, "time": move["active"]}], move["recover"])
			_impact()
		elif _t > 3.0:
			_end()
		return
	p.velocity = Vector3(0, -2.0, 0)
	p.move_and_slide()
	if _t >= float(move["active"]) + float(move["recover"]):
		_end()


func _tick_hurt(delta: float) -> void:
	var h := _flat(p.velocity).move_toward(Vector3.ZERO, 30.0 * delta)
	p.velocity = Vector3(h.x, p.velocity.y - Player.GRAVITY_DOWN * delta if not p.is_on_floor() else -2.0, h.z)
	p.move_and_slide()
	if _t >= HURT_TIME:
		_end()


func _end() -> void:
	_mode = ""
	move = {}
	p.end_action()


func _impact() -> void:
	var origin := p.global_position + p.facing * 1.1 + Vector3.UP * 1.1
	var victims: Array[Enemy] = []
	var cone: float = move.get("cone", 0.0)
	var radius: float = move.get("radius", 0.0)
	var reach: float = move.get("reach", 1.7)
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if not e.is_alive():
			continue
		var to := e.global_position - p.global_position
		if absf(to.y) > 2.5:
			continue
		var flat := _flat(to)
		if cone > 0.0:
			if flat.length() <= reach and rad_to_deg(p.facing.angle_to(flat)) <= cone:
				victims.append(e)
		elif radius > 0.0 and _flat(e.global_position - (p.global_position if move.get("around", false) else origin)).length() <= radius:
			victims.append(e)
	if is_instance_valid(target) and target.is_alive() and not victims.has(target):
		if _flat(target.global_position - p.global_position).length() <= reach + 0.6:
			victims.append(target)
	if target == null and victims.is_empty() and cone <= 0.0 and radius <= 0.0:
		var near := pick_target(reach + 0.4)
		if near and p.facing.dot(_flat(near.global_position - p.global_position).normalized()) > 0.3:
			victims.append(near)

	if cone > 0.0:
		Game.sfx("freeze" if p.element == "frost" else "flame")
		var ice := p.element == "frost"
		Fx.fire(p.global_position + Vector3.UP * 1.2 + p.facing * 0.6, p.facing, cone * 0.6, reach * 3.0, 90 if ice else 140, 0.6 if ice else 1.1, 0.4 if ice else 0.5, p.element)
		if ice:
			Fx.shards(p.global_position + Vector3.UP * 1.2 + p.facing * 1.5, p.facing, Color(0.7, 0.9, 1.0), 16)
		Fx.flash(origin, p.hero["color"], 10.0, 10.0, 0.3)
	if move.has("chain"):
		victims = _chain_victims(int(move["chain"]), float(move["hop"]), reach)
		var from := p.global_position + Vector3.UP * 1.3 + p.facing * 0.5
		for e in victims:
			var to := e.global_position + Vector3.UP * 1.1 * e.size
			Fx.lightning(from, to)
			from = to
		Game.sfx("zap")
	if move.has("cloud"):
		var at := _aim_target.global_position if is_instance_valid(_aim_target) else p.global_position + p.facing * 4.0
		at.y = p.global_position.y
		victims = _enemies_near(at, move["cloud"])
		Fx.cloud(at + Vector3.UP * 0.8, "venom", move["cloud_secs"], move["cloud"])
		Game.sfx("poison")
		_poison_zone(at, move["cloud"], move["cloud_secs"])
	if move.get("name", "") == "quake":
		Game.sfx("quake")
		Fx.ring(p.global_position, radius, Color(1.6, 1.0, 0.5, 1.0), 0.45)
		Fx.fire(p.global_position + Vector3.UP * 0.3, Vector3.UP, 85.0, 9.0, 140, 1.3, 0.8, "stone")
		Fx.shards(p.global_position + Vector3.UP * 0.4, Vector3.UP, Color(0.45, 0.38, 0.3), 40)
		Fx.cloud(p.global_position + Vector3.UP * 0.5, "stone", 0.5, 5.0)
		Fx.ring(p.global_position, radius * 0.6, Color(2.0, 1.2, 0.5, 1.0), 0.3)
	if move.get("name", "") == "tornado":
		Game.sfx("wind")
		Fx.cloud(p.global_position, "gale", 1.2, 3.0, 18.0)
		Fx.ring(p.global_position, radius, Color(1.4, 2.2, 1.9, 0.8), 0.4)
	if move.has("shadow"):
		_shadow_chain(_shadow_victims(int(move["shadow"]), reach))
		return
	if _mode == "slam":
		Game.sfx("slam")
		Fx.ring(p.global_position, radius)
		Fx.fire(p.global_position + Vector3.UP * 0.3, Vector3.UP, 85.0, 12.0, 110, 1.0, 0.45, p.element)
		Fx.flash(p.global_position + Vector3.UP, p.hero["color"], 9.0, 10.0, 0.25)
		Game.shake(move["shake"])
		Game.kick(move["kick"])

	var takedown: bool = move.get("takedown", false)
	if takedown and is_instance_valid(target):
		# special takedown: hard cut to a side view, the world crawls, fire everywhere
		if p.camera and p.camera.has_method("cinematic"):
			p.camera.cinematic(target.global_position + Vector3.UP * 1.1, p.facing, 0.9)
		Game.slowmo(0.22, 0.75)
		Game.sfx({"frost": "freeze", "volt": "zap"}.get(p.element, "flame"))
		Fx.fire(target.global_position + Vector3.UP * 1.0, Vector3.UP, 70.0, 10.0, 120, 1.0, 0.5, p.element)
		if p.element == "volt":
			for i in 4:
				Fx.lightning(target.global_position + Vector3.UP * 8.0 + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)), target.global_position + Vector3.UP)
		Fx.ring(target.global_position, 4.0)
		Fx.flash(target.global_position + Vector3.UP, p.hero["color"], 14.0, 12.0, 0.4)
	if move == Moves.GROUND_FINISH:
		Fx.ring(p.global_position + p.facing, 2.4, Color(2.5, 1.5, 0.6, 1.0), 0.25)

	var air_spike: bool = not p.is_on_floor() and move.get("finisher", false) and not takedown
	var landed := 0
	var blocked := false
	var killed := false
	for e in victims:
		var dir := _flat(e.global_position - p.global_position)
		dir = dir.normalized() if dir.length() > 0.05 else p.facing
		var dmg: float = move["damage"]
		if takedown and e.boss:
			dmg = Moves.BOSS_TAKEDOWN_DAMAGE
		var ok := e.take_hit({
			"damage": dmg, "knock": move["knock"], "launch": move.get("launch", 0.0),
			"dir": dir, "breaks_guard": move.get("breaks_guard", false), "spike": air_spike,
			"freeze": move.get("freeze", 0.0), "stun": move.get("stun", 0.0), "poison": move.get("poison", 0.0),
		})
		var at := e.global_position + Vector3.UP * 1.2
		if ok:
			landed += 1
			killed = killed or not e.is_alive()
			Fx.sparks(at - dir * 0.3, dir + Vector3.UP * 0.25)
			if move.get("finisher", false):
				Fx.ring(e.global_position, 2.5)
			if float(move.get("launch", 0.0)) >= 10.0 and e.is_alive() and not e.boss:
				_juggle = e  # jump now to follow it up
				_juggle_t = JUGGLE_WINDOW
		else:
			blocked = true

	if landed > 0:
		Game.sfx("hit_heavy" if float(move["hitstop"]) >= 0.1 else "hit")
		Game.hitstop(move["hitstop"])
		Game.shake(move["shake"])
		Game.kick(move["kick"])
		Fx.flash(origin)
		_set_combo(combo + landed)
		_set_energy(energy + ENERGY_PER_HIT * landed)
		if killed and _no_enemy_near():
			Game.slowmo(0.2, 0.9)
			Game.kick(10.0)
	elif blocked:
		Game.sfx("block")
		Game.hitstop(0.035)
		Game.shake(0.1)


## Volt's lightning: the enemy in front first, then hop to the nearest unhit one.
func _chain_victims(count: int, hop: float, reach: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var first := target if is_instance_valid(target) and target.is_alive() else pick_target(reach)
	if first == null:
		return out
	out.append(first)
	while out.size() < count:
		var last: Enemy = out.back()
		var best: Enemy = null
		var best_d := hop
		for n in get_tree().get_nodes_in_group("enemy"):
			var e := n as Enemy
			if not e.is_alive() or out.has(e):
				continue
			var d := e.global_position.distance_to(last.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		out.append(best)
	return out


func _enemies_near(at: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n in get_tree().get_nodes_in_group("enemy"):
		var e := n as Enemy
		if e.is_alive() and _flat(e.global_position - at).length() <= radius and absf(e.global_position.y - at.y) < 3.0:
			out.append(e)
	return out


## Keeps poisoning whoever stands in the cloud until it drifts away.
func _poison_zone(at: Vector3, radius: float, secs: float) -> void:
	var tree := get_tree()
	for i in int(secs / 0.5):
		await tree.create_timer(0.5, false).timeout
		for e in _enemies_near(at, radius):
			e.poison(1.0)


func _shadow_victims(count: int, reach: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	var first := _aim_target if is_instance_valid(_aim_target) and _aim_target.is_alive() else pick_target(reach)
	if first:
		out.append(first)
	var near := _enemies_near(p.global_position, reach)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	for e in near:
		if out.size() >= count:
			break
		if not out.has(e):
			out.append(e)
	return out


## Shade: vanish, reappear behind each victim in turn and strike.
func _shadow_chain(victims: Array[Enemy]) -> void:
	var tree := get_tree()
	Game.sfx("shadow")
	for e in victims:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		Fx.cloud(p.global_position + Vector3.UP, "shade", 0.15, 0.8)
		var back := -e._forward()
		var spot := e.global_position + back * 1.3
		var q := PhysicsRayQueryParameters3D.create(e.global_position + Vector3.UP, spot + Vector3.UP, 1)
		if not p.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			spot = e.global_position - back * 1.3  # wall behind it: come from the front
		p.global_position = Vector3(spot.x, e.global_position.y + 0.05, spot.z)
		var dir := _flat(e.global_position - p.global_position).normalized()
		p.facing = dir
		if e.take_hit({"damage": move.get("damage", 30.0), "knock": move.get("knock", 8.0), "launch": move.get("launch", 3.0),
				"dir": dir, "breaks_guard": true}):
			Fx.sparks(e.global_position + Vector3.UP * 1.2, dir, Color(2.2, 0.9, 3.0), 22, 12.0)
			Game.sfx("hit_heavy")
			Game.hitstop(0.06)
			Game.shake(0.3)
			_set_combo(combo + 1)
			_set_energy(energy + ENERGY_PER_HIT)
		await tree.create_timer(0.13, true, false, true).timeout


func _no_enemy_near() -> bool:
	for n in get_tree().get_nodes_in_group("enemy"):
		if (n as Enemy).is_alive() and (n as Enemy).global_position.distance_to(p.global_position) < 40.0:
			return false
	return true


## Called by enemies. Returns true if it hurt.
func take_hit(damage: float, from: Vector3) -> bool:
	if is_invulnerable() or health <= 0.0:
		return false
	health = maxf(0.0, health - damage)
	health_changed.emit(health, MAX_HEALTH)
	_set_combo(0)
	_invuln = MERCY_TIME
	var dir := _flat(p.global_position - from).normalized()
	p.facing = -dir if dir.length() > 0.1 else p.facing
	p.velocity = dir * 9.0 + Vector3.UP * 3.0
	_mode = "hurt"
	_t = 0.0
	move = {}
	p.set_state(Player.State.ACTION)
	p.anim.play([{"pose": Moves.HURT, "time": 0.04, "ease": 0.4}, {"pose": Moves.HURT, "time": HURT_TIME - 0.1}], 0.2)
	Game.sfx("hurt")
	Game.hitstop(0.07)
	Game.shake(0.4)
	Fx.sparks(p.global_position + Vector3.UP * 1.2, dir, Color(3.0, 0.5, 0.3), 20, 10.0)
	if health <= 0.0:
		died.emit()
	return true


## Damage over time (hot plates): no flinch, no mercy window.
func burn(amount: float) -> void:
	if health <= 0.0:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if randf() < 0.1:
		Fx.fire(p.global_position + Vector3.UP * 0.3, Vector3.UP, 30.0, 4.0, 6, 0.5, 0.4)
	if health <= 0.0:
		died.emit()


func heal_full() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)


func _set_combo(v: int) -> void:
	combo = v
	if v == 0:
		finisher_at = FINISHER_COMBO
	_combo_t = 0.0
	combo_changed.emit(combo)


func _set_energy(v: float) -> void:
	energy = clampf(v, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)
