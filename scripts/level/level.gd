class_name Level
extends Node3D
## One room of the house. Loads the room glb a Blender script built and turns
## its markers into gameplay (contract: top of tools/blender/roomkit.py):
## grapple points, arenas with their waves, checkpoints, stars, hazards, the
## goal, the intro fly-through, light and on-screen hints.
##
## A level script extends this and overrides the data functions below.

const PLAYER := preload("res://scenes/player.tscn")
const HAZARD_DAMAGE := {"water": 15.0, "hot": 12.0}  # water: per dunk, hot: per second

var player: Player
var camera: PlayerCamera
var hud: Hud
var start_time := 0
var stars := 0
var stars_total := 0
var _markers := {}
var _goal: Area3D
var _goal_open := false
var _won := false
var _windows: Array[Node3D] = []
var _glass: Array[StaticBody3D] = []
var _hints_shown := {}
var _intro_cam: Camera3D
var _hot_zones: Array[Area3D] = []
var keys := 0
var _gates: Array[StaticBody3D] = []
var _gate_labels: Array[Label3D] = []
var _sun: DirectionalLight3D


# ------------------------------------------------------------------ level data

func room_scene() -> PackedScene:
	return null


## Waves per arena, by marker name.
func arenas() -> Dictionary:
	return {}


## The arena whose last wave opens the goal.
func final_arena() -> String:
	return ""


## [position, radius, text]: shown once when the player first gets close.
func hints() -> Array:
	return []


func title() -> String:
	return ""


func subtitle() -> String:
	return ""


func goal_open_text() -> String:
	return "Das Ziel ist offen!"


## Sun origin and target: it shines in through the window.
func sun_line() -> Array:
	return [Vector3(1.8, 40, -60), Vector3(4, 0, 6)]


## Room-specific lamps on top of the shared light rig.
func extra_lights() -> void:
	pass


func on_goal_open() -> void:
	pass


## Arenas whose victory drops a key; all keys open the gates (gate_<n> markers).
func key_arenas() -> Array:
	return []


func key_look() -> String:
	return "battery"


func key_label() -> String:
	return "Batterien"


func key_color() -> Color:
	return Color(1.0, 0.8, 0.25)


## Shown after the intro: what this room asks of you.
func objective_text() -> String:
	return ""


# ------------------------------------------------------------------ build

func _ready() -> void:
	var room: Node3D = room_scene().instantiate()
	add_child(room)
	RoomMaterials.apply(room)
	for n in room.find_children("*", "", true, false):
		var nm := String(n.name)
		if n is StaticBody3D:
			if "_climb" in nm:
				n.collision_layer = 1 | 8
			if nm.begins_with("window_glass"):
				_glass.append(n)
		elif n is MeshInstance3D:
			if nm == "window_l" or nm == "window_r":
				_windows.append(n)
			if nm == "sky":
				n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # it stands where the sun comes from
		elif n.get_class() == "Node3D" and n.get_child_count() == 0:
			_markers[nm] = n
	_lights()

	# Positions are set before entering the tree: a body added at the origin and
	# moved the same frame can still trigger areas at the origin on the first step.
	player = PLAYER.instantiate()
	player.position = _pos("spawn_player")
	add_child(player)
	player.facing = Vector3.FORWARD
	player.checkpoint = player.global_position
	camera = PlayerCamera.new()
	camera.name = "Camera"
	camera.target_path = player.get_path()
	add_child(camera)
	hud = Hud.new(player)
	add_child(hud)

	var waves := arenas()
	for name in _markers:
		var m: Node3D = _markers[name]
		if name.begins_with("grapple_pull") or name.begins_with("grapple_swing"):
			var g := GrapplePoint.new()
			g.mode = GrapplePoint.Mode.PULL if name.begins_with("grapple_pull") else GrapplePoint.Mode.SWING
			g.position = m.global_position
			add_child(g)
		elif name.begins_with("checkpoint_"):
			_checkpoint(m.global_position)
		elif name.begins_with("star_"):
			var s := Star.new()
			s.position = m.global_position
			add_child(s)
			stars_total += 1
			s.collected.connect(func() -> void:
				stars += 1
				hud.set_stars(stars, stars_total))
		elif name.begins_with("hazard_"):
			_hazard(name, m)
		elif name.begins_with("gate_"):
			_gate(m)
		elif name.begins_with("vista_"):
			_vista(m)
		elif waves.has(name):
			_arena(name, m, waves[name])
	hud.set_stars(0, stars_total)
	if not key_arenas().is_empty():
		hud.set_keys(0, key_arenas().size(), key_label())
	_dust()
	_make_goal(_markers["goal"])
	Fx.prewarm.call_deferred()  # after the level finished entering the tree
	Game.start_music()
	start_time = Time.get_ticks_msec()
	_intro()


func _pos(marker: String) -> Vector3:
	return (_markers[marker] as Node3D).global_position


func _arena(name: String, m: Node3D, waves: Array) -> void:
	var a := Arena.new()
	a.name = name
	a.size = m.global_basis.get_scale().abs()
	a.waves = waves
	for k in 8:
		var b: Node3D = _markers.get("%s_barrier_%d" % [name, k])
		if b == null:
			break
		a.barriers.append(Transform3D(Basis.from_scale(b.global_basis.get_scale().abs()), b.global_position - m.global_position))
	a.position = m.global_position
	add_child(a)
	if name == final_arena():
		a.cleared.connect(_open_goal)
	if name in key_arenas():
		a.cleared.connect(_drop_key.bind(m.global_position + Vector3.UP * 1.6))


func _checkpoint(at: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 4.0
	shape.shape = s
	area.add_child(shape)
	area.position = at
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == player and player.checkpoint.distance_to(at) > 0.5:
			player.checkpoint = at
			hud.toast("Checkpoint"))


## hazard_water_<n>: falling in hurts and puts you back on dry ground.
## hazard_hot_<n>: a hot plate that burns whoever stands on it, enemies too.
## The marker is a box, origin at its base centre, scaled to its size.
func _hazard(name: String, m: Node3D) -> void:
	var area := Area3D.new()
	area.name = name
	area.collision_layer = 0
	area.collision_mask = 2 | 4
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = m.global_basis.get_scale().abs()
	shape.shape = b
	shape.position = Vector3(0, b.size.y / 2.0, 0)
	area.add_child(shape)
	area.position = m.global_position
	add_child(area)
	if name.begins_with("hazard_water"):
		area.body_entered.connect(func(body: Node3D) -> void:
			if body == player:
				Game.sfx("land", 0.0)
				Fx.sparks(player.global_position + Vector3.UP, Vector3.UP, Color(1.2, 1.8, 2.6), 30, 8.0)
				player.take_hit(HAZARD_DAMAGE["water"], player.global_position)
				player.respawn()
			elif body is Enemy:
				(body as Enemy).take_hit({"damage": 999.0, "dir": Vector3.UP}))
	else:
		_hot_zones.append(area)


func _physics_process(delta: float) -> void:
	for zone in _hot_zones:
		for body in zone.get_overlapping_bodies():
			if body == player:
				if player.element != "blaze":  # fire does not burn fire
					player.combat.burn(HAZARD_DAMAGE["hot"] * delta)
			elif body is Enemy and (body as Enemy).is_alive():
				(body as Enemy)._hurt_by_world(HAZARD_DAMAGE["hot"] * 2.0 * delta, Vector3.UP)
				if randf() < delta * 8.0:
					Fx.fire(body.global_position + Vector3.UP * 0.4, Vector3.UP, 30.0, 4.0, 6, 0.5, 0.4)


func _make_goal(m: Node3D) -> void:
	_goal = Area3D.new()
	_goal.collision_layer = 0
	_goal.collision_mask = 2
	_goal.monitoring = false
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = m.global_basis.get_scale().abs()
	shape.shape = b
	shape.position = Vector3(0, b.size.y / 2.0, 0)
	_goal.add_child(shape)
	_goal.position = m.global_position
	add_child(_goal)
	_goal.body_entered.connect(func(body: Node3D) -> void:
		if body == player:
			_win())


func _open_goal() -> void:
	if _goal_open:
		return
	_goal_open = true
	_goal.monitoring = true
	for g in _glass:
		g.collision_layer = 0
	for w in _windows:
		var dir := 1.0 if w.name == "window_l" else -1.0
		w.create_tween().tween_property(w, "rotation:y", deg_to_rad(-100.0 * dir), 1.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(_sun, "light_energy", _sun.light_energy * 1.5, 2.0)
	hud.toast(goal_open_text(), 5.0)
	Game.sfx("barrier")
	on_goal_open()


func _win() -> void:
	if _won:
		return
	_won = true
	var secs := (Time.get_ticks_msec() - start_time) / 1000
	Game.slowmo(0.3, 1.5)
	var nxt := Game.level + 1
	var more := nxt < Game.LEVELS.size()
	hud.banner("LEVEL GESCHAFFT", "Zeit: %d:%02d   -   Sterne: %d / %d%s" % [secs / 60, secs % 60, stars, stars_total,
		"\nSprung-Taste: weiter zu %s" % Game.LEVELS[nxt]["name"] if more else "\nDas Haus ist für heute befreit!"])


func _process(_delta: float) -> void:
	if player == null or _intro_cam != null:
		return
	var h_list := hints()
	for i in h_list.size():
		if _hints_shown.has(i):
			continue
		var h: Array = h_list[i]
		if player.global_position.distance_to(h[0]) < h[1]:
			_hints_shown[i] = true
			hud.toast(h[2], 6.0)


# ------------------------------------------------------------------ keys and gates

func _drop_key(at: Vector3) -> void:
	var k := KeyItem.new()
	k.look = key_look()
	k.color = key_color()
	k.position = at
	add_child(k)
	hud.toast("Eine %s ist erschienen - hol sie dir!" % key_label().trim_suffix("n").trim_suffix("e") if key_look() == "battery" else "Ein Teil ist erschienen - hol es dir!", 4.0)
	k.collected.connect(func() -> void:
		keys += 1
		hud.set_keys(keys, key_arenas().size(), key_label())
		for l in _gate_labels:
			l.text = "%d / %d %s" % [keys, key_arenas().size(), key_label()]
		if keys >= key_arenas().size():
			_unlock_gates())


## A force-field dome (four walls and a roof) that holds the final area shut
## until every key is found. Stops figures, not the camera.
func _gate(m: Node3D) -> void:
	var size := m.global_basis.get_scale().abs()
	var body := StaticBody3D.new()
	body.collision_layer = Arena.BARRIER_LAYER
	body.position = m.global_position
	add_child(body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.25, 0.16)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 0.5
	mat.rim_enabled = true
	mat.rim = 1.0
	var t := 0.5
	var panels := [
		[Vector3(0, size.y / 2.0, -size.z / 2.0), Vector3(size.x, size.y, t)],
		[Vector3(0, size.y / 2.0, size.z / 2.0), Vector3(size.x, size.y, t)],
		[Vector3(-size.x / 2.0, size.y / 2.0, 0), Vector3(t, size.y, size.z)],
		[Vector3(size.x / 2.0, size.y / 2.0, 0), Vector3(t, size.y, size.z)],
		[Vector3(0, size.y, 0), Vector3(size.x, t, size.z)],
	]
	for pnl in panels:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = pnl[1]
		shape.shape = box
		shape.position = pnl[0]
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pnl[1]
		mesh.mesh = bm
		mesh.material_override = mat
		mesh.position = pnl[0]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(mesh)
	var label := Label3D.new()
	label.text = "0 / %d %s" % [key_arenas().size(), key_label()]
	label.font_size = 260
	label.outline_size = 40
	label.modulate = Color(1.0, 0.85, 0.35)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, size.y + 2.5, 0)
	body.add_child(label)
	_gates.append(body)
	_gate_labels.append(label)
	body.set_meta("mat", mat)


func _unlock_gates() -> void:
	hud.toast("Alle %s gefunden! Das Kraftfeld fällt." % key_label(), 5.0)
	Game.sfx("barrier", 4.0)
	Game.shake(0.5)
	for g in _gates:
		g.collision_layer = 0
		if camera:
			camera.cinematic(g.global_position + Vector3.UP * 3.0, (g.global_position - player.global_position).normalized(), 2.4)
		var mat: StandardMaterial3D = g.get_meta("mat")
		var tw := g.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, 1.5)
		tw.parallel().tween_property(mat, "emission_energy_multiplier", 4.0, 0.3)
		tw.tween_callback(g.queue_free)
	_gate_labels.clear()


## vista_<n>: stepping in here pulls the camera far back to show the room.
func _vista(m: Node3D) -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = m.global_basis.get_scale().abs()
	shape.shape = b
	shape.position = Vector3(0, b.size.y / 2.0, 0)
	area.add_child(shape)
	area.position = m.global_position
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == player:
			camera.vista = true)
	area.body_exited.connect(func(body: Node3D) -> void:
		if body == player:
			camera.vista = false)


## Dust drifting in the air of the whole room: in a giant room, the motes are
## what tell your eye how big it is.
func _dust() -> void:
	var bounds := AABB()
	var first := true
	for n in find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.name == "sky":
			continue
		var bb := mi.global_transform * mi.get_aabb()
		bounds = bb if first else bounds.merge(bb)
		first = false
	var p := GPUParticles3D.new()
	p.amount = 700
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = AABB(-bounds.size / 2.0, bounds.size)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = bounds.size / 2.0 * 0.95
	pm.gravity = Vector3(0, -0.05, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.3
	pm.direction = Vector3(1, 0.2, 0.3)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.92, 0.75, 0.55)
	q.material = mat
	p.draw_pass_1 = q
	p.position = bounds.get_center()
	add_child(p)

# ------------------------------------------------------------------ intro

func _intro() -> void:
	var pts: Array[Vector3] = []
	var i := 0
	while _markers.has("cam_intro_%d" % i):
		pts.append(_pos("cam_intro_%d" % i))
		i += 1
	if pts.size() < 2 or DisplayServer.get_name() == "headless" or "--skip-intro" in OS.get_cmdline_user_args():
		return
	var curve := Curve3D.new()
	for k in pts.size():
		var prev: Vector3 = pts[max(k - 1, 0)]
		var nxt: Vector3 = pts[min(k + 1, pts.size() - 1)]
		var tan := (nxt - prev) * 0.25
		curve.add_point(pts[k], -tan, tan)
	_intro_cam = Camera3D.new()
	_intro_cam.fov = 65.0
	add_child(_intro_cam)
	_intro_cam.make_current()
	player.scripted = true
	hud.banner(title(), subtitle(), 4.0)
	var dur := 9.0
	var goal_pos := _pos("goal") + Vector3.UP * 6.0
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := curve.sample_baked(t * curve.get_baked_length(), true)
 		_intro_cam.global_position = p
		var look := goal_pos.lerp(player.global_position + Vector3.UP * 1.2, clampf((t - 0.6) / 0.4, 0.0, 1.0))
		if t < 0.15:
			look = (player.global_position + Vector3.UP).lerp(goal_pos, t / 0.15)
		_intro_cam.look_at(look), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_end_intro)


func _unhandled_input(event: InputEvent) -> void:
	if _intro_cam and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed():
		_end_intro()
	elif _won and event.is_action_pressed("jump") and Game.level + 1 < Game.LEVELS.size():
		Game.level += 1
		get_tree().change_scene_to_file(Game.LEVELS[Game.level]["scene"])


func _end_intro() -> void:
	if _intro_cam == null:
		return
	_intro_cam.queue_free()
	_intro_cam = null
	camera.cam.make_current()
	player.scripted = false
	start_time = Time.get_ticks_msec()
	if objective_text() != "":
		hud.toast(objective_text(), 7.0)


# ------------------------------------------------------------------ light

func _lights() -> void:
	var line := sun_line()
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.9, 0.75)
	_sun.light_energy = 2.6
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 220.0
	_sun.light_volumetric_fog_energy = 3.0
	add_child(_sun)
	_sun.look_at_from_position(line[0], line[1])

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.light_energy = 0.35
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)
	fill.look_at_from_position(Vector3(10, 30, 30), Vector3.ZERO)

	for at in [Vector3(-20, 12, 8), Vector3(8, 14, 10), Vector3(0, 10, -18)]:
		var bounce := OmniLight3D.new()
		bounce.light_color = Color(1.0, 0.88, 0.72)
		bounce.light_energy = 0.6
		bounce.omni_range = 34.0
		bounce.light_volumetric_fog_energy = 0.0
		add_child(bounce)
		bounce.global_position = at
	extra_lights()

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.75, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.82, 0.78)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.85)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 180.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
