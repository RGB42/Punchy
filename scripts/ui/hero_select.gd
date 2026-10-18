extends Node3D
## Pick your action figure: seven pedestals on a shelf board, the chosen one
## turning in a spotlight of its element colour. Locked figures stand as dark
## silhouettes until they are built.

const SPACING := 2.6

var index := 0
var _figures: Array[Node3D] = []
var _anims: Array[FigureAnimator] = []
var _spot: SpotLight3D
var _cam: Camera3D
var _name: Label
var _element: Label
var _power: Label
var _air: Label
var _level: Label
var _time := 0.0
var _leaving := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.start_music()
	_stage()
	for i in Heroes.ALL.size():
		_pedestal(i)
	_ui()
	index = maxi(0, Heroes.ALL.find(Heroes.by_id(Game.hero)))
	_select(index, true)
	_set_level(Game.level)


func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.42, 0.5)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(SPACING * 16, 0.4, 5)
	board.mesh = bm
	board.material_override = RoomMaterials.get_material("wood_light")
	board.position = Vector3(0, -0.2, 0)
	add_child(board)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(SPACING * 16, 10, 0.2)
	wall.mesh = wm
	wall.material_override = RoomMaterials.get_material("wall")
	wall.position = Vector3(0, 3.8, -2.4)
	add_child(wall)
	var key := DirectionalLight3D.new()
	key.light_energy = 0.5
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(Vector3(4, 8, 6), Vector3.ZERO)
	_spot = SpotLight3D.new()
	_spot.spot_range = 12.0
	_spot.spot_angle = 22.0
	_spot.light_energy = 18.0
	_spot.shadow_enabled = true
	add_child(_spot)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	add_child(_cam)
	_cam.make_current()


func _pedestal(i: int) -> void:
	var h: Dictionary = Heroes.ALL[i]
	var x := (i - (Heroes.ALL.size() - 1) / 2.0) * SPACING
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.85
	cyl.height = 0.3
	base.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14)
	mat.emission_enabled = true
	mat.emission = h["color"]
	mat.emission_energy_multiplier = 0.25
	mat.roughness = 0.3
	base.material_override = mat
	base.position = Vector3(x, 0.15, 0)
	add_child(base)
	var locked: bool = h.get("locked", false)
	var model: String = h.get("model", Heroes.ALL[0]["model"])
	var fig: Node3D = (load(model) as PackedScene).instantiate()
	var holder := Node3D.new()
	holder.position = Vector3(x, 0.3, 0)
	holder.rotation.y = PI  # face the camera (+Z)
	add_child(holder)
	holder.add_child(fig)
	var anim := FigureAnimator.new(fig)
	anim.snap_base(Poses.IDLE)
	if locked:
		var shadow := StandardMaterial3D.new()
		shadow.albedo_color = Color(0.02, 0.02, 0.03)
		shadow.roughness = 1.0
		for m in fig.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).material_override = shadow
		var q := Label3D.new()
		q.text = "?"
		q.font_size = 200
		q.outline_size = 30
		q.modulate = h["color"]
		q.position = Vector3(x, 2.15, 0.3)
		add_child(q)
	_figures.append(holder)
	_anims.append(anim)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := _label("WÄHLE DEINE ACTIONFIGUR", 54, Color(1.0, 0.85, 0.35))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-700, 30)
	title.size = Vector2(1400, 70)
	layer.add_child(title)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.position = Vector2(-700, -270)
	box.size = Vector2(1400, 240)
	layer.add_child(box)
	_name = _label("", 72, Color.WHITE)
	_element = _label("", 30, Color(0.9, 0.9, 0.9))
	_power = _label("", 26, Color(1, 1, 1))
	_air = _label("", 26, Color(1, 1, 1))
	_level = _label("", 28, Color(1.0, 0.85, 0.35))
	var hint := _label("◀ ▶  Figur      ▲ ▼  Level      Leertaste / Enter / A  spielen", 22, Color(0.7, 0.7, 0.75))
	for l in [_name, _element, _power, _air, _level, hint]:
		box.add_child(l)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	return l


func _select(i: int, instant := false) -> void:
	index = wrapi(i, 0, Heroes.ALL.size())
	var h: Dictionary = Heroes.ALL[index]
	var locked: bool = h.get("locked", false)
	_name.text = h["name"]
	_name.add_theme_color_override("font_color", h["color"])
	_element.text = "Element: %s" % h["element"]
	_power.text = "Bald verfügbar" if locked else "Kraft am Boden (Q):  " + h["power"]
	_air.text = "" if locked else "Kraft in der Luft (Q):  " + h["air"]
	_spot.light_color = h["color"]
	var x := _figures[index].position.x
	_spot.look_at_from_position(Vector3(x, 7.5, 2.0), Vector3(x, 0.8, 0))
	if not instant:
		Game.sfx("swing", -10.0)
		_anims[index].play([{"pose": Poses.JUMP_UP, "time": 0.12, "ease": 0.4}, {"pose": Poses.LAND, "time": 0.15}], 0.3)
	if instant:
		_cam.position = _cam_goal()


func _set_level(i: int) -> void:
	Game.level = wrapi(i, 0, Game.LEVELS.size())
	_level.text = "Level %d:  %s" % [Game.level + 1, Game.LEVELS[Game.level]["name"]]


func _cam_goal() -> Vector3:
	return Vector3(_figures[index].position.x * 0.9, 1.7, 4.8)


func _process(delta: float) -> void:
	_time += delta
	_cam.position = _cam.position.lerp(_cam_goal(), 1.0 - exp(-6.0 * delta))
	_cam.look_at(Vector3(_figures[index].position.x, 0.75, 0))
	for i in _figures.size():
		var sel := i == index
		var target_yaw := PI + (sin(_time * 0.8) * 0.6 if sel else 0.0)
		_figures[i].rotation.y = lerp_angle(_figures[i].rotation.y, target_yaw, 1.0 - exp(-4.0 * delta))
		var s := 1.12 if sel else 0.92
		_figures[i].scale = _figures[i].scale.lerp(Vector3.ONE * s, 1.0 - exp(-8.0 * delta))
		_anims[i].set_base(Poses.breathe(_time + i) if sel else Poses.IDLE, 8.0)
		_anims[i].update(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		_select(index - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		_select(index + 1)
	elif event.is_action_pressed("move_forward") or event.is_action_pressed("ui_up"):
		_set_level(Game.level - 1)
	elif event.is_action_pressed("move_back") or event.is_action_pressed("ui_down"):
		_set_level(Game.level + 1)
	elif event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		choose()


func choose() -> void:
	var h: Dictionary = Heroes.ALL[index]
	if h.get("locked", false):
		Game.sfx("block", -6.0)
		return
	_leaving = true
	Game.hero = h["id"]
	Game.sfx("counter")
	_anims[index].play([{"pose": Poses.TUCK, "time": 0.1, "ease": 0.4}, {"pose": Poses.ROCKET, "time": 0.3}], 0.3)
	var tw := create_tween()
	tw.tween_property(_figures[index], "position:y", 3.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(Game.LEVELS[Game.level]["scene"]))
