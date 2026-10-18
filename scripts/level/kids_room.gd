extends Level
## Level 1: the kids' room. Wardrobe to window. Built by tools/blender/build_room.py.

const ROOM := preload("res://assets/models/rooms/kids_room.glb")

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

const HINTS := [
	[Vector3(17.4, 1.9, 22.4), 6.0, "Leertaste: Springen  -  in der Luft nochmal: Doppelsprung (Salto)"],
	[Vector3(8, 0, 10), 7.0, "Linke Maus: Angriff  -  Rechte Maus bei !: Konter  -  F: Schwerer Angriff (bricht Schilde)"],
	[Vector3(-12, 0, 17), 5.0, "Gegen Leiter & Vorhang laufen: Klettern  -  oben: Hochziehen"],
	[Vector3(-19, 20.7, 0), 6.0, "E / Mittelklick auf blauen Ring: Schwingen  -  Springen: Loslassen"],
	[Vector3(-12, 21.6, -23), 6.0, "Shift in der Luft: Dash  -  Q in der Luft: Luftkraft deiner Figur  -  Sprung halten: Gleiten"],
	[Vector3(21, 9, -9.5), 6.0, "Q am Boden: Elementkraft (kostet Energie)  -  F in der Luft: Bodenstampfer  -  ab 8 Treffern F: Finisher"],
]


func room_scene() -> PackedScene:
	return ROOM


func arenas() -> Dictionary:
	return ARENAS


func final_arena() -> String:
	return "arena_4"


func hints() -> Array:
	return HINTS


func title() -> String:
	return "DAS KINDERZIMMER"


func subtitle() -> String:
	return "Erreiche das Fenster"


func goal_open_text() -> String:
	return "Das Fenster ist offen! Spring auf die Fensterbank!"


func extra_lights() -> void:
	var lamp := SpotLight3D.new()  # the desk lamp
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 6.0
	lamp.spot_range = 14.0
	lamp.spot_angle = 50.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.look_at_from_position(Vector3(19.5, 13.4, -18.6), Vector3(19, 9, -15))
