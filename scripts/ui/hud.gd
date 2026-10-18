class_name Hud
extends CanvasLayer
## Health, fire energy, the combo counter, and a marker on the grapple target.

var player: Player
var _health: ProgressBar
var _energy: ProgressBar
var _combo: Label
var _combo_word: Label
var _marker: Control


func _init(p: Player) -> void:
	player = p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.position = Vector2(36, 30)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_health = _bar(Color(0.95, 0.2, 0.15), 340, 22)
	_energy = _bar(Color(1.0, 0.6, 0.1), 260, 14)
	box.add_child(_health)
	box.add_child(_energy)

	_combo = Label.new()
	_combo.add_theme_font_size_override("font_size", 84)
	_combo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_combo.add_theme_color_override("font_outline_color", Color(0.45, 0.08, 0.02))
	_combo.add_theme_constant_override("outline_size", 18)
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_combo.position = Vector2(-300, -120)
	_combo.size = Vector2(260, 100)
	_combo.pivot_offset = Vector2(200, 50)
	add_child(_combo)
	_combo_word = Label.new()
	_combo_word.text = "TREFFER"
	_combo_word.add_theme_font_size_override("font_size", 26)
	_combo_word.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.0))
	_combo_word.add_theme_constant_override("outline_size", 10)
	_combo_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_word.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_combo_word.position = Vector2(-420, -24)
	_combo_word.size = Vector2(380, 40)
	add_child(_combo_word)
	_on_combo(0)

	_marker = Control.new()
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.draw.connect(_draw_marker)
	add_child(_marker)

	var c := player.combat
	c.health_changed.connect(_set_bar.bind(_health))
	c.energy_changed.connect(_set_bar.bind(_energy))
	c.combo_changed.connect(_on_combo)
	_health.max_value = c.MAX_HEALTH
	_health.value = c.health
	_energy.max_value = c.MAX_ENERGY
	_energy.value = c.energy


func _bar(col: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(w, h)
	b.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(int(h / 2))
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.25)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(int(h / 2))
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func set_stars(n: int, total: int) -> void:
	if _stars == null:
		_stars = _label("", 30, Color(1.0, 0.85, 0.3))
		_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_stars.position = Vector2(-260, 24)
		_stars.size = Vector2(220, 44)
		add_child(_stars)
	_stars.text = "★ %d / %d" % [n, total]
	if n > 0:
		_stars.scale = Vector2.ONE * 1.3
		_stars.pivot_offset = Vector2(180, 22)
		_stars.create_tween().tween_property(_stars, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


var _stars: Label


## Esc / Start: pause with a small menu. Works while the tree is paused.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	var tree := get_tree()
	if _pause:
		_pause.queue_free()
		_pause = null
		tree.paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pause = Control.new()
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-330, -300)
	box.size = Vector2(660, 600)
	box.add_theme_constant_override("separation", 14)
	_pause.add_child(box)
	box.add_child(_label("PAUSE", 72, Color(1.0, 0.82, 0.3)))
	for item in [["Weiter", _toggle_pause], ["Level neu starten", _restart], ["Figur wechseln", _change_hero],
			["Beenden", tree.quit]]:
		var b := Button.new()
		b.text = item[0]
		b.add_theme_font_size_override("font_size", 30)
		b.custom_minimum_size = Vector2(0, 56)
		b.pressed.connect(item[1])
		box.add_child(b)
	var help := _label(CONTROLS, 20, Color(0.92, 0.92, 0.92))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(help)
	add_child(_pause)
	(box.get_child(1) as Button).grab_focus()


const CONTROLS := """WASD / Stick: Laufen      Maus / rechter Stick: Kamera
Leertaste / A: Springen, in der Luft Doppelsprung, halten: Gleiten
Shift / B: Ausweichrolle, in der Luft Dash
E / Mittelklick / LT: Greifhaken (gelb: heranziehen, blau: schwingen)
Linksklick / X: Angriff (Kombo)      Rechtsklick / Y: Konter bei gelbem !
F / RB: Schwerer Angriff, in der Luft Bodenstampfer, ab 8er-Kombo Finisher
Q / LB: Elementkraft am Boden (Energie) / Luftkraft in der Luft
Rotes !! kann man nicht kontern: ausweichen oder springen!"""

var _pause: Control


func _change_hero() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/hero_select.tscn")


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## A line of text at the bottom centre that fades out.
func toast(text: String, secs := 2.5) -> void:
	var l := _label(text, 30, Color(1, 0.97, 0.9))
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.position = Vector2(-700, -150)
	l.size = Vector2(1400, 60)
	for old in get_tree().get_nodes_in_group("hud_toast"):
		old.queue_free()
	l.add_to_group("hud_toast")
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


## Big title in the middle of the screen. secs <= 0 keeps it up.
func banner(title: String, sub: String, secs := 0.0) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-700, -110)
	box.size = Vector2(1400, 220)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_label(title, 96, Color(1.0, 0.82, 0.3)))
	box.add_child(_label(sub, 36, Color(1, 1, 1)))
	box.modulate.a = 0.0
	add_child(box)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.5)
	if secs > 0.0:
		tw.tween_interval(secs)
		tw.tween_property(box, "modulate:a", 0.0, 0.8)
		tw.tween_callback(box.queue_free)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.0))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	return l


func _set_bar(value: float, max_value: float, bar: ProgressBar) -> void:
	bar.max_value = max_value
	bar.value = value


func _on_combo(n: int) -> void:
	var show := n >= 2
	_combo.visible = show
	_combo_word.visible = show
	if not show:
		return
	_combo.text = "%d" % n
	_combo.scale = Vector2.ONE * 1.45
	_combo.create_tween().tween_property(_combo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	_marker.queue_redraw()
	var ready := player.combat.finisher_ready()
	_combo_word.text = "FINISHER BEREIT  [F]" if ready else "TREFFER"
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
	_combo_word.modulate = Color(1.0, 0.55 + 0.3 * glow, 0.2) if ready else Color.WHITE
	var b := get_tree().get_first_node_in_group("boss") as Enemy
	if b and b.state != Enemy.State.IDLE:
		if _boss == null:
			_boss = VBoxContainer.new()
			_boss.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_boss.position = Vector2(-400, 28)
			_boss.size = Vector2(800, 60)
			_boss.add_child(_label(Enemy.KINDS[b.kind].get("title", "ENDGEGNER"), 30, Color(1.0, 0.8, 0.35)))
			_boss_bar = _bar(Color(0.85, 0.15, 0.1), 800, 20)
			_boss.add_child(_boss_bar)
			add_child(_boss)
		_boss_bar.max_value = b.max_health
		_boss_bar.value = b.health
	elif _boss:
		_boss.queue_free()
		_boss = null


var _boss: VBoxContainer
var _boss_bar: ProgressBar


func _draw_marker() -> void:
	var g := player.grapple_target
	var cam := get_viewport().get_camera_3d()
	if cam and player.element == "venom" and player._can_rocket and not player.is_on_floor():
		var hit := player.vine_aim()
		if not hit.is_empty() and not cam.is_position_behind(hit.position):
			var at := cam.unproject_position(hit.position)
			_marker.draw_arc(at, 12.0, 0, TAU, 24, Color(0.5, 1.0, 0.3), 3.0, true)
			_marker.draw_circle(at, 3.0, Color(0.5, 1.0, 0.3))
	if g == null or cam == null or cam.is_position_behind(g.global_position):
		return
	var at := cam.unproject_position(g.global_position)
	var col := Color(1.0, 0.8, 0.3) if g.mode == GrapplePoint.Mode.PULL else Color(0.4, 0.9, 1.0)
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.012)
	_marker.draw_arc(at, 26.0 * pulse, 0, TAU, 40, col, 4.0, true)
	_marker.draw_arc(at, 8.0, 0, TAU, 20, col, 3.0, true)
