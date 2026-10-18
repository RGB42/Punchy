class_name Dragon
extends Enemy
## The kitchen boss: a toy dragon on its own quadruped rig (tools/blender/build_dragon.py).
##
## bite    yellow sign: counter it
## tail    red: a full spin with the tail, jump over it
## breath  red: a sweeping cone of fire, get behind or out of it
## dive    red, second half of the fight: takes off, marks a spot, crashes down
## At half health it calls two dinos. Light hits only chip (boss armour).

const BREATH_TIME := 1.6
const BREATH_REACH := 9.0
const BREATH_ANGLE := 28.0
const BREATH_TICK := 0.3
const BREATH_DAMAGE := 8.0
const TAIL_REACH := 5.5
const BITE_REACH := 4.4
const DIVE_RADIUS := 6.0

const IDLE := {
	"root": Vector3.ZERO, "neck": Vector3(0, 0, 0), "head": Vector3(0, 0, 0), "jaw": Vector3(0, 0, 0),
	"tail1": Vector3(-4, 0, 0), "tail2": Vector3(-6, 0, 0), "tail3": Vector3(-8, 0, 0),
	"leg_fl": Vector3.ZERO, "leg_fr": Vector3.ZERO, "leg_bl": Vector3.ZERO, "leg_br": Vector3.ZERO,
	"wing_l": Vector3(0, 30, -50), "wing_r": Vector3(0, -30, 50),
}
const BREATH_WIND := {"neck": Vector3(28, 0, 0), "head": Vector3(22, 0, 0), "jaw": Vector3(-10, 0, 0), "root": Vector3(0, 0.2, 0)}
const BREATH := {"neck": Vector3(-14, 0, 0), "head": Vector3(-12, 0, 0), "jaw": Vector3(-38, 0, 0), "root": Vector3(0, -0.1, 0)}
const BITE_WIND := {"neck": Vector3(32, 0, 0), "head": Vector3(25, 0, 0), "jaw": Vector3(-42, 0, 0)}
const BITE_HIT := {"neck": Vector3(-32, 0, 0), "head": Vector3(-22, 0, 0), "jaw": Vector3(0, 0, 0), "root": Vector3(0, -0.3, 0)}
const TAIL_WIND := {"tail1": Vector3(0, 45, 0), "tail2": Vector3(0, 35, 0), "tail3": Vector3(0, 30, 0), "neck": Vector3(0, -25, 0)}
const SPREAD := {"wing_l": Vector3(0, 0, 0), "wing_r": Vector3(0, 0, 0), "leg_fl": Vector3(-30, 0, 0),
	"leg_fr": Vector3(-30, 0, 0), "leg_bl": Vector3(35, 0, 0), "leg_br": Vector3(35, 0, 0)}

var _tick := 0.0
var _dive_target := Vector3.ZERO
var _marker: MeshInstance3D
var _gait := 0.0


func _ready() -> void:
	kind = "dragon"
	summon_kind = "dino"
	super._ready()


func _guard_pose() -> Dictionary:
	return IDLE


func is_counterable() -> bool:
	return _attack == "bite" and (state == State.WINDUP or (state == State.ATTACK and _t < 0.07))


func _pick_boss_attack(dist: float) -> void:
	if not _summoned and health < max_health * 0.5:
		_summoned = true
		_summon()
	var late := health < max_health * 0.5
	var r := randf()
	if late and r < 0.3:
		_attack = "dive"
	elif dist < TAIL_REACH and r < 0.55:
		_attack = "tail"
	elif dist < BITE_REACH:
		_attack = "bite"
	elif r < 0.65:
		_attack = "breath"
	else:
		_attack = "bite"
		_enter(State.APPROACH)  # walk up, then bite
		return
	_start_windup()


func _start_windup() -> void:
	_enter(State.WINDUP)
	var pose: Dictionary = {"bite": BITE_WIND, "breath": BREATH_WIND, "tail": TAIL_WIND, "dive": SPREAD}.get(_attack, BITE_WIND)
	anim.play([{"pose": pose, "time": windup_time * 0.6, "ease": 0.5}, {"pose": pose, "time": 5.0}], 0.1)
	if _attack == "breath":
		Game.sfx("rocket", -4.0)


func _start_strike_anim() -> void:
	_tick = 0.0
	match _attack:
		"breath":
			anim.play([{"pose": BREATH, "time": 0.12, "ease": 0.4}, {"pose": BREATH, "time": BREATH_TIME}], 0.3)
			Game.sfx("flame", 2.0)
		"bite":
			anim.play([{"pose": BITE_HIT, "time": 0.07, "ease": 0.3}, {"pose": BITE_HIT, "time": 0.3}], 0.25)
		"dive":
			anim.play([{"pose": SPREAD, "time": 0.1}, {"pose": SPREAD, "time": 5.0}], 0.3)
			Game.sfx("wind")
		_:
			anim.play([{"pose": IDLE, "time": 0.05}, {"pose": IDLE, "time": 0.5}], 0.2)


func _tick_attack(delta: float, to_p: Vector3, dist: float) -> void:
	match _attack:
		"bite":
			var lunge := _forward() * (10.0 if _t < 0.12 else 0.0)
			velocity.x = lunge.x
			velocity.z = lunge.z
			if not _hit_done and _t >= 0.08:
				_hit_done = true
				Game.sfx("hit_heavy", -2.0)
				if player and dist <= BITE_REACH and _forward().dot(to_p.normalized()) > 0.4:
					player.take_hit(attack_damage, global_position)
			if _t >= 0.35:
				_enter(State.RECOVER)
		"tail":
			velocity.x = 0.0
			velocity.z = 0.0
			if not _hit_done and _t >= 0.2:
				_hit_done = true
				Game.sfx("swing_heavy")
				Game.shake(0.3)
				if player and dist <= TAIL_REACH and player.global_position.y - global_position.y < 0.9:
					player.take_hit(attack_damage, global_position)
			if _t >= 0.55:
				_enter(State.RECOVER)
		"breath":
			_tick_breath(delta, to_p, dist)
		"dive":
			_tick_dive(delta)


func _tick_breath(delta: float, to_p: Vector3, dist: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if to_p.length() > 0.1:  # it sweeps after you, but slowly: run round it
		_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-1.1 * delta))
	_tick -= delta
	var mouth: Vector3 = (anim.joints["jaw"] as Node3D).global_position + _forward() * 1.2 * size
	if fmod(_t, 0.06) < delta:
		Fx.fire(mouth, _forward() + Vector3.DOWN * 0.25, 14.0, 22.0, 18, 0.9, 0.45)
	if _tick <= 0.0:
		_tick = BREATH_TICK
		if player and dist <= BREATH_REACH and rad_to_deg(_forward().angle_to(to_p)) <= BREATH_ANGLE:
			player.take_hit(BREATH_DAMAGE * (0.5 if player.element == "blaze" else 1.0), global_position)
	if _t >= BREATH_TIME:
		_enter(State.RECOVER)


func _tick_dive(delta: float) -> void:
	if _t < 0.8:  # take off
		velocity = Vector3(0, 12.0, 0)
		_hit_done = false
		return
	if _t < 1.6:  # hover over the mark
		if _marker == null and player:
			_dive_target = Vector3(player.global_position.x, home.y, player.global_position.z)
			_marker = _make_marker(_dive_target)
		var flat := Vector3(_dive_target.x - global_position.x, 0, _dive_target.z - global_position.z)
		velocity = flat * 3.0  # drift over the mark, no gravity while hovering
		return
	if not _hit_done:  # dive
		velocity = Vector3(0, -40.0, 0)
		if is_on_floor() or global_position.y <= home.y + 0.1:
			_hit_done = true
			_t = 1.6
			Game.sfx("slam", 3.0)
			Game.shake(0.9)
			Fx.ring(global_position, DIVE_RADIUS, Color(3.0, 1.2, 0.6, 1.0), 0.45)
			Fx.fire(global_position + Vector3.UP * 0.4, Vector3.UP, 80.0, 10.0, 120, 1.2, 0.6)
			if is_instance_valid(_marker):
				_marker.queue_free()
			if player and player.global_position.distance_to(global_position) < DIVE_RADIUS \
					and player.global_position.y - global_position.y < 0.9:
				player.take_hit(attack_damage * 1.3, global_position)
		elif _t > 3.5:
			_hit_done = true
		return
	velocity = Vector3.ZERO
	if _t >= 2.3:
		_enter(State.RECOVER)


## A pulsing red disc on the table where the dragon is about to land.
func _make_marker(at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = DIVE_RADIUS
	disc.bottom_radius = DIVE_RADIUS
	disc.height = 0.05
	m.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.15, 0.05, 0.35)
	m.material_override = mat
	m.top_level = true
	add_child(m)
	m.global_position = at + Vector3.UP * 0.06
	var tw := m.create_tween().set_loops()
	tw.tween_property(mat, "albedo_color:a", 0.6, 0.15)
	tw.tween_property(mat, "albedo_color:a", 0.25, 0.15)
	return m


func _die(impulse: Vector3) -> void:
	if is_instance_valid(_marker):
		_marker.queue_free()
	super._die(impulse)


func _update_visual(delta: float, to_p: Vector3) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_set_flash(false)
	var tracking := state in [State.STRAFE, State.APPROACH, State.WINDUP] and to_p.length() > 0.1
	if tracking and _attack != "breath":
		_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-4.0 * delta))
	var spin := 0.0
	if state == State.ATTACK and _attack == "tail":
		spin = TAU * clampf((_t - 0.05) / 0.45, 0.0, 1.0)
	visual.rotation = Vector3(0, _yaw + spin, 0)

	var flying := state == State.ATTACK and _attack == "dive" and _t < 1.75
	var spd := Vector3(velocity.x, 0, velocity.z).length()
	_gait += spd * delta * TAU / 4.0
	var s := sin(_gait)
	var a := clampf(spd / 5.0, 0.0, 1.0) * 28.0
	var pose := IDLE.duplicate()
	pose["leg_fl"] = Vector3(s * a, 0, 0)
	pose["leg_br"] = Vector3(s * a, 0, 0)
	pose["leg_fr"] = Vector3(-s * a, 0, 0)
	pose["leg_bl"] = Vector3(-s * a, 0, 0)
	var sway := sin(Time.get_ticks_msec() * 0.002)
	pose["tail1"] = IDLE["tail1"] + Vector3(0, sway * 10.0, 0)
	pose["tail2"] = IDLE["tail2"] + Vector3(0, sway * 14.0, 0)
	pose["tail3"] = IDLE["tail3"] + Vector3(0, sway * 18.0, 0)
	pose["root"] = Vector3(0, absf(s) * 0.08 * a / 28.0, 0)
	if flying:
		var flap := sin(Time.get_ticks_msec() * 0.025) * 40.0
		pose["wing_l"] = Vector3(0, 0, -flap)
		pose["wing_r"] = Vector3(0, 0, flap)
	anim.set_base(pose, 12.0)
