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

var p: Player
var health := MAX_HEALTH
var energy := 0.0
var combo := 0

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
			_chain = (_chain + 1) % Moves.COMBO.size() if _chain_open else 0
			_start(Moves.COMBO[_chain], t)
			return true
		"heavy":
			if air:
				_start_slam()
			else:
				_start(Moves.HEAVY, pick_target(LUNGE_RANGE * 0.6))
			return true
		"power":
			if air or energy < Moves.FLAME["energy"]:
				return false
			_set_energy(energy - Moves.FLAME["energy"])
			_start(Moves.FLAME, pick_target(CLOSE_RANGE))
			return true
	return false


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
	_windup = m["windup"]
	if t and m.has("cone"):
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
		var want := _from.lerp(Vector3(stand.x, _from.y, stand.z), ease(k, 0.5))
		var v := (want - p.global_position) / delta
		p.velocity = Vector3(v.x, p.velocity.y, v.z)
		p.facing = to.normalized() if to.length() > 0.1 else p.facing
	else:
		var h := _flat(p.velocity).move_toward(Vector3.ZERO, 60.0 * delta)
		p.velocity = Vector3(h.x, p.velocity.y, h.z)
	if p.is_on_floor():
		p.velocity.y = -2.0
	elif lunging or _t < _windup + float(move["active"]):
		p.velocity.y = 0.0  # air combo: hang in the air while hitting
	else:
		p.velocity.y -= Player.GRAVITY_DOWN * delta
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
		elif radius > 0.0 and _flat(e.global_position - origin).length() <= radius:
			victims.append(e)
	if is_instance_valid(target) and target.is_alive() and not victims.has(target):
		if _flat(target.global_position - p.global_position).length() <= reach + 0.6:
			victims.append(target)
	if target == null and victims.is_empty() and cone <= 0.0 and radius <= 0.0:
		var near := pick_target(reach + 0.4)
		if near and p.facing.dot(_flat(near.global_position - p.global_position).normalized()) > 0.3:
			victims.append(near)

	if cone > 0.0:
		Game.sfx("flame")
		Fx.fire(p.global_position + Vector3.UP * 1.2 + p.facing * 0.6, p.facing, cone * 0.6, reach * 3.0, 140, 1.1, 0.5)
		Fx.flash(origin, Color(1.0, 0.5, 0.15), 10.0, 10.0, 0.3)
	if _mode == "slam":
		Game.sfx("slam")
		Fx.ring(p.global_position, radius)
		Fx.fire(p.global_position + Vector3.UP * 0.3, Vector3.UP, 85.0, 12.0, 110, 1.0, 0.45)
		Fx.flash(p.global_position + Vector3.UP, Color(1.0, 0.5, 0.15), 9.0, 10.0, 0.25)
		Game.shake(move["shake"])
		Game.kick(move["kick"])

	var landed := 0
	var blocked := false
	var killed := false
	for e in victims:
		var dir := _flat(e.global_position - p.global_position)
		dir = dir.normalized() if dir.length() > 0.05 else p.facing
		var ok := e.take_hit({
			"damage": move["damage"], "knock": move["knock"], "launch": move.get("launch", 0.0),
			"dir": dir, "breaks_guard": move.get("breaks_guard", false),
		})
		var at := e.global_position + Vector3.UP * 1.2
		if ok:
			landed += 1
			killed = killed or not e.is_alive()
			Fx.sparks(at - dir * 0.3, dir + Vector3.UP * 0.25)
			if move.get("finisher", false):
				Fx.ring(e.global_position, 2.5)
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


func heal_full() -> void:
	health = MAX_HEALTH
	health_changed.emit(health, MAX_HEALTH)


func _set_combo(v: int) -> void:
	combo = v
	_combo_t = 0.0
	combo_changed.emit(combo)


func _set_energy(v: float) -> void:
	energy = clampf(v, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)
