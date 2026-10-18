extends Node3D
## Level 1, the kids' room. Loads kids_room.glb and turns its markers into
## gameplay (see the contract at the top of tools/blender/build_room.py):
## grapple points, arenas with their waves, checkpoints, the goal window, the
## intro fly-through, light, and on-screen hints.

const ROOM := preload("res://assets/models/rooms/kids_room.glb")
const PLAYER := preload("res://scenes/player.tscn")

## Waves per arena, by marker name. The goal opens when the last one is cleared.
const ARENAS := {
	"arena_1": [
		{"enemies": ["knight", "knight", "doll"]},
		{"enemies": ["knight", "knight", "doll", "doll"], "shielded": 1},
	],
	"arena_2": [
		{"enemies": ["doll", "doll", "doll", "knight"]},
		{"enemies": ["knight", "knight", "soldier", "soldier"], "shielded": 1},
		{"enemies": ["knight", "knight", "doll", "doll", "soldier"], "shielded": 2},
	],
	"arena_3": [
		{"enemies": ["soldier", "soldier", "knight"]},
		{"enemies": ["doll", "doll", "knight", "soldier"], "shielded": 1},
	],
	"arena_4": [
		{"enemies": ["knight", "knight", "doll", "soldier"], "shielded": 1},
		{"enemies": ["king"]},
	],
}
const FINAL_ARENA := "arena_4"

## [position, radius, text]: shown once when the player first gets close.
const HINTS := [
	[Vector3(17.4, 1.9, 22.4), 6.0, "Leertaste: Springen  -  in der Luft nochmal: Doppelsprung (Salto)"],
	[Vector3(8, 0, 10), 7.0, "Linke Maus: Angriff  -  Rechte Maus bei !: Konter  -  F: Schwerer Angriff (bricht Schilde)"],
	[Vector3(-12, 0, 17), 5.0, "Gegen Leiter & Vorhang laufen: Klettern  -  oben: Hochziehen"],
	[Vector3(-19, 20.7, 0), 6.0, "E / Mittelklick auf blauen Ring: Schwingen  -  Springen: Loslassen"],
	[Vector3(-12, 21.6, -23), 6.0, "Shift in der Luft: Feuer-Dash  -  Q in der Luft: Raketen-Schub  -  Sprung halten: Gleiten"],
	[Vector3(21, 9, -9.5), 6.0, "Q am Boden mit voller Energie: Flammenstoss  -  F in der Luft: Bodenstampfer"],
]

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


func _ready() -> void:
	var room: Node3D = ROOM.instantiate()
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
		elif ARENAS.has(name):
			_arena(name, m)
	hud.set_stars(0, stars_total)
	_make_goal(_markers["goal"])
	Fx.prewarm.call_deferred()  # after the level finished entering the tree
	start_time = Time.get_ticks_msec()
	_intro()


func _pos(marker: String) -> Vector3:
	return (_markers[marker] as Node3D).global_position


func _arena(name: String, m: Node3D) -> void:
	var a := Arena.new()
	a.name = name
	a.size = m.global_basis.get_scale().abs()
	a.waves = ARENAS[name]
	for k in 8:
		var b: Node3D = _markers.get("%s_barrier_%d" % [name, k])
		if b == null:
			break
		a.barriers.append(Transform3D(Basis.from_scale(b.global_basis.get_scale().abs()), b.global_position - m.global_position))
	a.position = m.global_position
	add_child(a)
	if name == FINAL_ARENA:
		a.cleared.connect(_open_goal)


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
	var tw := create_tween()
	tw.tween_property(_sun, "light_energy", 4.0, 2.0)
	hud.toast("Das Fenster ist offen! Spring auf die Fensterbank!", 5.0)
	Game.sfx("barrier")


func _win() -> void:
	if _won:
		return
	_won = true
	var secs := (Time.get_ticks_msec() - start_time) / 1000
	Game.slowmo(0.3, 1.5)
	hud.banner("LEVEL GESCHAFFT", "Zeit: %d:%02d   -   Sterne: %d / %d" % [secs / 60, secs % 60, stars, stars_total])


func _process(_delta: float) -> void:
	if player == null or _intro_cam != null:
		return
	for i in HINTS.size():
		if _hints_shown.has(i):
			continue
		var h: Array = HINTS[i]
		if player.global_position.distance_to(h[0]) < h[1]:
			_hints_shown[i] = true
			hud.toast(h[2], 6.0)


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
	hud.banner("DAS KINDERZIMMER", "Erreiche das Fenster", 4.0)
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


func _end_intro() -> void:
	if _intro_cam == null:
		return
	_intro_cam.queue_free()
	_intro_cam = null
	camera.cam.make_current()
	player.scripted = false
	start_time = Time.get_ticks_msec()


# ------------------------------------------------------------------ light

var _sun: DirectionalLight3D


func _lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(1.0, 0.9, 0.75)
	_sun.light_energy = 2.6
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 120.0
	_sun.light_volumetric_fog_energy = 3.0
	add_child(_sun)
	_sun.look_at_from_position(Vector3(1.8, 40, -60), Vector3(4, 0, 6))

	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.75, 0.82, 1.0)
	fill.light_energy = 0.35
	fill.light_volumetric_fog_energy = 0.0
	add_child(fill)
	fill.look_at_from_position(Vector3(10, 30, 30), Vector3.ZERO)

	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 6.0
	lamp.spot_range = 14.0
	lamp.spot_angle = 50.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.look_at_from_position(Vector3(19.5, 13.4, -18.6), Vector3(19, 9, -15))

	for at in [Vector3(-20, 12, 8), Vector3(8, 14, 10), Vector3(0, 10, -18)]:
		var bounce := OmniLight3D.new()
		bounce.light_color = Color(1.0, 0.88, 0.72)
		bounce.light_energy = 0.6
		bounce.omni_range = 34.0
		bounce.light_volumetric_fog_energy = 0.0
		add_child(bounce)
		bounce.global_position = at

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
	env.volumetric_fog_length = 90.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
