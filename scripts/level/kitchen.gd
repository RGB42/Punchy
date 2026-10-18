extends Level
## Level 2: the kitchen. Door to cookie jar. Built by tools/blender/build_kitchen.py.

const ROOM := preload("res://assets/models/rooms/kitchen.glb")

const ARENAS := {
	"arena_1": [
		{"enemies": ["robot", "dino", "dino"]},
		{"enemies": ["robot", "robot", "dino", "dino"]},
	],
	"arena_2": [
		{"enemies": ["dino", "dino", "dino", "robot"]},
		{"enemies": ["robot", "robot", "dino", "dino", "soldier"]},
	],
	"arena_3": [
		{"enemies": ["dino", "dino", "dino"]},
		{"enemies": ["robot", "robot", "dino"]},
	],
	"arena_4": [
		{"enemies": ["dino", "dino"]},
		{"enemies": ["dino", "dino", "doll"]},
	],
	"arena_5": [
		{"enemies": ["robot", "dino", "dino"]},
		{"enemies": ["dragon"]},
	],
}

const HINTS := [
	[Vector3(13, 0.1, 23), 6.0, "Die Keksdose auf dem Tisch! Erst die Arbeitsplatte hoch - die Schubladen sind eine Treppe"],
	[Vector3(17, 0.1, 1), 6.0, "Aufziehroboter: leichte Schläge prallen ab - Schwer (F), Kraft (Q) oder Konter!"],
	[Vector3(-1, 10.9, -22), 5.0, "Nicht ins Spülbecken fallen - der Wasserhahn ist ein Haken"],
	[Vector3(-14, 10.9, -22), 5.0, "Die Herdplatte glüht - wirf Gegner drauf, aber stell dich nicht selbst drauf"],
	[Vector3(23.4, 21.7, -23.0), 5.0, "Von hier: Topfregal und Lampe zum Tisch schwingen"],
]


func room_scene() -> PackedScene:
	return ROOM


func arenas() -> Dictionary:
	return ARENAS


func final_arena() -> String:
	return "arena_5"


func hints() -> Array:
	return HINTS


func title() -> String:
	return "DIE KÜCHE"


func subtitle() -> String:
	return "Erreiche die Keksdose"


func goal_open_text() -> String:
	return "Der Drache ist besiegt - die Keksdose ist offen!"


func sun_line() -> Array:
	return [Vector3(-7, 42, -62), Vector3(-2, 0, 4)]


func extra_lights() -> void:
	var hot := OmniLight3D.new()  # the glowing hot plate
	hot.light_color = Color(1.0, 0.35, 0.1)
	hot.light_energy = 2.0
	hot.omni_range = 5.0
	add_child(hot)
	hot.global_position = Vector3(-17.5, 11.6, -21.6)
	var strip := SpotLight3D.new()  # LEDs under the upper cabinets
	strip.light_color = Color(1.0, 0.92, 0.8)
	strip.light_energy = 3.0
	strip.spot_range = 10.0
	strip.spot_angle = 70.0
	add_child(strip)
	strip.look_at_from_position(Vector3(10, 17.0, -24.5), Vector3(10, 10.8, -22.5))
	var pendant := SpotLight3D.new()  # over the table
	pendant.light_color = Color(1.0, 0.85, 0.6)
	pendant.light_energy = 5.0
	pendant.spot_range = 24.0
	pendant.spot_angle = 45.0
	pendant.shadow_enabled = true
	add_child(pendant)
	pendant.look_at_from_position(Vector3(2, 21.8, 4), Vector3(2, 9, 6))


func on_goal_open() -> void:
	for n in find_children("jar_lid", "MeshInstance3D", true, false):
		var lid := n as Node3D
		var tw := lid.create_tween().set_parallel()
		tw.tween_property(lid, "position:y", lid.position.y + 3.0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(lid, "rotation:z", 0.6, 0.8)
	Fx.sparks(_pos("goal") + Vector3(0, 5, 2.6), Vector3.UP, Color(3.0, 2.4, 0.8), 40, 10.0)
