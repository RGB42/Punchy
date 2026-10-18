class_name Enemy
extends CharacterBody3D
## A hostile toy. Arkham-style group behaviour: everyone circles the player, at
## most MAX_ATTACKERS step in at once, each attack is telegraphed by a sign above
## the head (yellow = counter it, red = get out of the way), and shields block
## light hits from the front.
##
## `kind` picks a row from KINDS: knight (sword), doll (fast slaps), soldier
## (keeps distance, aims a laser, fires corks that a counter knocks back) and
## king (the boss: super armour, sweep / shockwave slam / charge, calls help).

signal died(enemy: Enemy)

enum State { IDLE, STRAFE, APPROACH, WINDUP, ATTACK, RECOVER, STAGGER, AIRBORNE, DOWN, GETUP, DEAD, FROZEN }

const GRAVITY := 40.0
## Bosses are big enough to swallow the camera: they sit on a layer its spring arm avoids.
const BOSS_LAYER := 64
const MAX_ATTACKERS := 2
const WINDUP_TIME := 0.7  # knight default; kinds override
const ATTACK_TIME := 0.2
const RECOVER_TIME := 0.55
const ATTACK_RANGE := 2.0
const STRAFE_MIN := 4.0
const STRAFE_MAX := 6.5
const DOWN_TIME := 1.0
const GETUP_TIME := 0.45

const KINDS := {
	"knight": {"model": "res://assets/models/figures/knight.glb", "health": 40.0, "speed": 6.5, "damage": 12.0,
		"windup": 0.7, "color": Color(0.6, 0.62, 0.68)},
	"doll": {"model": "res://assets/models/figures/doll.glb", "health": 22.0, "speed": 9.5, "damage": 8.0,
		"windup": 0.42, "color": Color(0.95, 0.6, 0.75)},
	"soldier": {"model": "res://assets/models/figures/soldier.glb", "health": 28.0, "speed": 5.5, "damage": 10.0,
		"windup": 0.85, "color": Color(0.2, 0.3, 0.7), "ranged": true},
	"robot": {"model": "res://assets/models/figures/robot.glb", "health": 70.0, "speed": 4.5, "damage": 16.0,
		"windup": 0.8, "color": Color(0.72, 0.74, 0.78), "armored": true},
	"dino": {"model": "res://assets/models/figures/dino.glb", "health": 30.0, "speed": 10.5, "damage": 10.0,
		"windup": 0.45, "color": Color(0.25, 0.62, 0.2), "dino": true},
	"dragon": {"model": "res://assets/models/figures/dragon.glb", "health": 420.0, "speed": 5.5, "damage": 16.0,
		"windup": 0.9, "color": Color(0.48, 0.14, 0.58), "boss": true, "title": "DER SPIELZEUGDRACHE", "scale": 0.85, "capsule": [1.5, 4.2], "sign_y": 6.0,
		"parts": ["body", "neck", "head", "jaw", "tail1", "tail2", "tail3", "leg_fl", "leg_fr", "leg_bl", "leg_br", "wing_l", "wing_r"]},
	"king": {"model": "res://assets/models/figures/king.glb", "health": 320.0, "speed": 6.0, "damage": 20.0,
		"windup": 0.8, "color": Color(0.3, 0.3, 0.36), "boss": true, "title": "DER BLECHKÖNIG", "scale": 1.9},
}

const GUARD := {
	"root": Vector3(0, -0.08, 0), "chest": Vector3(-6, 0, 0), "head": Vector3(-4, 0, 0),
	"upper_arm_r": Vector3(35, 0, 22), "lower_arm_r": Vector3(55, 0, 0), "hand_r": Vector3(-25, 0, 0),
	"upper_arm_l": Vector3(55, 0, -8), "lower_arm_l": Vector3(75, 0, 0),
	"thigh_r": Vector3(18, 0, 8), "shin_r": Vector3(-30, 0, 0), "foot_r": Vector3(12, 0, 0),
	"thigh_l": Vector3(5, 0, -8), "shin_l": Vector3(-25, 0, 0), "foot_l": Vector3(20, 0, 0),
}
const SWING_WIND := {
	"root": Vector3(0, -0.04, 0), "chest": Vector3(14, -30, 0), "abdomen": Vector3(5, -10, 0), "head": Vector3(-8, 30, 0),
	"upper_arm_r": Vector3(170, 0, 30), "lower_arm_r": Vector3(70, 0, 0), "hand_r": Vector3(30, 0, 0),
	"upper_arm_l": Vector3(40, 0, -20), "lower_arm_l": Vector3(60, 0, 0),
	"thigh_r": Vector3(-10, 0, 8), "shin_r": Vector3(-20, 0, 0), "thigh_l": Vector3(25, 0, -8), "shin_l": Vector3(-35, 0, 0),
}
const SWING_HIT := {
	"root": Vector3(0, -0.22, 0), "chest": Vector3(-22, 35, 0), "abdomen": Vector3(-8, 12, 0), "head": Vector3(10, -35, 0),
	"upper_arm_r": Vector3(75, 40, 0), "lower_arm_r": Vector3(8, 0, 0), "hand_r": Vector3(-10, 0, 0),
	"upper_arm_l": Vector3(-15, 0, -30), "lower_arm_l": Vector3(40, 0, 0),
	"thigh_r": Vector3(-25, 0, 8), "shin_r": Vector3(-20, 0, 0), "thigh_l": Vector3(55, 0, -8), "shin_l": Vector3(-65, 0, 0),
}
const AIM := {
	"root": Vector3(0, -0.1, 0), "chest": Vector3(-4, 20, 0), "head": Vector3(-6, -20, 0),
	"upper_arm_r": Vector3(80, -15, 10), "lower_arm_r": Vector3(10, 0, 0), "hand_r": Vector3(0, 0, 0),
	"upper_arm_l": Vector3(75, 25, -10), "lower_arm_l": Vector3(40, 0, 0),
	"thigh_r": Vector3(-12, 0, 10), "shin_r": Vector3(-20, 0, 0), "thigh_l": Vector3(25, 0, -8), "shin_l": Vector3(-35, 0, 0),
}
const RECOIL := {
	"chest": Vector3(12, 20, 0), "head": Vector3(10, -20, 0),
	"upper_arm_r": Vector3(100, -15, 10), "lower_arm_r": Vector3(30, 0, 0),
}
const SLAM_WIND := {
	"root": Vector3(0, 0.1, 0), "chest": Vector3(25, 0, 0), "head": Vector3(-15, 0, 0),
	"upper_arm_r": Vector3(178, 0, 10), "lower_arm_r": Vector3(30, 0, 0),
	"upper_arm_l": Vector3(160, 0, -20), "lower_arm_l": Vector3(40, 0, 0),
	"thigh_r": Vector3(20, 0, 10), "shin_r": Vector3(-40, 0, 0), "thigh_l": Vector3(20, 0, -10), "shin_l": Vector3(-40, 0, 0),
}
const SLAM_HIT := {
	"root": Vector3(0, -0.35, 0), "chest": Vector3(-40, 0, 0), "head": Vector3(25, 0, 0),
	"upper_arm_r": Vector3(80, 0, 5), "lower_arm_r": Vector3(5, 0, 0),
	"upper_arm_l": Vector3(60, 0, -25), "lower_arm_l": Vector3(20, 0, 0),
	"thigh_r": Vector3(70, 0, 12), "shin_r": Vector3(-100, 0, 0), "thigh_l": Vector3(-15, 0, -12), "shin_l": Vector3(-40, 0, 0),
}
## Dino: body leaned forward to horizontal, head up to look ahead, tail on the hips.
const DINO_GUARD := {
	"root": Vector3(0, -0.06, 0), "abdomen": Vector3(-35, 0, 0), "chest": Vector3(-35, 0, 0), "head": Vector3(68, 0, 0),
	"upper_arm_r": Vector3(25, 0, 10), "lower_arm_r": Vector3(30, 0, 0), "upper_arm_l": Vector3(25, 0, -10), "lower_arm_l": Vector3(30, 0, 0),
	"thigh_r": Vector3(30, 0, 6), "shin_r": Vector3(-45, 0, 0), "foot_r": Vector3(15, 0, 0),
	"thigh_l": Vector3(30, 0, -6), "shin_l": Vector3(-45, 0, 0), "foot_l": Vector3(15, 0, 0),
}
const DINO_BITE_WIND := {
	"root": Vector3(0, 0.0, 0), "abdomen": Vector3(-20, 0, 0), "chest": Vector3(-12, 0, 0), "head": Vector3(100, 0, 0),
	"thigh_r": Vector3(10, 0, 6), "shin_r": Vector3(-30, 0, 0), "thigh_l": Vector3(20, 0, -6), "shin_l": Vector3(-35, 0, 0),
}
const DINO_BITE_HIT := {
	"root": Vector3(0, -0.18, 0), "abdomen": Vector3(-45, 0, 0), "chest": Vector3(-48, 0, 0), "head": Vector3(50, 0, 0),
	"thigh_r": Vector3(55, 0, 6), "shin_r": Vector3(-70, 0, 0), "thigh_l": Vector3(-10, 0, -6), "shin_l": Vector3(-30, 0, 0),
}

const LYING := {
	"root": Vector3.ZERO, "chest": Vector3(10, 0, 0), "head": Vector3(15, 20, 0),
	"upper_arm_r": Vector3(20, 0, 70), "lower_arm_r": Vector3(20, 0, 0),
	"upper_arm_l": Vector3(-10, 0, -60), "lower_arm_l": Vector3(30, 0, 0),
	"thigh_r": Vector3(25, 0, 12), "shin_r": Vector3(-35, 0, 0), "thigh_l": Vector3(5, 0, -10), "shin_l": Vector3(-10, 0, 0),
}

const PROJECTILE := preload("res://scripts/enemies/projectile.gd")

@export var kind := "knight"
@export var max_health := 0.0  # 0 = the kind's default
@export var shielded := false
@export var aggro_range := 24.0

var health := 0.0
var state := State.IDLE
var player: Player
var anim: FigureAnimator
var visual: Node3D
var home := Vector3.ZERO
var move_speed := 6.5
var attack_damage := 12.0
var windup_time := WINDUP_TIME
var plastic_color := Color(0.6, 0.62, 0.68)
var ranged := false
var boss := false
var size := 1.0

var _attack := "slash"  # slash, shoot, sweep, slam, charge
var _t := 0.0
var _yaw := 0.0
var _strafe_dir := 1.0
var _strafe_dist := 5.0
var _cooldown := 1.0
var _hit_done := false
var _walk_phase := 0.0
var _down_pitch := 0.0
var _flash_t := 0.0
var _meshes: Array[GeometryInstance3D] = []
var _flash_mat: StandardMaterial3D
var _sign: Label3D
var _shield: Node3D
var _figure: Node3D
var _laser: MeshInstance3D
var _airborne_spawn := false
var _summoned := false
var _summons: Array[Enemy] = []
var summon_kind := "knight"  # who the boss calls for help
var _wave_r := 0.0
var _float_t := 0.0
var _stagger_len := 0.0  # 0 = default
var _freeze_len := 0.0
var _poison_t := 0.0
var _ice_mat: StandardMaterial3D
var _splat_cd := 0.0
var _spiked := false
var armored := false  # robots: light hits clank off without a flinch
var dino := false
var _guard: Dictionary = GUARD
var _key: Node3D


func _ready() -> void:
	add_to_group("enemy")
	var k: Dictionary = KINDS.get(kind, KINDS["knight"])
	if max_health <= 0.0:
		max_health = k["health"]
	move_speed = k["speed"]
	attack_damage = k["damage"]
	windup_time = k["windup"]
	plastic_color = k["color"]
	ranged = k.get("ranged", false)
	boss = k.get("boss", false)
	armored = k.get("armored", false)
	dino = k.get("dino", false)
	_guard = _guard_pose()
	size = k.get("scale", 1.0)
	if boss:
		add_to_group("boss")
	collision_layer = 4 | (BOSS_LAYER if boss else 0)
	collision_mask = 1 | Arena.BARRIER_LAYER
	health = max_health
	home = global_position
	_airborne_spawn = true
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var dims: Array = k.get("capsule", [0.4 * size, 1.8 * size])
	cap.radius = dims[0]
	cap.height = dims[1]
	shape.shape = cap
	shape.position = Vector3(0, cap.height / 2.0, 0)
	add_child(shape)
	visual = Node3D.new()
	visual.position = Vector3(0, 0.95 * size, 0)
	visual.scale = Vector3.ONE * size
	add_child(visual)
	_figure = (load(k["model"]) as PackedScene).instantiate()
	_figure.position = Vector3(0, -0.95, 0)
	visual.add_child(_figure)
	anim = FigureAnimator.new(_figure, k.get("parts", FigureAnimator.PARTS))
	anim.snap_base(_guard)
	_key = _figure.find_child("key", true, false)
	_shield = _figure.find_child("shield", true, false)
	if _shield:
		_shield.visible = shielded or boss
	shielded = shielded or boss
	for n in _figure.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(n)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1, 1, 1, 0.85)
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sign = Label3D.new()
	_sign.text = "!"
	_sign.font_size = 160
	_sign.outline_size = 36
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sign.no_depth_test = true
	_sign.position = Vector3(0, k.get("sign_y", 2.45 * size), 0)
	_sign.visible = false
	add_child(_sign)
	if ranged:
		_laser = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = 1.0
		cyl.radial_segments = 6
		_laser.mesh = cyl
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(4.0, 0.3, 0.2)
		_laser.material_override = lm
		_laser.top_level = true
		_laser.visible = false
		add_child(_laser)
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_strafe_dist = randf_range(9.0, 12.0) if ranged else randf_range(STRAFE_MIN, STRAFE_MAX) * (1.4 if boss else 1.0)
	_cooldown = randf_range(0.6, 2.5)
	_yaw = rotation.y
	rotation = Vector3.ZERO


## The idle stance of this kind's skeleton; the dragon overrides it.
func _guard_pose() -> Dictionary:
	return DINO_GUARD if dino else GUARD


func activate() -> void:
	if state == State.IDLE:
		_enter(State.STRAFE)


func boss_kind() -> bool:
	return KINDS.get(kind, {}).get("boss", false)


func is_alive() -> bool:
	return state != State.DEAD


## Yellow-sign attacks can be countered; red ones (slam, charge) cannot.
func is_counterable() -> bool:
	if _attack in ["slam", "charge", "shoot", "tail"]:
		return false
	return state == State.WINDUP or (state == State.ATTACK and _t < 0.07)


func _enter(s: State) -> void:
	state = s
	_t = 0.0
	_sign.visible = s == State.WINDUP
	if _laser:
		_laser.visible = s == State.WINDUP and _attack == "shoot"
	if s == State.WINDUP:
		var red := not is_counterable()
		_sign.text = "!!" if red else "!"
		_sign.modulate = Color(1.0, 0.25, 0.15) if red else Color(1.0, 0.85, 0.2)
		_sign.outline_modulate = Color(0.3, 0.0, 0.0) if red else Color(0.9, 0.15, 0.05)
		Game.sfx("warn", -6.0 if not red else -2.0, 0.02)
	elif s == State.ATTACK and _attack != "shoot":
		Game.sfx("enemy_swing", -4.0 if not boss else 0.0)


static func attackers(tree: SceneTree, want_ranged := false) -> int:
	var n := 0
	for e in tree.get_nodes_in_group("enemy"):
		var en := e as Enemy
		if en.ranged != want_ranged or en.boss:
			continue
		if en.state == State.APPROACH or en.state == State.WINDUP or en.state == State.ATTACK:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_t += delta
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	_float_t -= delta
	_splat_cd -= delta
	if _poison_t > 0.0:
		_tick_poison(delta)
		if state == State.DEAD:
			return
	velocity.y -= GRAVITY * delta * (0.2 if _float_t > 0.0 else 1.0)
	var to_p := Vector3.ZERO
	var dist := INF
	if player:
		to_p = player.global_position - global_position
		to_p.y = 0
		dist = to_p.length()

	match state:
		State.IDLE:
			_brake(delta, 30.0)
			if player and dist < aggro_range and absf(player.global_position.y - global_position.y) < 6.0:
				activate()
		State.STRAFE:
			_tick_strafe(delta, to_p, dist)
		State.APPROACH:
			var reach := ATTACK_RANGE * size
			_steer((to_p.normalized() + _separation() * 0.5).normalized() * move_speed, delta)
			if dist < reach + 0.2:
				_start_windup()
			elif _t > 3.0:
				_back_off()
		State.WINDUP:
			_brake(delta, 40.0)
			_sign.scale = Vector3.ONE * (1.0 + 0.25 * sin(_t * 30.0))
			if _attack == "shoot":
				_aim_laser()
			if _t >= windup_time * (1.4 if _attack == "slam" else 1.0):
				_enter(State.ATTACK)
				_hit_done = false
				_wave_r = 0.0
				_start_strike_anim()
		State.ATTACK:
			_tick_attack(delta, to_p, dist)
		State.RECOVER:
			_brake(delta, 30.0)
			if _t >= RECOVER_TIME * (1.4 if boss else 1.0):
				_back_off()
		State.STAGGER:
			_brake(delta, 22.0)
			if _stagger_len > 0.0 and randf() < delta * 12.0:
				Fx.sparks(global_position + Vector3.UP * randf_range(0.5, 1.8) * size, Vector3.UP, Color(3.0, 2.8, 0.8), 4, 4.0)
			if _t >= (_stagger_len if _stagger_len > 0.0 else (0.8 if boss else 0.45)):
				_stagger_len = 0.0
				_back_off()
		State.FROZEN:
			_brake(delta, 60.0)
			if _t >= _freeze_len:
				_thaw()
				_back_off()
		State.AIRBORNE:
			_brake(delta, 2.0)
			if is_on_floor() and _t > 0.15:
				velocity = Vector3.ZERO
				_enter(State.DOWN)
				Game.shake(0.12)
		State.DOWN:
			_brake(delta, 30.0)
			if _t >= DOWN_TIME:
				_enter(State.GETUP)
		State.GETUP:
			_brake(delta, 30.0)
			if _t >= GETUP_TIME:
				_back_off()

	var was_air := not is_on_floor()
	var flying := Vector3(velocity.x, 0, velocity.z).length()
	move_and_slide()
	if (state == State.AIRBORNE or state == State.STAGGER) and flying > 9.0 and is_on_wall() and _splat_cd <= 0.0:
		_wall_splat()
	if _spiked and is_on_floor():
		_spiked = false
		_ground_impact()
	if _airborne_spawn and was_air and is_on_floor():
		_airborne_spawn = false
		Fx.ring(global_position, 1.8 * size, Color(1.5, 1.4, 1.3, 0.8), 0.25)
		Game.sfx("land", -8.0 if not boss else 2.0)
		if boss:
			Game.shake(0.6)
	elif is_on_floor():
		_airborne_spawn = false
	if global_position.y < home.y - 14.0:
		global_position = home
		velocity = Vector3.ZERO
	_update_visual(delta, to_p)
	if state != State.FROZEN:  # frozen mid-pose
		anim.update(delta)


func _tick_strafe(delta: float, to_p: Vector3, dist: float) -> void:
	_cooldown -= delta
	var radial := to_p.normalized() * clampf(dist - _strafe_dist, -1.0, 1.0)
	var tangent := to_p.normalized().cross(Vector3.UP) * _strafe_dir * 0.45
	_steer((radial + tangent + _separation()).limit_length(1.0) * move_speed * 0.6, delta)
	if _t > 2.5 and randf() < delta * 0.4:
		_strafe_dir = -_strafe_dir
		_t = 0.0
	if _cooldown > 0.0 or _poison_t > 0.0:  # poisoned toys are too sick to attack
		return
	if boss:
		if randf() < delta * 2.0:
			_pick_boss_attack(dist)
	elif ranged:
		if Enemy.attackers(get_tree(), true) < 1 and dist < 16.0 and randf() < delta * 1.2:
			_attack = "shoot"
			_start_windup()
	elif Enemy.attackers(get_tree()) < MAX_ATTACKERS and randf() < delta * 1.5:
		_attack = "tail" if dino and randf() < 0.35 else "slash"
		_enter(State.APPROACH)


func _pick_boss_attack(dist: float) -> void:
	if not _summoned and health < max_health * 0.5:
		_summoned = true
		_summon()
	var r := randf()
	if dist > 7.0 and r < 0.5:
		_attack = "charge"
		_start_windup()
	elif r < 0.4:
		_attack = "slam"
		_start_windup()
	else:
		_attack = "sweep"
		_enter(State.APPROACH)


func _summon() -> void:
	windup_time *= 0.8
	Game.shake(0.4)
	for i in 2:
		var e := Enemy.new()
		e.kind = summon_kind
		var a := randf() * TAU
		var at := global_position + Vector3(cos(a) * 3.5, 6.0, sin(a) * 3.5)
		e.position = (get_parent() as Node3D).to_local(at)
		get_parent().add_child(e)
		e.activate()
		_summons.append(e)


func _start_windup() -> void:
	_enter(State.WINDUP)
	var pose := DINO_BITE_WIND if dino else SWING_WIND
	match _attack:
		"shoot": pose = AIM
		"slam": pose = SLAM_WIND
	anim.play([{"pose": pose, "time": windup_time * 0.6, "ease": 0.5}, {"pose": pose, "time": 5.0}], 0.1)


func _start_strike_anim() -> void:
	match _attack:
		"shoot":
			anim.play([{"pose": RECOIL, "time": 0.05, "ease": 0.3}, {"pose": AIM, "time": 0.25}], 0.2)
		"slam":
			anim.play([{"pose": SLAM_HIT, "time": 0.08, "ease": 0.3}, {"pose": SLAM_HIT, "time": 0.6}], 0.3)
		"tail":
			anim.play([{"pose": _guard, "time": 0.05}, {"pose": _guard, "time": 0.4}], 0.2)
		_:
			var hit_pose := DINO_BITE_HIT if dino else SWING_HIT
			anim.play([{"pose": hit_pose, "time": 0.07, "ease": 0.3}, {"pose": hit_pose, "time": ATTACK_TIME + 0.15}], 0.25)


func _tick_attack(delta: float, to_p: Vector3, dist: float) -> void:
	match _attack:
		"shoot":
			velocity.x = 0.0
			velocity.z = 0.0
			if not _hit_done:
				_hit_done = true
				_fire()
			if _t >= 0.3:
				_enter(State.RECOVER)
		"slam":
			velocity.x = 0.0
			velocity.z = 0.0
			if not _hit_done and _t >= 0.08:
				_hit_done = true
				Game.sfx("slam")
				Game.shake(0.7)
				Fx.ring(global_position, 9.0, Color(3.0, 1.2, 0.5, 1.0), 0.5)
				Fx.sparks(global_position + Vector3.UP * 0.3, Vector3.UP, Color(2.5, 1.2, 0.4), 40, 14.0)
			if _hit_done:
				var prev := _wave_r
				_wave_r = minf(9.0, _wave_r + delta * 18.0)
				if player and prev < 9.0 and dist >= prev - 0.8 and dist <= _wave_r + 0.8:
					if player.global_position.y - global_position.y < 0.8:
						player.take_hit(attack_damage * 1.1, global_position)
						_wave_r = 99.0
			if _t >= 0.8:
				_enter(State.RECOVER)
		"charge":
			var dir := _forward()
			if _t < 1.2:
				_steer(dir * 16.0, 1.0)
				if not _hit_done and dist < 2.2 * size * 0.7 and _forward().dot(to_p.normalized()) > 0.3:
					_hit_done = true
					player.take_hit(attack_damage, global_position)
				if is_on_wall() or (Vector3(velocity.x, 0, velocity.z).length() < 1.0 and _t > 0.2):
					_t = 1.2
			else:
				_brake(delta, 40.0)
				if _t >= 1.6:
					_enter(State.RECOVER)
		"tail":
			# a full spin with the tail out: jump over it
			velocity.x = 0.0
			velocity.z = 0.0
			if not _hit_done and _t >= 0.15:
				_hit_done = true
				if player and dist <= 3.4 * size and player.global_position.y - global_position.y < 0.8:
					player.take_hit(attack_damage, global_position)
			if _t >= 0.4:
				_enter(State.RECOVER)
		_:
			var lunge := _forward() * (9.0 if _t < 0.1 else 0.0)
			velocity.x = lunge.x
			velocity.z = lunge.z
			if not _hit_done and _t >= 0.07:
				_hit_done = true
				var reach := (ATTACK_RANGE + 0.6) * size + (1.2 if _attack == "sweep" else 0.0)
				var arc := -0.6 if _attack == "sweep" else 0.3
				if player and dist <= reach and _forward().dot(to_p.normalized()) >= arc:
					player.take_hit(attack_damage, global_position)
			if _t >= ATTACK_TIME:
				_enter(State.RECOVER)


func _fire() -> void:
	if player == null:
		return
	var muzzle := global_position + Vector3.UP * 1.45 + _forward() * 0.9
	var aim := player.global_position + Vector3.UP * 1.1 + player.velocity * 0.15
	var p := PROJECTILE.new()
	p.shooter = self
	p.damage = attack_damage
	p.velocity = (aim - muzzle).normalized() * 26.0
	p.position = muzzle
	get_tree().current_scene.add_child(p)
	Game.sfx("shot", -2.0)
	Fx.sparks(muzzle, _forward(), Color(3.0, 2.0, 1.0), 10, 6.0)


func _aim_laser() -> void:
	if player == null:
		return
	var from := global_position + Vector3.UP * 1.45 + _forward() * 0.9
	var to := player.global_position + Vector3.UP * 1.1
	var span := to - from
	var l := span.length()
	var up := span / l
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	_laser.global_transform = Transform3D(Basis(side, up * l, side.cross(up)), from + span * 0.5)


func _forward() -> Vector3:
	return Vector3(-sin(_yaw), 0, -cos(_yaw))


func _back_off() -> void:
	_cooldown = randf_range(1.2, 3.0) * (0.6 if boss else 1.0)
	if not ranged:
		_strafe_dist = randf_range(STRAFE_MIN, STRAFE_MAX) * (1.4 if boss else 1.0)
	_attack = "slash"
	_enter(State.STRAFE)


func _brake(delta: float, rate: float) -> void:
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, rate * delta)
	velocity.x = h.x
	velocity.z = h.z


## Walks toward `want` (horizontal velocity) but never off an edge.
func _steer(want: Vector3, delta: float) -> void:
	if want.length() > 0.1:
		var ahead := global_position + want.normalized() * (0.9 * size) + Vector3.UP * 0.5
		var q := PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 2.0, 1)
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			want = Vector3.ZERO
	if _poison_t > 0.0:
		want *= 0.5
	var h := Vector3(velocity.x, 0, velocity.z).move_toward(want, 40.0 * delta)
	velocity.x = h.x
	velocity.z = h.z


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		var d: Vector3 = global_position - (e as Node3D).global_position
		d.y = 0
		var l := d.length()
		var r := 2.2 * maxf(size, (e as Enemy).size)
		if l < r and l > 0.01:
			push += d / l * (r - l)
	return push


## Returns true if the hit landed (false: blocked or already dead).
func take_hit(hit: Dictionary) -> bool:
	if state == State.DEAD:
		return false
	var dir: Vector3 = hit.get("dir", -_forward())
	var heavy: bool = hit.get("breaks_guard", false)
	var guarding := state == State.STRAFE or state == State.APPROACH or state == State.IDLE or state == State.RECOVER
	if shielded and guarding and not heavy and _forward().dot(-dir) > 0.3:
		velocity += dir * 3.0
		anim.play([{"pose": GUARD, "time": 0.04}, {"pose": GUARD, "time": 0.15}], 0.1)
		Fx.sparks(global_position + Vector3.UP * 1.1 * size - dir * 0.4, -dir, Color(2.5, 2.5, 3.0), 18, 10.0)
		return false
	if shielded and heavy and not boss:
		shielded = false
		if _shield:
			Fx.shards(_shield.global_position, dir, Color(0.55, 0.45, 0.8), 14)
			_shield.visible = false
	var dmg := float(hit.get("damage", 10.0))
	if state == State.FROZEN:
		dmg *= 2.0  # shatter the ice
		_thaw()
		Fx.shards(global_position + Vector3.UP * 1.0 * size, dir, Color(0.75, 0.92, 1.0), 14)
		Game.sfx("shatter", -4.0)
	health -= dmg
	_flash_t = 0.07
	_set_flash(true)
	Fx.shards(global_position + Vector3.UP * 1.2 * size, dir, plastic_color, 5)
	var knock: float = hit.get("knock", 5.0)
	var launch: float = hit.get("launch", 0.0)
	if health <= 0.0:
		_yaw = atan2(dir.x, dir.z)
		_die(dir * knock * 0.9 + Vector3.UP * (launch * 0.5 + 4.0))
		return true
	if float(hit.get("poison", 0.0)) > 0.0:
		poison(hit["poison"])
	var freeze: float = hit.get("freeze", 0.0)
	var stun: float = hit.get("stun", 0.0)
	if freeze > 0.0:
		_freeze(freeze * (0.4 if boss else 1.0))
		return true
	if stun > 0.0:
		_yaw = atan2(dir.x, dir.z)
		velocity = dir * 2.0
		_enter(State.STAGGER)
		_stagger_len = stun * (0.5 if boss else 1.0)
		anim.play([{"pose": Moves.HURT, "time": 0.04, "ease": 0.4}, {"pose": Moves.HURT, "time": _stagger_len}], 0.3)
		return true
	if armored and not heavy:
		# tin plating: the hit counts but it does not flinch
		velocity += dir * knock * 0.1
		Game.sfx("block", -6.0)
		Fx.sparks(global_position + Vector3.UP * 1.2 - dir * 0.3, -dir, Color(2.5, 2.4, 2.0), 10, 8.0)
		return true
	if boss:
		# super armour: light hits only chip; heavy hits and counters stagger
		velocity += dir * knock * 0.15
		if heavy:
			_yaw = atan2(dir.x, dir.z)
			_enter(State.STAGGER)
			anim.play([{"pose": Moves.HURT, "time": 0.05, "ease": 0.4}, {"pose": Moves.HURT, "time": 0.5}], 0.3)
		return true
	_yaw = atan2(dir.x, dir.z)  # face the attacker
	if not is_on_floor() and state == State.AIRBORNE:
		# juggled: each air hit pops it up and lets it hang; a finisher spikes it down
		if hit.get("spike", false):
			velocity = dir * 4.0 + Vector3.DOWN * 34.0
			_spiked = true
		else:
			velocity = dir * knock * 0.2 + Vector3.UP * maxf(launch, 5.5)
			_float_t = 0.45
		_t = 0.0
		anim.play([{"pose": Moves.HURT, "time": 0.04, "ease": 0.4}, {"pose": LYING, "time": 0.4}], 0.3)
		return true
	velocity = dir * knock + Vector3.UP * launch
	if launch >= 4.0:
		_enter(State.AIRBORNE)
		anim.play([{"pose": Moves.HURT, "time": 0.05, "ease": 0.4}, {"pose": LYING, "time": 0.6}], 0.3)
	else:
		_enter(State.STAGGER)
		anim.play([{"pose": Moves.HURT, "time": 0.04, "ease": 0.4}, {"pose": Moves.HURT, "time": 0.2}], 0.25)
	return true


## Frost's ice: the figure stops dead under a sheen of ice; the next hit
## shatters it for double damage.
func _freeze(secs: float) -> void:
	_freeze_len = secs
	_enter(State.FROZEN)
	velocity = Vector3.ZERO
	if _ice_mat == null:
		_ice_mat = StandardMaterial3D.new()
		_ice_mat.albedo_color = Color(0.65, 0.88, 1.0, 0.55)
		_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ice_mat.roughness = 0.05
		_ice_mat.emission_enabled = true
		_ice_mat.emission = Color(0.35, 0.7, 1.0)
		_ice_mat.emission_energy_multiplier = 0.5
		_ice_mat.grow = true
		_ice_mat.grow_amount = 0.02
	for m in _meshes:
		m.material_overlay = _ice_mat
	Fx.fire(global_position + Vector3.UP * 1.0 * size, Vector3.UP, 70.0, 4.0, 30, 0.5, 0.5, "frost")


func _thaw() -> void:
	if state == State.FROZEN:
		state = State.STAGGER
		_t = 0.0
	for m in _meshes:
		if m.material_overlay == _ice_mat:
			m.material_overlay = null


const POISON_DPS := 6.0


## Venom's poison: health drains, the toy slows down and will not attack.
func poison(secs: float) -> void:
	_poison_t = maxf(_poison_t, secs)


func _tick_poison(delta: float) -> void:
	_poison_t -= delta
	health -= POISON_DPS * delta * (0.4 if boss else 1.0)
	if randf() < delta * 6.0:
		Fx.sparks(global_position + Vector3.UP * randf_range(0.6, 1.8) * size, Vector3.UP, Color(0.8, 2.2, 0.3), 3, 2.5)
	if health <= 0.0:
		_die(Vector3.UP * 4.0)


const SPLAT_DAMAGE := 8.0
const SPIKE_DAMAGE := 12.0


## Knocked hard into furniture: bounce off it, and it hurts.
func _wall_splat() -> void:
	_splat_cd = 0.6
	var n := get_wall_normal()
	velocity = n * 3.0 + Vector3.UP * 2.0
	Game.sfx("hit_heavy", -4.0)
	Game.shake(0.25)
	Game.hitstop(0.05)
	Fx.sparks(global_position + Vector3.UP * 1.0 * size - n * 0.4, n, Color(2.5, 1.6, 0.8), 18, 9.0)
	Fx.shards(global_position + Vector3.UP * 1.0 * size, n, plastic_color, 6)
	_hurt_by_world(SPLAT_DAMAGE, n)


## A spiked enemy hitting the ground: crater ring, damage, flat on its back.
func _ground_impact() -> void:
	Game.sfx("land_hard")
	Game.shake(0.45)
	Game.hitstop(0.06)
	Fx.ring(global_position, 3.0, Color(2.5, 1.4, 0.6, 1.0), 0.3)
	Fx.shards(global_position + Vector3.UP * 0.3, Vector3.UP, plastic_color, 8)
	velocity = Vector3.ZERO
	_enter(State.DOWN)
	_hurt_by_world(SPIKE_DAMAGE, Vector3.UP)


func _hurt_by_world(dmg: float, dir: Vector3) -> void:
	health -= dmg
	_flash_t = 0.07
	_set_flash(true)
	if health <= 0.0:
		_die(dir * 4.0 + Vector3.UP * 4.0)


func _die(impulse: Vector3) -> void:
	_enter(State.DEAD)
	collision_layer = 0
	remove_from_group("enemy")
	remove_from_group("boss")
	_set_flash(false)
	if _laser:
		_laser.visible = false
	Game.sfx("shatter", 4.0 if boss else 0.0)
	if boss:
		Game.slowmo(0.15, 2.0)
		Game.shake(1.0)
		Fx.ring(global_position, 12.0, Color(3.0, 1.6, 0.6, 1.0), 0.8)
		for e in _summons:  # the king's guard falls with him
			if is_instance_valid(e) and e.is_alive():
				e.take_hit({"damage": 999.0, "dir": (e.global_position - global_position).normalized()})
	Fx.shatter(_figure, impulse)
	died.emit(self)
	get_tree().create_timer(0.5, false).timeout.connect(queue_free)


func _set_flash(on: bool) -> void:
	for m in _meshes:
		m.material_overlay = _flash_mat if on else null


func _update_visual(delta: float, to_p: Vector3) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_set_flash(false)
	var tracking := state in [State.STRAFE, State.APPROACH, State.WINDUP] and to_p.length() > 0.1
	if tracking and not (state == State.WINDUP and _attack == "charge" and _t > windup_time * 0.7):
		_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-10.0 * delta))
	var down := state == State.AIRBORNE or state == State.DOWN
	var target_pitch := 0.0
	if state == State.AIRBORNE:
		target_pitch = 80.0 * clampf(_t * 3.0, 0.0, 1.0)
	elif state == State.DOWN:
		target_pitch = 88.0
	elif state == State.ATTACK and _attack == "charge" and _t < 1.2:
		target_pitch = -25.0
	_down_pitch = lerpf(_down_pitch, target_pitch, 1.0 - exp(-(14.0 if down else 7.0) * delta))
	var spin := 0.0
	if state == State.ATTACK and _attack == "tail":
		spin = TAU * clampf(_t / 0.35, 0.0, 1.0)
	visual.rotation = Vector3(deg_to_rad(_down_pitch), _yaw + spin, 0)
	if _key:
		_key.rotation.z += delta * 5.0
	visual.position.y = (0.95 - 0.7 * (maxf(_down_pitch, 0.0) / 90.0)) * size

	var h := Vector3(velocity.x, 0, velocity.z)
	match state:
		State.STRAFE, State.APPROACH:
			var spd := h.length()
			_walk_phase += spd * delta * TAU / (2.6 * size)
			var walk := Poses.run(_walk_phase, clampf(spd / 8.0, 0.0, 0.7))
			var keys := ["upper_arm_r", "lower_arm_r", "hand_r", "upper_arm_l", "lower_arm_l"]
			if dino:  # the dino keeps its forward lean while it runs
				keys += ["abdomen", "chest", "head"]
			for k in keys:
				if _guard.has(k):
					walk[k] = _guard[k]
			anim.set_base(walk, 14.0)
		State.ATTACK:
			if _attack == "charge":
				var spd := h.length()
				_walk_phase += spd * delta * TAU / (2.6 * size)
				anim.set_base(Poses.run(_walk_phase, 1.0), 20.0)
		State.DOWN, State.AIRBORNE:
			anim.set_base(LYING, 10.0)
		_:
			anim.set_base(_guard, 10.0)
