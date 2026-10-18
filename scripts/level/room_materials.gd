class_name RoomMaterials
## Godot-side looks for the material roles the Blender room script names.
## Textures are generated once, procedurally; everything maps triplanar in
## world space so detail stays at the right scale on every furniture size
## (the figure is 12x smaller than a person: a 7 cm floor plank is 0.85 units).

static var _cache := {}


static func apply(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src == null:
				continue
			var m := get_material(src.resource_name)
			if m:
				mi.set_surface_override_material(i, m)


static func get_material(role: String) -> Material:
	if _cache.has(role):
		return _cache[role]
	var m := _make(role)
	_cache[role] = m
	return m


static func _make(role: String) -> Material:
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	match role:
		"parquet":
			m.albedo_texture = _parquet()
			m.uv1_scale = Vector3(1.0 / 3.4, 1.0 / 3.4, 1.0 / 22.0)  # 0.85-wide planks, 22 long
			m.roughness = 0.42
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.02, true, 4.0, 1, Vector2(1, 8))
			m.normal_scale = 0.25
		"wood_light", "wood_dark", "wood_white":
			var base: Color = {"wood_light": Color(0.8, 0.6, 0.4), "wood_dark": Color(0.36, 0.22, 0.13), "wood_white": Color(0.93, 0.92, 0.89)}[role]
			m.albedo_color = base
			if role != "wood_white":
				m.albedo_texture = _grain()
				m.uv1_scale = Vector3(0.6, 0.08, 0.6)
			m.roughness = 0.5 if role != "wood_white" else 0.35
		"wall":
			m.albedo_color = Color(0.82, 0.86, 0.9)
			m.albedo_texture = _wallpaper()
			m.uv1_scale = Vector3.ONE / 6.0
			m.roughness = 0.9
		"ceiling", "baseboard", "sill":
			m.albedo_color = Color(0.95, 0.95, 0.93)
			m.roughness = 0.6 if role == "ceiling" else 0.3
		"rug":
			m.albedo_color = Color(0.72, 0.28, 0.24)
			m.albedo_texture = _noise_tex(0.25, false, 1.0, 3, Vector2.ONE, Color(0.75, 0.75, 0.75), Color.WHITE)
			m.normal_enabled = true
			m.normal_texture = _noise_tex(0.3, true, 6.0, 3)
			m.uv1_scale = Vector3.ONE / 1.5
			m.roughness = 1.0
		"fabric_blanket", "fabric_sheet", "fabric_curtain", "fabric_shirt":
			var cols := {"fabric_blanket": Color(0.25, 0.45, 0.78), "fabric_sheet": Color(0.93, 0.93, 0.96),
				"fabric_curtain": Color(0.9, 0.58, 0.3), "fabric_shirt": Color(0.5, 0.66, 0.42)}
			m.albedo_color = cols[role]
			m.normal_enabled = true
			m.normal_texture = _weave()
			m.normal_scale = 0.6
			m.uv1_scale = Vector3.ONE / 0.8
			m.roughness = 0.95
			if role == "fabric_curtain":
				m.backlight_enabled = true
				m.backlight = Color(0.6, 0.35, 0.15)
		"glass":
			m.albedo_color = Color(0.8, 0.9, 1.0, 0.12)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.05
			m.metallic = 0.3
		"sky":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(1.6, 1.7, 1.8)
		"lampshade":
			m.albedo_color = Color(0.97, 0.92, 0.78)
			m.backlight_enabled = true
			m.backlight = Color(0.5, 0.45, 0.3)
			m.roughness = 0.8
		"metal":
			m.albedo_color = Color(0.78, 0.78, 0.8)
			m.metallic = 1.0
			m.roughness = 0.28
		"leaf":
			m.albedo_color = Color(0.18, 0.48, 0.16)
			m.roughness = 0.45
			m.backlight_enabled = true
			m.backlight = Color(0.25, 0.5, 0.1)
		_:
			if role.begins_with("plastic_"):
				var c := {"plastic_red": Color(0.86, 0.12, 0.1), "plastic_blue": Color(0.1, 0.36, 0.88),
					"plastic_yellow": Color(0.97, 0.76, 0.1), "plastic_green": Color(0.14, 0.66, 0.25),
					"plastic_grey": Color(0.58, 0.58, 0.62)}
				m.albedo_color = c.get(role, Color.WHITE)
				m.roughness = 0.22
				m.clearcoat_enabled = true
				m.clearcoat = 0.6
				m.clearcoat_roughness = 0.15
			elif role.begins_with("book_"):
				var c := {"book_a": Color(0.62, 0.14, 0.14), "book_b": Color(0.14, 0.3, 0.56),
					"book_c": Color(0.86, 0.7, 0.3), "book_d": Color(0.2, 0.5, 0.34)}
				m.albedo_color = c.get(role, Color.WHITE)
				m.roughness = 0.65
			else:
				return null  # keep the glTF material (pot, paper, cardboard, rope)
	return m


static func _noise_tex(freq: float, normal: bool, bump := 2.0, octaves := 3, stretch := Vector2.ONE,
		dark := Color.BLACK, light := Color.WHITE) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = int(512 * stretch.x)
	t.height = int(512 / stretch.y) if stretch.y > 1.0 else 512
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var g := Gradient.new()
		g.set_color(0, dark)
		g.set_color(1, light)
		t.color_ramp = g
	return t


static func _grain() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	n.domain_warp_enabled = true
	n.domain_warp_amplitude = 12.0
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.78, 0.78, 0.78), Color(1, 1, 1), Color(0.86, 0.86, 0.86), Color(1, 1, 1)])
	t.color_ramp = g
	return t


static func _parquet() -> ImageTexture:
	const S := 512
	const PLANK := 128  # 4 planks across the texture
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var shade := []
	var offset := []
	for p in S / PLANK:
		offset.append(rng.randi_range(0, S))
		shade.append([rng.randf_range(0.8, 1.08), rng.randf_range(0.8, 1.08)])
	var base := Color(0.66, 0.45, 0.27)
	for y in S:
		for x in S:
			var p := x / PLANK
			var yy: int = (y + offset[p]) % S
			var k: float = shade[p][0]
			var grain := 0.88 + 0.12 * sin((x % PLANK) * 0.35 + n.get_noise_2d(x * 0.3, yy * 4.0) * 6.0)
			var c := base * k * grain
			if x % PLANK < 2 or yy < 3:
				c = c * 0.55  # the seam
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _wallpaper() -> ImageTexture:
	# pale blue with small cream stars: a kids' room
	const S := 256
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	img.fill(Color(0.83, 0.88, 0.94))
	var star := Color(0.98, 0.94, 0.8)
	for c in [Vector2(64, 64), Vector2(192, 192), Vector2(192, 60), Vector2(70, 190)]:
		var r := 9.0 if int(c.x) % 128 == 64 else 6.0
		for y in range(int(c.y - r), int(c.y + r) + 1):
			for x in range(int(c.x - r), int(c.x + r) + 1):
				var d: Vector2 = Vector2(x, y) - c
				var a := atan2(d.y, d.x)
				var lim := r * (0.55 + 0.45 * absf(cos(a * 2.5)))
				if d.length() <= lim:
					img.set_pixel(x, y, star)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _weave() -> ImageTexture:
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGB8)
	for y in S:
		for x in S:
			var u := sin(x * TAU / 8.0)
			var v := sin(y * TAU / 8.0)
			var over := ((x / 4 + y / 4) % 2) == 0
			var nx := 0.5 + 0.35 * (u if over else 0.0)
			var ny := 0.5 + 0.35 * (0.0 if over else v)
			img.set_pixel(x, y, Color(nx, ny, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
