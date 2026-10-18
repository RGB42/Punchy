class_name Player
extends CharacterBody3D
## The action figure the player drives. One state machine for all movement:
## run, jump, double jump (front flip), glide, air dash / ground roll, rocket
## boost, ledge hang + shimmy + climb up, free climbing on climbable surfaces,
## grapple pull and grapple swing.
##
## Input comes in as an *intent* (move_input, jump_pressed, ...). Real play fills
## it from the InputMap; tests set `scripted = true` and write it directly.
## The node origin is at the feet.

signal landed(impact: float)

enum State { GROUND, AIR, GLIDE, DASH, LEDGE, CLIMB_UP, CLIMB, GRAPPLE_PULL, GRAPPLE_SWING, ACTION }

const BLINK_DIST := 8.0  # Volt's air power
const ICE_LIFETIME := 4.0  # Frost's air platform
const GRIP_TIME := 3.0  # Stone: seconds on any wall
const UPDRAFT_TIME := 3.0  # Gale: seconds of rising glide
const UPDRAFT_RISE := 3.5
const VINE_RANGE := 18.0  # Venom: aim-anywhere grapple
const PHASE_HEIGHT := 5.0  # Shade: teleport up through anything
const VINE_HOLD := 2.0  # Venom: seconds the vine holds you on a wall

const WORLD_MASK := 1
const CLIMB_MASK := 8

const RUN_SPEED := 10.0
const GROUND_ACCEL := 80.0
const GROUND_DECEL := 90.0
const AIR_ACCEL := 32.0
const AIR_DRAG := 6.0
const GRAVITY_UP := 38.0
const GRAVITY_DOWN := 58.0
const JUMP_CUT := 2.4  # gravity multiplier while rising with jump released
const MAX_FALL := 45.0
const JUMP_APEX := 3.2
const DOUBLE_APEX := 2.6
const ROCKET_APEX := 4.5
const COYOTE := 0.12
const BUFFER := 0.12
const DASH_SPEED := 24.0
const DASH_TIME := 0.18
const ROLL_SPEED := 16.0
const ROLL_TIME := 0.32
const GLIDE_FALL := 2.5
const GLIDE_SPEED := 11.0
const FLIP_TIME := 0.42
const CLIMB_SPEED := 6.0
const CLIMB_UP_TIME := 0.38
const SHIMMY_SPEED := 3.0
const HANG_DROP := 2.05  # ledge height above the feet while hanging
const GRAPPLE_RANGE := 26.0
const PULL_SPEED := 32.0
const SWING_LEN := 9.0  # shortest rope a swing reels in to
const SWING_LEN_MAX := 14.0  # longest: far hooks give long, sweeping arcs
const SWING_PUMP := 16.0
const STRIDE := 2.8  # units travelled per run cycle

var state := State.GROUND
var facing := Vector3.FORWARD
var checkpoint := Vector3.ZERO  # where death sends you; ZERO = last safe ground
var camera: Node3D  # PlayerCamera; sets itself

# --- intent ---
var scripted := false
var move_input := Vector2.ZERO  # x right, y forward, camera-relative
var view_yaw := 0.0
var jump_pressed := false
var jump_held := false
var dodge_pressed := false
var grapple_pressed := false
var power_pressed := false
var attack_pressed := false
var heavy_pressed := false
var counter_pressed := false

var visual: Node3D
var anim: FigureAnimator
var combat: PlayerCombat
var hero: Dictionary
var element := "blaze"
var grapple_target: GrapplePoint

var _coyote := 0.0
var _jump_buffer := 0.0
var _jumping := false  # rising from a jump (variable height applies)
var _can_double := true
var _can_dash := true
var _can_rocket := true
var _state_t := 0.0
var _dash_dir := Vector3.ZERO
var _dash_ground := false
var _ledge_normal := Vector3.ZERO
var _ledge_point := Vector3.ZERO
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _wall_normal := Vector3.ZERO
var _push_t := 0.0
var _ignore_ledge := 0.0
var _ignore_climb := 0.0
var _anchor := Vector3.ZERO
var _pull_dir := Vector3.ZERO
var _rope_len := 0.0
var _rope_target := 0.0
var _rope: MeshInstance3D
var _run_phase := 0.0
var _climb_phase := 0.0
var _flip_t := 99.0
var _flip_len := FLIP_TIME
var _rocket_t := 99.0
var _yaw := 0.0
var _pitch := 0.0
var _time := 0.0
var _safe_pos := Vector3.ZERO
var _safe_t := 0.0
var _jet: CPUParticles3D
var _climb_mask := CLIMB_MASK
var _gripping := false  # Stone holding a plain wall
var _grip_t := 0.0
var _updraft_t := 0.0
var _vine_normal := Vector3.ZERO  # Venom: surface the vine bit into; ZERO = normal hook


func _ready() -> void:
	add_to_group("player")
	visual = Node3D.new()
	visual.name = "Visual"
	visual.position = Vector3(0, 0.95, 0)  # pivot at the hips so flips spin in place
	add_child(visual)
	hero = Heroes.by_id(Game.hero)
	element = hero["id"]
	var fig: Node3D = (load(hero["model"]) as PackedScene).instantiate()
	fig.position = Vector3(0, -0.95, 0)
	visual.add_child(fig)
	anim = FigureAnimator.new(fig)
	anim.snap_base(Poses.IDLE)
	_jet = Fx.thruster(element)
	_jet.position = Vector3(0, 0.03, 0.22)  # between the two back nozzles
	(anim.joints["chest"] as Node3D).add_child(_jet)
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	cyl.radial_segments = 6
	_rope.mesh = cyl
	var rm := StandardMaterial3D.new()
	rm.albedo_color = hero["color"]
	rm.emission_enabled = true
	rm.emission = hero["color"]
	rm.emission_energy_multiplier = 2.0
	_rope.material_override = rm
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)
	_yaw = atan2(-facing.x, -facing.z)
	_safe_pos = global_position
	combat = PlayerCombat.new(self)
	combat.name = "Combat"
	add_child(combat)
	combat.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not scripted:
		_gather_input()
	_time += delta
	_state_t += delta
	_ignore_ledge -= delta
	_ignore_climb -= delta
	_flip_t += delta
	_rocket_t += delta
	_jump_buffer = BUFFER if jump_pressed else maxf(0.0, _jump_buffer - delta)
	_update_grapple_target()
	combat.tick_global(delta)

	match state:
		State.GROUND: _tick_ground(delta)
		State.AIR: _tick_air(delta)
		State.GLIDE: _tick_glide(delta)
		State.DASH: _tick_dash(delta)
		State.LEDGE: _tick_ledge(delta)
		State.CLIMB_UP: _tick_climb_up()
		State.CLIMB: _tick_climb(delta)
		State.GRAPPLE_PULL: _tick_pull()
		State.GRAPPLE_SWING: _tick_swing(delta)
		State.ACTION: combat.tick_action(delta)

	if global_position.y < -30.0:
		respawn()
	_update_visual(delta)
	anim.update(delta)
	jump_pressed = false
	dodge_pressed = false
	grapple_pressed = false
	power_pressed = false
	attack_pressed = false
	heavy_pressed = false
	counter_pressed = false


func _gather_input() -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	jump_pressed = Input.is_action_just_pressed("jump")
	jump_held = Input.is_action_pressed("jump")
	dodge_pressed = Input.is_action_just_pressed("dodge")
	grapple_pressed = Input.is_action_just_pressed("grapple")
	power_pressed = Input.is_action_just_pressed("power")
	attack_pressed = Input.is_action_just_pressed("attack")
	heavy_pressed = Input.is_action_just_pressed("heavy")
	counter_pressed = Input.is_action_just_pressed("counter")
	if camera:
		view_yaw = camera.rotation.y


func set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	_rope.visible = s == State.GRAPPLE_PULL or s == State.GRAPPLE_SWING


func end_action() -> void:
	set_state(State.GROUND if is_on_floor() else State.AIR)


func take_hit(damage: float, from: Vector3) -> bool:
	return combat.take_hit(damage, from)


func _on_died() -> void:
	if checkpoint != Vector3.ZERO:
		_safe_pos = checkpoint
	respawn()
	combat.heal_full()


## Attack, heavy, counter and (grounded) power start a combat action.
func _combat_input() -> bool:
	if counter_pressed and combat.try_start("counter"):
		return true
	if attack_pressed and combat.try_start("attack"):
		return true
	if heavy_pressed and combat.try_start("heavy"):
		return true
	if power_pressed and is_on_floor() and combat.try_start("power"):
		return true
	return false


func respawn() -> void:
	global_position = _safe_pos
	velocity = Vector3.ZERO
	set_state(State.AIR)


func wish_dir() -> Vector3:
	var v := Vector3(move_input.x, 0, -move_input.y)
	if v.length() > 1.0:
		v = v.normalized()
	return v.rotated(Vector3.UP, view_yaw)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# ------------------------------------------------------------------ ground / air

func _tick_ground(delta: float) -> void:
	if _combat_input():
		return
	var wish := wish_dir() * RUN_SPEED
	var h := Vector3(velocity.x, 0, velocity.z)
	h = h.move_toward(wish, (GROUND_ACCEL if wish.length() > 0.1 else GROUND_DECEL) * delta)
	velocity = Vector3(h.x, -2.0, h.z)
	if _jump_buffer > 0.0:
		_jump(JUMP_APEX)
		Game.sfx("jump", -8.0)
		return
	if dodge_pressed:
		_start_dash(true)
		return
	if grapple_pressed and grapple_target:
		_start_grapple()
		return
	move_and_slide()
	# Walking into a ladder or curtain starts the climb, no jump needed.
	if is_on_wall() and wish.length() > 0.1 and _ignore_climb <= 0.0 and _try_climb():
		return
	if not is_on_floor():
		_coyote = COYOTE
		velocity.y = 0.0
		set_state(State.AIR)
	else:
		_safe_t += delta
		if _safe_t > 0.5:
			_safe_pos = global_position
			_safe_t = 0.0


func _jump(apex: float) -> void:
	velocity.y = sqrt(2.0 * GRAVITY_UP * apex)
	_jumping = true
	_coyote = 0.0
	_jump_buffer = 0.0
	set_state(State.AIR)


func _refresh_air_moves() -> void:
	_can_double = true
	_can_dash = true
	_can_rocket = true


func _apply_gravity(delta: float) -> void:
	var g := GRAVITY_UP if velocity.y > 0.0 else GRAVITY_DOWN
	if velocity.y > 0.0 and _jumping and not jump_held:
		g *= JUMP_CUT
	if velocity.y <= 0.0:
		_jumping = false
	velocity.y = maxf(velocity.y - g * delta, -MAX_FALL)


func _air_steer(delta: float, top_speed: float, accel: float) -> void:
	var wish := wish_dir()
	var h := Vector3(velocity.x, 0, velocity.z)
	if wish.length() > 0.1:
		# Steer without bleeding momentum the player earned (grapple, dash).
		var target := wish * maxf(top_speed, h.length() if h.length() > top_speed else 0.0)
		h = h.move_toward(target, accel * delta)
	else:
		h = h.move_toward(Vector3.ZERO, AIR_DRAG * delta)
	velocity.x = h.x
	velocity.z = h.z


func _tick_air(delta: float) -> void:
	if _combat_input():
		return
	_coyote -= delta
	_apply_gravity(delta)
	_air_steer(delta, RUN_SPEED, AIR_ACCEL)
	if _jump_buffer > 0.0:
		if _coyote > 0.0:
			_jump(JUMP_APEX)
			Game.sfx("jump", -8.0)
		elif _can_double:
			_double_jump()
	if jump_held and velocity.y < -1.0 and not _can_double and not _jumping:
		set_state(State.GLIDE)
	if _air_abilities():
		return
	var vy := velocity.y
	move_and_slide()
	if is_on_floor() and vy <= 0.0:
		_land(-vy)
		return
	_edge_checks()


## Moves available in any airborne state. True if one took over.
func _air_abilities() -> bool:
	if dodge_pressed and _can_dash:
		_start_dash(false)
		return true
	if power_pressed and _can_rocket:
		_can_rocket = false
		match element:
			"frost": _ice_platform()
			"volt": _blink()
			"stone": _rock_grip()
			"venom": _vine()
			"gale": _updraft()
			"shade": _phase_up()
			_: _rocket()
		return true
	if grapple_pressed and grapple_target:
		_start_grapple()
		return true
	return false


## Blaze: a burst of fire from the back thrusters carries you up.
func _rocket() -> void:
	velocity.y = sqrt(2.0 * GRAVITY_UP * ROCKET_APEX)
	_jumping = false
	_rocket_t = 0.0
	Game.shake(0.2)
	Game.sfx("rocket", -2.0)
	Fx.fire(global_position + Vector3.UP * 0.8, Vector3.DOWN, 30.0, 14.0, 70, 0.8, 0.45, element)
	anim.play([{"pose": Poses.ROCKET, "time": 0.06, "ease": 0.4}, {"pose": Poses.ROCKET, "time": 0.3}], 0.25)
	set_state(State.AIR)


## Frost: a block of ice forms under your feet and holds for a few seconds.
func _ice_platform() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.add_to_group("ice_platform")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 0.5, 3.2)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.9, 1.0, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic = 0.2
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.6
	mesh.material_override = mat
	body.add_child(mesh)
	body.position = global_position - Vector3.UP * 0.3
	get_parent().add_child(body)
	velocity.y = maxf(velocity.y, 0.0)
	_jumping = false
	Game.sfx("freeze", -2.0)
	Fx.fire(body.global_position, Vector3.UP, 80.0, 6.0, 50, 0.6, 0.5, "frost")
	var tw := body.create_tween()
	tw.tween_interval(ICE_LIFETIME - 0.6)
	tw.tween_property(mat, "albedo_color:a", 0.25, 0.6)
	tw.tween_callback(func() -> void:
		Fx.shards(body.global_position, Vector3.UP, Color(0.75, 0.92, 1.0), 12)
		Game.sfx("shatter", -8.0)
		body.queue_free())


func _on_ice() -> bool:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider() as Node
		if col and col.is_in_group("ice_platform"):
			return true
	return false


## Stone: rock fingers bite into any wall for a few seconds.
func _rock_grip() -> void:
	_grip_t = GRIP_TIME
	Game.sfx("quake", -12.0)
	if not _try_climb(true, true):
		_can_rocket = false  # stays armed: the next wall touched in this jump is gripped


## Where Venom's vine would bite right now ({} if nothing in range). Aims
## along the camera, tilted 25 deg up so looking ahead reaches up and forward.
func vine_aim() -> Dictionary:
	var dir := facing
	if camera:
		var pitch: float = camera.pitch + 0.45
		dir = (Basis(Vector3.UP, camera.rotation.y) * Basis(Vector3.RIGHT, pitch)) * Vector3.FORWARD
	var eye := global_position + Vector3.UP * 1.5
	return _ray(eye, eye + dir.normalized() * VINE_RANGE, WORLD_MASK)


## Venom: shoot a vine at whatever you aim at and pull yourself to it.
func _vine() -> void:
	var hit := vine_aim()
	if hit.is_empty():
		_can_rocket = true  # nothing to bite: try again
		Game.sfx("swing", -10.0)
		return
	_anchor = hit.position + hit.normal * 0.4
	_vine_normal = hit.normal
	var flat := Vector3(_anchor.x - global_position.x, 0, _anchor.z - global_position.z)
	_pull_dir = flat.normalized() if flat.length() > 0.3 else facing
	_jumping = false
	set_state(State.GRAPPLE_PULL)
	_update_rope()
	Game.sfx("grapple_fire", -4.0)
	Game.sfx("poison", -10.0)


## Gale: a column of wind lifts the glide for a few seconds.
func _updraft() -> void:
	_updraft_t = UPDRAFT_TIME
	_jumping = false
	velocity.y = maxf(velocity.y, 2.0)
	set_state(State.GLIDE)
	Game.sfx("wind", -2.0)
	Fx.cloud(global_position, "gale", 0.6, 1.5, 14.0)


## Shade: melt into shadow and reappear above, through floors and shelves.
func _phase_up() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = WORLD_MASK
	q.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var from := global_position
	for i in 13:
		var h := PHASE_HEIGHT - i * 0.25 if i < 9 else PHASE_HEIGHT + (i - 8) * 0.4
		q.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * (h + 0.9))
		if space.intersect_shape(q, 1).is_empty():
			global_position = from + Vector3.UP * h
			velocity = Vector3(velocity.x * 0.3, 2.0, velocity.z * 0.3)
			_jumping = false
			Game.sfx("shadow")
			Fx.cloud(from + Vector3.UP, "shade", 0.25, 1.0)
			Fx.cloud(global_position + Vector3.UP, "shade", 0.25, 1.0)
			return
	_can_rocket = true  # no room above


## Volt: zap forward, stopping short of anything solid.
func _blink() -> void:
	var dir := wish_dir().normalized() if wish_dir().length() > 0.2 else facing
	var from := global_position + Vector3.UP * 0.9
	var dist := BLINK_DIST
	for h: float in [0.3, 0.9, 1.6]:
		var o: Vector3 = global_position + Vector3.UP * h
		var hit := _ray(o, o + dir * BLINK_DIST, WORLD_MASK)
		if not hit.is_empty():
			dist = minf(dist, (hit.position - o).length() - 0.6)
	dist = maxf(dist, 0.0)
	global_position += dir * dist
	facing = dir
	velocity = Vector3(dir.x * RUN_SPEED, maxf(velocity.y, 3.0), dir.z * RUN_SPEED)
	_jumping = false
	Game.sfx("zap", -2.0)
	Game.shake(0.15)
	Fx.lightning(from, global_position + Vector3.UP * 0.9)
	Fx.sparks(global_position + Vector3.UP, -dir, Color(3.0, 2.8, 0.8), 20, 8.0)


func _edge_checks() -> void:
	if _ignore_ledge <= 0.0 and velocity.y < 6.0 and _try_ledge():
		return
	if _ignore_climb <= 0.0:
		_try_climb(_grip_t > 0.0 and not _gripping)


func _double_jump() -> void:
	_can_double = false
	_jump(DOUBLE_APEX)
	var wish := wish_dir()
	if wish.length() > 0.2:
		var h := wish.normalized() * maxf(horizontal_speed(), RUN_SPEED * 0.85)
		velocity.x = h.x
		velocity.z = h.z
	_flip_t = 0.0
	_flip_len = FLIP_TIME
	Game.sfx("double_jump", -6.0)
	anim.play([
		{"pose": Poses.TUCK, "time": 0.08, "ease": 0.4},
		{"pose": Poses.TUCK, "time": 0.22},
		{"pose": Poses.FALL, "time": 0.15},
	], 0.2)


func _land(impact: float) -> void:
	_refresh_air_moves()
	_grip_t = 0.0
	_updraft_t = 0.0
	if _on_ice():
		_can_rocket = false  # no ice staircases: Frost's platform recharges on solid ground only
	_jumping = false
	set_state(State.GROUND)
	velocity.y = 0.0
	if impact > 16.0:
		var hard := clampf((impact - 16.0) / 25.0, 0.0, 1.0)
		anim.play([
			{"pose": Poses.LAND, "time": 0.05, "ease": 0.4},
			{"pose": Poses.LAND, "time": 0.04 + 0.1 * hard},
		], 0.2)
		Game.shake(0.1 + 0.3 * hard)
		Game.sfx("land_hard", -4.0 + 4.0 * hard)
	elif impact > 6.0:
		Game.sfx("land", -10.0)
	landed.emit(impact)


func _tick_glide(delta: float) -> void:
	if _combat_input():
		return
	if _updraft_t > 0.0:  # Gale's updraft: the glide climbs, no button needed
		_updraft_t -= delta
		velocity.y = move_toward(velocity.y, UPDRAFT_RISE, 40.0 * delta)
	else:
		velocity.y = move_toward(velocity.y, -GLIDE_FALL, (GRAVITY_DOWN if velocity.y > -GLIDE_FALL else 70.0) * delta)
	var wish := wish_dir()
	var h := Vector3(velocity.x, 0, velocity.z)
	var target := wish * GLIDE_SPEED if wish.length() > 0.1 else facing * GLIDE_SPEED * 0.55
	h = h.move_toward(target, 18.0 * delta)
	velocity.x = h.x
	velocity.z = h.z
	if _updraft_t <= 0.0 and not jump_held:
		set_state(State.AIR)
		return
	if _air_abilities():
		return
	move_and_slide()
	if is_on_floor():
		_land(0.0)
		return
	_edge_checks()


func _start_dash(ground: bool) -> void:
	var wish := wish_dir()
	_dash_dir = wish.normalized() if wish.length() > 0.2 else facing
	_dash_ground = ground
	facing = _dash_dir
	set_state(State.DASH)
	if ground:
		_flip_t = 0.0
		_flip_len = ROLL_TIME
		anim.play([{"pose": Poses.TUCK, "time": 0.06, "ease": 0.4}, {"pose": Poses.TUCK, "time": ROLL_TIME - 0.1}], 0.15)
		Game.sfx("swing", -8.0)
	else:
		_can_dash = false
		_jumping = false
		Game.shake(0.12)
		Game.sfx("dash", -3.0)
		Fx.fire(global_position + Vector3.UP * 1.3 - _dash_dir * 0.5, -_dash_dir, 25.0, 10.0, 40, 0.6, 0.35, element)
		anim.play([{"pose": Poses.DASH, "time": 0.05, "ease": 0.4}, {"pose": Poses.DASH, "time": DASH_TIME}], 0.2)


func _tick_dash(delta: float) -> void:
	if _dash_ground:
		velocity = _dash_dir * ROLL_SPEED + Vector3(0, -2.0, 0)
	else:
		velocity = _dash_dir * DASH_SPEED
	move_and_slide()
	var done := _state_t >= (ROLL_TIME if _dash_ground else DASH_TIME)
	if done:
		var keep := _dash_dir * RUN_SPEED * 1.1
		velocity = Vector3(keep.x, 0.0, keep.z)
		if is_on_floor():
			set_state(State.GROUND)
		else:
			_coyote = COYOTE if _dash_ground else 0.0
			set_state(State.AIR)
		return
	if _dash_ground and not is_on_floor():
		_coyote = COYOTE
		set_state(State.AIR)
		return
	if not _dash_ground:
		if is_on_floor():
			_land(0.0)
			return
		if grapple_pressed and grapple_target:
			_start_grapple()
			return
		_edge_checks()


# ------------------------------------------------------------------ ledges

func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


## Looks for a grabbable edge in front of a figure standing at `pos`.
## Returns {normal, point} (point = edge top above the wall hit) or {}.
func probe_ledge(pos: Vector3, fwd: Vector3) -> Dictionary:
	var from := pos + Vector3.UP * 1.5
	var hit := _ray(from, from + fwd * 0.9, WORLD_MASK)
	if hit.is_empty() or absf(hit.normal.y) > 0.3:
		return {}
	var n := Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	var top_from := Vector3(hit.position.x, pos.y + 3.0, hit.position.z) - n * 0.25
	var top := _ray(top_from, top_from + Vector3.DOWN * 2.4, WORLD_MASK)
	if top.is_empty() or top.normal.y < 0.7:
		return {}
	var h: float = top.position.y - pos.y
	if h < 1.2 or h > 2.9:
		return {}
	var head := _ray(top.position + Vector3.UP * 0.05, top.position + Vector3.UP * 1.9, WORLD_MASK)
	if not head.is_empty():
		return {}
	return {"normal": n, "point": Vector3(hit.position.x, top.position.y, hit.position.z)}


func _hang_position(info: Dictionary) -> Vector3:
	var n: Vector3 = info["normal"]
	var p: Vector3 = info["point"]
	return p + n * 0.38 - Vector3.UP * HANG_DROP


func _try_ledge() -> bool:
	var fwd := facing
	var wish := wish_dir()
	if wish.length() > 0.3:
		fwd = wish.normalized()
	var info := probe_ledge(global_position, fwd)
	if info.is_empty():
		return false
	_grab_ledge(info)
	return true


func _grab_ledge(info: Dictionary) -> void:
	_ledge_normal = info["normal"]
	_ledge_point = info["point"]
	global_position = _hang_position(info)
	velocity = Vector3.ZERO
	facing = -_ledge_normal
	_refresh_air_moves()
	_jump_buffer = 0.0
	_push_t = 0.0
	set_state(State.LEDGE)
	anim.play([{"pose": Poses.LEDGE_HANG, "time": 0.05, "ease": 0.4}], 0.12)
	Game.shake(0.05)


func _tick_ledge(delta: float) -> void:
	velocity = Vector3.ZERO
	var right := (-_ledge_normal).cross(Vector3.UP)
	if absf(move_input.x) > 0.25:
		var cand := global_position + right * signf(move_input.x) * SHIMMY_SPEED * delta
		var info := probe_ledge(cand, -_ledge_normal)
		if not info.is_empty():
			_ledge_normal = info["normal"]
			_ledge_point = info["point"]
			global_position = _hang_position(info)
	var wish := wish_dir()
	_push_t = _push_t + delta if wish.dot(-_ledge_normal) > 0.7 else 0.0
	if _state_t < 0.15:
		return
	if dodge_pressed:
		_ignore_ledge = 0.4
		set_state(State.AIR)
		return
	if _jump_buffer > 0.0 and wish.dot(_ledge_normal) > 0.5:
		_jump_buffer = 0.0
		velocity = _ledge_normal * 8.0
		_jump(DOUBLE_APEX)
		_ignore_ledge = 0.3
		facing = _ledge_normal
		return
	if _jump_buffer > 0.0 or _push_t > 0.2:
		_jump_buffer = 0.0
		_start_climb_up()


func _start_climb_up() -> void:
	_climb_from = global_position
	_climb_to = _ledge_point - _ledge_normal * 0.6 + Vector3.UP * 0.02
	set_state(State.CLIMB_UP)
	anim.play([
		{"pose": Poses.CLIMB_UP, "time": CLIMB_UP_TIME * 0.5, "ease": 0.6},
		{"pose": Poses.LAND, "time": CLIMB_UP_TIME * 0.5},
	], 0.2)


func _tick_climb_up() -> void:
	var t := clampf(_state_t / CLIMB_UP_TIME, 0.0, 1.0)
	var mid := Vector3(_climb_from.x, _climb_to.y, _climb_from.z)
	if t < 0.55:
		global_position = _climb_from.lerp(mid, ease(t / 0.55, 0.6))
	else:
		global_position = mid.lerp(_climb_to, ease((t - 0.55) / 0.45, 0.8))
	velocity = Vector3.ZERO
	if t >= 1.0:
		_refresh_air_moves()
		set_state(State.GROUND)


# ------------------------------------------------------------------ climbing

## Climb a climbable surface in front. any_wall (Stone's rock grip) also takes
## plain walls, but only for GRIP_TIME and without recharging the grip.
func _try_climb(any_wall := false, use_facing := false) -> bool:
	var wish := wish_dir()
	if wish.length() < 0.3 and not use_facing:
		return false
	var fwd := wish.normalized() if wish.length() >= 0.3 else facing
	var mask := CLIMB_MASK | (WORLD_MASK if any_wall else 0)
	var hit := _ray(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.0 + fwd * (1.4 if use_facing else 0.8), mask)
	if hit.is_empty() or absf(hit.normal.y) > 0.4:
		return false
	var n := Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	if fwd.dot(-n) < 0.5:
		return false
	var climbable := ((hit.collider as CollisionObject3D).collision_layer & CLIMB_MASK) != 0
	_wall_normal = n
	var p: Vector3 = hit.position + n * 0.38
	global_position = Vector3(p.x, global_position.y, p.z)
	velocity = Vector3.ZERO
	facing = -n
	_refresh_air_moves()
	_gripping = not climbable
	_climb_mask = mask if _gripping else CLIMB_MASK
	if _gripping:
		_can_rocket = false  # one grip per jump: no endless wall climbing
		Game.sfx("land_hard", -8.0)
		Fx.shards(global_position + Vector3.UP * 1.0 - n * 0.4, n, Color(0.45, 0.38, 0.3), 8)
	_jump_buffer = 0.0
	set_state(State.CLIMB)
	return true


func _tick_climb(delta: float) -> void:
	var n := _wall_normal
	var right := (-n).cross(Vector3.UP)
	var v := right * move_input.x + Vector3.UP * move_input.y
	velocity = v * CLIMB_SPEED - n * 1.5
	_climb_phase += v.length() * CLIMB_SPEED * delta * 2.2
	move_and_slide()
	if _gripping:
		_grip_t -= delta
		if _grip_t <= 0.0:  # the rock fingers give out
			_gripping = false
			_ignore_climb = 0.5
			Fx.shards(global_position + Vector3.UP * 1.2 - n * 0.4, n, Color(0.45, 0.38, 0.3), 10)
			set_state(State.AIR)
			return
	if _state_t > 0.1 and dodge_pressed:
		_ignore_climb = 0.4
		set_state(State.AIR)
		return
	if _state_t > 0.1 and _jump_buffer > 0.0:
		_jump_buffer = 0.0
		velocity = n * 9.0
		_jump(2.2)
		facing = n
		_ignore_climb = 0.35
		return
	var head := _ray(global_position + Vector3.UP * 1.9, global_position + Vector3.UP * 1.9 - n * 0.9, _climb_mask)
	if head.is_empty():
		var info := probe_ledge(global_position, -n)
		if not info.is_empty() and move_input.y > 0.2:
			_ledge_normal = info["normal"]
			_ledge_point = info["point"]
			_start_climb_up()
			return
	var body := _ray(global_position + Vector3.UP * 0.9, global_position + Vector3.UP * 0.9 - n * 0.9, _climb_mask)
	if body.is_empty() and head.is_empty():
		set_state(State.AIR)
		return
	var hit := body if not body.is_empty() else head
	_wall_normal = Vector3(hit.normal.x, 0, hit.normal.z).normalized()
	if is_on_floor() and move_input.y < -0.3:
		set_state(State.GROUND)


# ------------------------------------------------------------------ grapple

func _update_grapple_target() -> void:
	var best: GrapplePoint = null
	if state != State.GRAPPLE_PULL and state != State.GRAPPLE_SWING and state != State.CLIMB_UP:
		var look := facing
		if camera:
			look = -camera.global_basis.z
		var eye := global_position + Vector3.UP * 1.5
		var best_score := -INF
		for node in get_tree().get_nodes_in_group("grapple_point"):
			var g := node as GrapplePoint
			var to := g.global_position - eye
			var d := to.length()
			if d > GRAPPLE_RANGE or d < 1.5:
				continue
			var align := look.dot(to / d)
			# A hook high overhead is hard to look at; roughly facing its way is enough.
			var flat := Vector2(to.x, to.z)
			var look_flat := Vector2(look.x, look.z).normalized()
			if to.y > 3.0 and (flat.length() < 1.0 or look_flat.dot(flat.normalized()) > 0.2):
				align = maxf(align, 0.6)
			if align < 0.45:
				continue
			if not _ray(eye, g.global_position - to / d * 0.6, WORLD_MASK).is_empty():
				continue
			var score := align * 2.0 - d / GRAPPLE_RANGE
			if score > best_score:
				best_score = score
				best = g
	if best != grapple_target:
		if is_instance_valid(grapple_target):
			grapple_target.set_highlight(false)
		if best:
			best.set_highlight(true)
		grapple_target = best


func _start_grapple() -> void:
	_anchor = grapple_target.global_position
	_refresh_air_moves()
	_jumping = false
	Game.shake(0.08)
	Game.sfx("grapple_fire", -4.0)
	Game.sfx("grapple_hit", -8.0)
	_vine_normal = Vector3.ZERO
	if grapple_target.mode == GrapplePoint.Mode.PULL:
		var flat := Vector3(_anchor.x - global_position.x, 0, _anchor.z - global_position.z)
		# a hook nearly overhead says nothing about where to go: fling the way you face
		_pull_dir = flat.normalized() if flat.length() > 2.5 else facing
		set_state(State.GRAPPLE_PULL)
	else:
		_rope_len = clampf((_anchor - (global_position + Vector3.UP * 2.0)).length(), 4.0, GRAPPLE_RANGE)
		_rope_target = clampf(_rope_len, SWING_LEN, SWING_LEN_MAX)
		set_state(State.GRAPPLE_SWING)
	_update_rope()


## Zips the chest to just above the hook, then flings the figure up and over the
## edge in the direction it was pulled.
func _tick_pull() -> void:
	var to := _anchor + Vector3.UP * 1.0 - (global_position + Vector3.UP * 1.0)
	var stuck := _state_t > 0.25 and get_real_velocity().length() < 2.0
	if to.length() < 0.8 or _state_t > 2.0 or stuck:
		if absf(_vine_normal.y) < 0.4 and _vine_normal != Vector3.ZERO:
			# the vine hit a wall: hang on it for a moment instead of bouncing off
			facing = -Vector3(_vine_normal.x, 0, _vine_normal.z).normalized()
			_vine_normal = Vector3.ZERO
			_grip_t = VINE_HOLD
			if _try_climb(true, true):
				return
		_vine_normal = Vector3.ZERO
		velocity = _pull_dir * 9.0
		_jump(1.6)
		Game.shake(0.12)
		return
	velocity = to.normalized() * minf(PULL_SPEED, to.length() * 20.0 + 4.0)
	move_and_slide()
	_update_rope()


func _tick_swing(delta: float) -> void:
	velocity.y -= GRAVITY_UP * delta
	velocity += wish_dir() * SWING_PUMP * delta
	_rope_len = move_toward(_rope_len, _rope_target, 14.0 * delta)
	var hand := global_position + Vector3.UP * 2.0
	var nxt := hand + velocity * delta
	var d := nxt - _anchor
	if d.length() > _rope_len:
		nxt = _anchor + d.normalized() * _rope_len
		velocity = (nxt - hand) / delta
	velocity = velocity.limit_length(30.0)
	move_and_slide()
	_update_rope()
	if _state_t > 0.15 and (grapple_pressed or _jump_buffer > 0.0):
		_jump_buffer = 0.0
		velocity.y = maxf(velocity.y, 0.0) + 9.0
		_can_double = true
		_jumping = false
		facing = Vector3(velocity.x, 0, velocity.z).normalized() if horizontal_speed() > 1.0 else facing
		set_state(State.AIR)
		return
	if is_on_floor():
		_land(0.0)


func _update_rope() -> void:
	var hand: Vector3 = (anim.joints["hand_r"] as Node3D).global_position
	var span := _anchor - hand
	var len := span.length()
	if len < 0.01:
		return
	var up := span / len
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_rope.global_transform = Transform3D(Basis(side, up * len, side.cross(up)), hand + span * 0.5)


# ------------------------------------------------------------------ visuals

func _update_visual(delta: float) -> void:
	var h := Vector3(velocity.x, 0, velocity.z)
	match state:
		State.GROUND, State.AIR, State.GLIDE, State.GRAPPLE_PULL, State.GRAPPLE_SWING:
			if h.length() > 0.8:
				facing = facing.slerp(h.normalized(), 1.0 - exp(-14.0 * delta)).normalized()
		State.LEDGE, State.CLIMB_UP:
			facing = -_ledge_normal
		State.CLIMB:
			facing = -_wall_normal
	_yaw = lerp_angle(_yaw, atan2(-facing.x, -facing.z), 1.0 - exp(-18.0 * delta))

	var pitch := 0.0
	match state:
		State.GLIDE: pitch = -55.0
		State.DASH: pitch = 0.0 if _dash_ground else -62.0
		State.GRAPPLE_PULL: pitch = -35.0
		State.GRAPPLE_SWING:
			var rope := (_anchor - global_position).normalized()
			pitch = rad_to_deg(asin(clampf(-rope.dot(facing), -1.0, 1.0))) * 0.8
	_pitch = lerpf(_pitch, pitch, 1.0 - exp(-12.0 * delta))
	var flip := 0.0
	if _flip_t < _flip_len:
		flip = -360.0 * ease(_flip_t / _flip_len, -1.8)
	visual.rotation = Vector3(deg_to_rad(_pitch + flip), _yaw, 0)
	_jet.emitting = state == State.GLIDE or state == State.GRAPPLE_PULL or _rocket_t < 0.35 \
		or (state == State.DASH and not _dash_ground)

	match state:
		State.GROUND:
			var spd := h.length() / RUN_SPEED
			if spd > 0.08:
				var step := floori(_run_phase / PI)
				_run_phase += h.length() * delta * TAU / STRIDE
				if floori(_run_phase / PI) != step:
					Game.sfx("step", -16.0, 0.15)
				anim.set_base(Poses.run(_run_phase, clampf(spd, 0.0, 1.0)), 20.0)
			else:
				anim.set_base(Poses.breathe(_time), 10.0)
		State.AIR:
			anim.set_base(Poses.JUMP_UP if velocity.y > 3.0 else Poses.FALL, 9.0)
		State.GLIDE:
			anim.set_base(Poses.GLIDE, 10.0)
		State.DASH:
			anim.set_base(Poses.TUCK if _dash_ground else Poses.DASH, 25.0)
		State.LEDGE:
			anim.set_base(Poses.LEDGE_HANG, 14.0)
		State.CLIMB_UP:
			anim.set_base(Poses.CLIMB_UP, 14.0)
		State.CLIMB:
			anim.set_base(Poses.climb(_climb_phase), 18.0)
		State.GRAPPLE_PULL:
			anim.set_base(Poses.GRAPPLE, 14.0)
		State.GRAPPLE_SWING:
			anim.set_base(Poses.SWING, 12.0)
		State.ACTION:
			anim.set_base(Poses.breathe(_time) if is_on_floor() else Poses.FALL, 10.0)
