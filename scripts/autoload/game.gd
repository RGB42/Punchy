extends Node
## Global game feel: input map, hitstop, slow motion, camera trauma.
## Time effects run on real time so they end even while the world is frozen.

const HITSTOP_SCALE := 0.03
const HITSTOP_MAX := 0.15

## The rooms of the house, in play order.
const LEVELS := [
	{"name": "Das Kinderzimmer", "scene": "res://scenes/kids_room.tscn"},
	{"name": "Die Küche", "scene": "res://scenes/kitchen.tscn"},
]

var hero := "blaze"  # id from Heroes.ALL, chosen on the select screen
var level := 0  # index into LEVELS
var trauma := 0.0  # 0..1, read and decayed by the camera
var fov_kick := 0.0  # degrees, read and decayed by the camera
var _hitstop_until := 0
var _slowmo_until := 0
var _slowmo_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_make_players()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			hero = a.trim_prefix("--hero=")
		elif a.begins_with("--level="):
			level = a.trim_prefix("--level=").to_int()
	_dev_screenshot()


## Dev aid: `godot --path . -- --shot=out.png --shot-delay=3` saves one frame and quits.
func _dev_screenshot() -> void:
	var path := ""
	var delay := 3.0
	var cam_spec := ""  # --cam=x,y,z,tx,ty,tz : free camera for overview shots
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-delay="):
			delay = a.trim_prefix("--shot-delay=").to_float()
		elif a.begins_with("--cam="):
			cam_spec = a.trim_prefix("--cam=")
	if "--fps" in OS.get_cmdline_user_args():
		for i in 8:
			await get_tree().create_timer(1.0, true, false, true).timeout
			print("FPS ", Engine.get_frames_per_second())
	if path == "":
		return
	await get_tree().create_timer(delay, true, false, true).timeout
	if cam_spec != "":
		var v := cam_spec.split_floats(",")
		var c := Camera3D.new()
		c.fov = 75.0
		get_tree().current_scene.add_child(c)
		c.look_at_from_position(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]))
		c.make_current()
		await get_tree().create_timer(0.3, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var scale := 1.0
	if now < _slowmo_until:
		scale = _slowmo_scale
	if now < _hitstop_until:
		scale = min(scale, HITSTOP_SCALE)
	Engine.time_scale = scale
	var real_delta := (now - _last_ticks) / 1000.0 if _last_ticks > 0 else 0.0
	_last_ticks = now
	_update_music(real_delta)


## Freeze the world briefly. Overlapping calls take the longest, never the sum.
func hitstop(sec: float) -> void:
	var until := Time.get_ticks_msec() + int(min(sec, HITSTOP_MAX) * 1000.0)
	_hitstop_until = max(_hitstop_until, until)


func slowmo(scale: float, sec: float) -> void:
	_slowmo_scale = scale
	_slowmo_until = Time.get_ticks_msec() + int(sec * 1000.0)


## Punch the camera in (narrower FOV) for a beat.
func kick(degrees: float) -> void:
	fov_kick = maxf(fov_kick, degrees)


func shake(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)


## Plays assets/sfx/<name>.wav, or a random one of <name>_0, <name>_1, ...
## Audio runs on real time, so impacts ring out through the hitstop.
func sfx(name: String, volume_db := 0.0, pitch_var := 0.08) -> void:
	if not _sounds.has(name):
		var list: Array[AudioStream] = []
		var single := "res://assets/sfx/%s.wav" % name
		if ResourceLoader.exists(single):
			list.append(load(single))
		var i := 0
		while ResourceLoader.exists("res://assets/sfx/%s_%d.wav" % [name, i]):
			list.append(load("res://assets/sfx/%s_%d.wav" % [name, i]))
			i += 1
		_sounds[name] = list
	var list: Array = _sounds[name]
	if list.is_empty():
		return
	var pl := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	pl.stream = list.pick_random()
	pl.volume_db = volume_db
	pl.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	pl.play()


## Two synced loops (tools/gen_music.py): the combat layer fades in while an
## arena is active, the explore layer ducks under it.
func start_music() -> void:
	if _explore == null:
		_explore = _music_player("explore")
		_combat = _music_player("combat")
	if not _explore.playing:
		_explore.play()
		_combat.play()
	_combat_mix = 0.0
	_combat_target = 0.0


func set_combat(on: bool) -> void:
	_combat_target = 1.0 if on else 0.0


func _music_player(name: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	var s := load("res://assets/music/%s.wav" % name) as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	pl.stream = s
	add_child(pl)
	return pl


func _update_music(real_delta: float) -> void:
	if _explore == null:
		return
	# fights kick in fast, the calm comes back slowly
	_combat_mix = move_toward(_combat_mix, _combat_target, real_delta * (1.5 if _combat_target > _combat_mix else 0.25))
	_combat.volume_db = linear_to_db(maxf(_combat_mix, 0.0001)) - 3.0
	_explore.volume_db = -4.0 - 5.0 * _combat_mix


var _explore: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _combat_mix := 0.0
var _combat_target := 0.0
var _last_ticks := 0
var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _make_players() -> void:
	for i in 16:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"jump": [KEY_SPACE], "dodge": [KEY_SHIFT], "heavy": [KEY_F], "power": [KEY_Q],
		"grapple": [KEY_E], "pause": [KEY_ESCAPE],
	}
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "counter": MOUSE_BUTTON_RIGHT, "grapple": MOUSE_BUTTON_MIDDLE}
	# Xbox layout: A jump, X attack, Y counter, B dodge, RB heavy, LB power, LT grapple.
	var pad := {
		"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "counter": JOY_BUTTON_Y, "dodge": JOY_BUTTON_B,
		"heavy": JOY_BUTTON_RIGHT_SHOULDER, "power": JOY_BUTTON_LEFT_SHOULDER, "pause": JOY_BUTTON_START,
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"look_left": [JOY_AXIS_RIGHT_X, -1.0], "look_right": [JOY_AXIS_RIGHT_X, 1.0],
		"look_up": [JOY_AXIS_RIGHT_Y, -1.0], "look_down": [JOY_AXIS_RIGHT_Y, 1.0],
		"grapple": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	var actions := {}
	for d in [keys, mouse, pad, axes]:
		for a in d:
			actions[a] = true
	for a in actions:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
	for a in keys:
		for k in keys[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	for a in mouse:
		var e := InputEventMouseButton.new()
		e.button_index = mouse[a]
		InputMap.action_add_event(a, e)
	for a in pad:
		var e := InputEventJoypadButton.new()
		e.button_index = pad[a]
		InputMap.action_add_event(a, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = axes[a][0]
		e.axis_value = axes[a][1]
		InputMap.action_add_event(a, e)
