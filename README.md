# Punchy

Actionfiguren sind in einem ganz normalen Haus lebendig geworden. 3D-Action-Adventure
(God of War trifft Batman Arkham) mit Godot 4.7. Wähle eine Actionfigur und ein Zimmer:

1. **Das Kinderzimmer**: vom Kleiderschrank zum offenen Fenster. Ritter, Puppen, Zinnsoldaten, Endgegner Blechkönig.
2. **Die Küche**: von der Tür über Arbeitsplatte, Hängeschränke und Kühlschrank zur Keksdose auf dem Tisch.
   Aufziehroboter (gepanzert), Spielzeug-Dinos (Schwanzfeger: springen!), Endgegner Spielzeugdrache
   (Feueratem, Schwanzschwung, Biss, Sturzflug). Vorsicht: Spülbecken und glühende Herdplatte.

| Figur | Element | Kraft am Boden (Q) | Kraft in der Luft (Q) |
|---|---|---|---|
| **Blaze** (rot-orange) | Feuer | Flammenstoß: Feuerkegel, schleudert weg | Raketen-Schub nach oben |
| **Frost** (blau-weiß) | Eis | Eisstoß: friert ein, Eingefrorene nehmen doppelten Schaden | Eisplattform zum Draufstellen |
| **Volt** (schwarz-gelb) | Blitz | Kettenblitz: bis zu 5 Gegner, lähmt | Blitz-Teleport 8 Schritte vor |
| **Boulder** (braun-grau) | Stein | Erdbeben: wirft alle ringsum hoch | Felsgriff: 3 s an jeder Wand klettern |
| **Venom** (grün-lila) | Gift | Giftwolke: Schaden, langsam, kein Angriff | Rankenschuss: Haken an jede Fläche (grüner Zielpunkt) |
| **Gale** (weiß-mint) | Wind | Wirbelsturm: zieht heran, wirbelt hoch | Aufwind: 3 s steigend gleiten |
| **Shade** (lila-schwarz) | Schatten | Schattenkette: hinter 3 Gegner, ignoriert Schilde | Phasensprung: 5 nach oben, durch Möbelböden |

Design: [docs/DESIGN.md](docs/DESIGN.md) · Plan: [docs/PLAN.md](docs/PLAN.md)

## Starten

Projekt in Godot 4.7.1 öffnen und F5 drücken, oder:

```bash
"N:/Programme/EigeneProjekte/Godot/Godot_v4.7.1-stable_win64.exe" --path .
```

Das Spiel startet im Auswahlbildschirm (◀ ▶ Figur, ▲ ▼ Level). Nach einem Level geht es mit der Sprungtaste weiter. Das Intro im Level lässt sich mit einer beliebigen Taste überspringen. Der Trainingsraum
mit allen Bewegungs-Hindernissen und endlosen Gegnerwellen ist `scenes/gym.tscn`.

## Steuerung

| | Tastatur / Maus | Gamepad (Xbox) |
|---|---|---|
| Laufen / Kamera | WASD / Maus | linker / rechter Stick |
| Springen, Doppelsprung, halten = Gleiten | Leertaste | A |
| Ausweichrolle / in der Luft Dash | Shift | B |
| Greifhaken (gelb = ziehen, blau = schwingen) | E / Mittelklick | LT |
| Angriff (4er-Kombo, springt zum Gegner in Stick-Richtung) | Linksklick | X |
| Konter (bei gelbem **!**, schlägt auch Korken zurück) | Rechtsklick | Y |
| Schwerer Angriff (bricht Schilde) / in der Luft Bodenstampfer | F | RB |
| Elementkraft (Energie aus der Kombo) / in der Luft Luftkraft | Q | LB |
| Spezial-Finisher ab 8er-Kombo (Anzeige "FINISHER BEREIT") | F | RB |
| Pause | Esc | Start |

Rotes **!!** lässt sich nicht kontern: ausweichen oder springen.
Liegende Gegner: Angriff = Boden-Takedown. Nach dem Uppercut (F) springen = hinterher,
dann Luftkombo; der 4. Schlag schmettert den Gegner zu Boden. Weggeschleuderte Gegner
prallen mit Schaden gegen Möbel.
Gegen Leiter und Vorhang laufen = klettern. Kanten werden automatisch gegriffen.

## Assets neu erzeugen

Alles ist per Skript erzeugt, nichts von Hand modelliert:

```bash
"N:/Programme/Blender/blender.exe" --background --python-exit-code 1 --python tools/blender/build_figure.py -- blaze
```

Varianten: `blaze`, `frost`, `volt`, `stone`, `venom`, `gale`, `shade`, `robot`, `dino`, `knight`, `doll`, `soldier`, `king`. Der Drache: `tools/blender/build_dragon.py`. Die Zimmer: `build_room.py` (Kinderzimmer),
`build_kitchen.py` (Küche), gemeinsamer Baukasten und Marker-Vertrag in `roomkit.py`.
Sounds: `python tools/gen_sfx.py`. Vorschaubild eines Modells:
`tools/blender/preview.py -- <glb> <png> [winkel]`.

## Tests

Headless, je Szene; Exit-Code 1 bei Fehler:

```bash
"N:/Programme/EigeneProjekte/Godot/Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 40000 res://scenes/tests/test_movement.tscn
```

`test_movement` (Sprunghöhen, Dash, Kanten, Klettern, Haken), `test_combat`
(Kombo, Schild, Konter, Hitstop, Arena), `test_enemies` (Soldat, Puppe, König),
`test_route` / `test_route_kitchen` (ein Bot spielt jede Verbindung der Level durch), `test_heroes` (alle Elementkräfte,
Auswahlbildschirm). Musik: `python tools/gen_music.py`.
`shot_combat` / `shot_room` / `shot_kitchen` laufen im Fenster und speichern Bilder.
Fenster-Läufe mit `--screen 1` öffnen auf dem zweiten Bildschirm.
Entwickler-Parameter (Level direkt: `res://scenes/kids_room.tscn` als Szene angeben):
`-- --hero=frost --skip-intro --shot=bild.png --shot-delay=3 --cam=x,y,z,zx,zy,zz --fps`.
