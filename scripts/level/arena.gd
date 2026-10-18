class_name Arena
extends Area3D
## A God-of-War fight ring. Walking in raises toy-block barriers and drops the
## first wave in from above; each cleared wave brings the next; the last one
## lowers the barriers. If the player dies inside, the arena resets.
##
## waves: Array of {"count": int, "shielded": int, "health": float}

signal started
signal cleared

const DROP_HEIGHT := 7.0
const BARRIER_HEIGHT := 6.0

var size := Vector3(14, 6, 14)
var waves: Array = []
var barriers: Array[Transform3D] = []  # each: basis scaled to the block size, origin at its base centre
var barrier_color := Color(0.25, 0.55, 0.95)

var active := false
var done := false
var wave := -1
var _alive := 0
var _blocks: Array[StaticBody3D] = []
var _spawned: Array[Enemy] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y / 2.0, 0)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	for xf in barriers:
		_blocks.append(_make_block(xf))


func _make_block(xf: Transform3D) -> StaticBody3D:
	var sz := xf.basis.get_scale()
	var body := StaticBody3D.new()
	body.collision_layer = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	shape.shape = bs
	shape.position = Vector3(0, sz.y / 2.0, 0)
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mesh.mesh = bm
	mesh.position = shape.position
	var mat := StandardMaterial3D.new()
	mat.albedo_color = barrier_color
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = barrier_color
	mat.emission_energy_multiplier = 0.25
	mesh.material_override = mat
	body.add_child(mesh)
	body.transform = Transform3D(xf.basis.orthonormalized(), xf.origin - Vector3.UP * (sz.y + 0.5))
	body.set_meta("up", xf.origin)
	body.visible = false
	add_child(body)
	return body


func _on_body_entered(body: Node3D) -> void:
	if active or done or not body.is_in_group("player"):
		return
	start()


func start() -> void:
	active = true
	wave = -1
	Game.sfx("barrier")
	Game.shake(0.25)
	for b in _blocks:
		b.visible = true
		b.collision_layer = 1
		b.create_tween().tween_property(b, "position", b.get_meta("up"), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and not p.combat.died.is_connected(_on_player_died):
		p.combat.died.connect(_on_player_died)
	started.emit()
	_next_wave()


func _next_wave() -> void:
	wave += 1
	if wave >= waves.size():
		_finish()
		return
	var w: Dictionary = waves[wave]
	var kinds: Array = w.get("enemies", [])
	if kinds.is_empty():
		for i in int(w.get("count", 3)):
			kinds.append(w.get("kind", "knight"))
	var count := kinds.size()
	var shielded: int = w.get("shielded", 0)
	_alive = count
	for i in count:
		var e := Enemy.new()
		e.kind = kinds[i]
		e.shielded = i < shielded
		e.max_health = w.get("health", 0.0)
		var a := TAU * (i + 0.5) / count + randf_range(-0.3, 0.3)
		var r := minf(size.x, size.z) * 0.33
		e.position = Vector3.UP * DROP_HEIGHT if e.kind == "king" else Vector3(cos(a) * r, DROP_HEIGHT, sin(a) * r)
		add_child(e)
		e.activate()
		e.died.connect(_on_enemy_died)
		_spawned.append(e)


func _on_enemy_died(_e: Enemy) -> void:
	_alive -= 1
	if _alive <= 0 and active:
		get_tree().create_timer(1.2, false).timeout.connect(_next_wave)


func _finish() -> void:
	active = false
	done = true
	_lower()
	cleared.emit()


func _lower() -> void:
	Game.sfx("barrier", -4.0)
	for b in _blocks:
		b.collision_layer = 0
		var tw := b.create_tween()
		tw.tween_property(b, "position", b.get_meta("up") - Vector3.UP * (BARRIER_HEIGHT + 1.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_callback(b.hide)


func _on_player_died() -> void:
	if not active:
		return
	active = false
	for e in _spawned:
		if is_instance_valid(e):
			e.queue_free()
	_spawned.clear()
	_lower()
