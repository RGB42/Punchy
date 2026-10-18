class_name Heroes
## The seven action figures. Colour and look follow the power. An entry with
## "locked": true shows as a silhouette on the select screen.

const ALL := [
	{"id": "blaze", "name": "BLAZE", "element": "Feuer", "model": "res://assets/models/figures/blaze.glb",
		"color": Color(1.0, 0.45, 0.1),
		"power": "Flammenstoß: Feuerkegel, schleudert Gegner weg",
		"air": "Raketen-Schub: ein Feuerstoß trägt dich hoch"},
	{"id": "frost", "name": "FROST", "element": "Eis", "model": "res://assets/models/figures/frost.glb",
		"color": Color(0.5, 0.85, 1.0),
		"power": "Eisstoß: friert Gegner ein, Eingefrorene nehmen doppelten Schaden",
		"air": "Eisplattform: erschafft unter dir einen Eisblock zum Stehen"},
	{"id": "volt", "name": "VOLT", "element": "Blitz", "model": "res://assets/models/figures/volt.glb",
		"color": Color(1.0, 0.88, 0.15),
		"power": "Kettenblitz: springt auf bis zu 5 Gegner über und lähmt sie",
		"air": "Blitz-Teleport: zuckt 8 Schritte nach vorn"},
	{"id": "stone", "name": "BOULDER", "element": "Stein", "model": "res://assets/models/figures/stone.glb",
		"color": Color(0.85, 0.55, 0.3),
		"power": "Erdbeben: Schockwelle wirft alle Gegner um dich in die Luft",
		"air": "Felsgriff: 3 Sekunden an jeder Wand klettern"},
	{"id": "venom", "name": "VENOM", "element": "Gift", "model": "res://assets/models/figures/venom.glb",
		"color": Color(0.45, 0.9, 0.25),
		"power": "Giftwolke: Gegner darin verlieren Leben, werden langsam und greifen nicht an",
		"air": "Rankenschuss: Greifhaken an jede Fläche, auf die du zielst"},
	{"id": "gale", "name": "GALE", "element": "Wind", "model": "res://assets/models/figures/gale.glb",
		"color": Color(0.6, 1.0, 0.85),
		"power": "Wirbelsturm: zieht Gegner heran und wirbelt sie hoch",
		"air": "Aufwind: 3 Sekunden steigend gleiten"},
	{"id": "shade", "name": "SHADE", "element": "Schatten", "model": "res://assets/models/figures/shade.glb",
		"color": Color(0.7, 0.4, 1.0),
		"power": "Schattenkette: taucht hinter bis zu 3 Gegnern auf, Schilde nutzen nichts",
		"air": "Phasensprung: 5 Schritte nach oben, auch durch Möbelböden"},
]


static func by_id(id: String) -> Dictionary:
	for h in ALL:
		if h["id"] == id:
			return h
	return ALL[0]
