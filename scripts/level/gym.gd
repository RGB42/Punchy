extends Node3D
## Movement gym: one of every traversal challenge, at figure scale.
## Positions here are what scripts/tests/test_movement.gd measures against.

const PLAYER := preload("res://scenes/player.tscn")

const LEDGE_WALL := {"pos": Vector3(0, 2.2, -15), "size": Vector3(10, 4.4, 3)}
const TALL_BLOCK := {"pos": Vector3(-8, 3, -8), "size": Vector3(4, 6, 4)}
const CLIMB_WALL := {"pos": Vector3(15, 6, -10), "size": Vector3(6, 12, 1)}
const TOWER := {"pos": Vector3(-20, 6, -20), "size": Vector3(5, 12, 5)}
const PULL_POINT := Vector3(-20, 12.8, -17.2)
const SWING_A := {"pos": Vector3(30, 4, 0), "size": Vector3(6, 8, 6)}
const SWING_B := {"pos": Vector3(30, 4, -26), "size": Vector3(6, 8, 6)}
const SWING_POINT := Vector3(30, 19, -13)
const SPAWN := Vector3(0, 0.1, 6)


func _ready() -> void:
	_environment()
	_box(Vector3(0, -0.5, 0), Vector3(90, 1, 90), Color(0.55, 0.42, 0.32))
	_box(Vector3(6, 1, -6), Vector3(4, 2, 4), Color(0.3, 0.55, 0.85))
	_box(LEDGE_WALL.pos, LEDGE_WALL.size, Color(0.85, 0.8, 0.7))
	_box(TALL_BLOCK.pos, TALL_BLOCK.size, Color(0.9, 0.35, 0.3))
	_box(CLIMB_WALL.pos, CLIMB_WALL.size, Color(0.35, 0.65, 0.35), true)
	_box(TOWER.pos, TOWER.size, Color(0.8, 0.75, 0.6))
	_box(SWING_A.pos, SWING_A.size, Color(0.6, 0.5, 0.8))
	_box(SWING_B.pos, SWING_B.size, Color(0.6, 0.5, 0.8))
	_box(Vector3(30, 9, 6), Vector3(4, 2, 4), Color(0.6, 0.5, 0.8))  # step up to A
	_point(PULL_POINT, GrapplePoint.Mode.PULL)
	_point(SWING_POINT, GrapplePoint.Mode.SWING)

	var player := PLAYER.instantiate()
	player.position = SPAWN
	add_child(player)
	var cam := PlayerCamera.new()
	cam.name = "Camera"
	cam.target_path = player.get_path()
	add_child(cam)
	add_child(Hud.new(player))
	if spawn_enemies:
		_spawn_wave()


## Practice ring behind the spawn: a fresh wave whenever the last one falls.
@export var spawn_enemies := true
const FIGHT_CENTER := Vector3(0, 0, 24)


func _spawn_wave() -> void:
	var alive := [0]
	for i in 4:
		var e := Enemy.new()
		e.shielded = i == 3
		var a := TAU * i / 4.0
		e.position = FIGHT_CENTER + Vector3(cos(a), 0, sin(a)) * 5.0
		add_child(e)
		alive[0] += 1
		e.died.connect(func(_e: Enemy) -> void:
			alive[0] -= 1
			if alive[0] == 0:
				get_tree().create_timer(2.5, false).timeout.connect(_spawn_wave))


func _box(pos: Vector3, size: Vector3, color: Color, climbable := false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1 | (8 if climbable else 0)
	body.position = pos
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if climbable:
		mat.albedo_texture = _stripes()
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	return body


func _stripes() -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var on := ((x + y) / 8) % 2 == 0
			img.set_pixel(x, y, Color(1, 1, 1) if on else Color(0.75, 0.85, 0.7))
	return ImageTexture.create_from_image(img)


func _point(pos: Vector3, mode: GrapplePoint.Mode) -> void:
	var g := GrapplePoint.new()
	g.mode = mode
	g.position = pos
	add_child(g)


func _environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
