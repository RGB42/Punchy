# Punchy

Actionfiguren sind in einem ganz normalen Haus lebendig geworden. 3D-Action-Adventure
(God of War trifft Batman Arkham) mit Godot 4.7. Level 1: **das Kinderzimmer**.
Du bist **Blaze**, die Feuer-Actionfigur, und kämpfst und kletterst dich vom
Kleiderschrank bis zum offenen Fenster.

Design: [docs/DESIGN.md](docs/DESIGN.md) · Plan: [docs/PLAN.md](docs/PLAN.md)

## Starten

Projekt in Godot 4.7.1 öffnen und F5 drücken, oder:

```bash
"N:/Programme/EigeneProjekte/Godot/Godot_v4.7.1-stable_win64.exe" --path .
```

Das Intro lässt sich mit einer beliebigen Taste überspringen. Der Trainingsraum
mit allen Bewegungs-Hindernissen und endlosen Gegnerwellen ist `scenes/gym.tscn`.

## Steuerung

| | Tastatur / Maus | Gamepad (Xbox) |
|---|---|---|
| Laufen / Kamera | WASD / Maus | linker / rechter Stick |
| Springen, Doppelsprung, halten = Gleiten | Leertaste | A |
| Ausweichrolle / in der Luft Feuer-Dash | Shift | B |
| Greifhaken (gelb = ziehen, blau = schwingen) | E / Mittelklick | LT |
| Angriff (4er-Kombo, springt zum Gegner in Stick-Richtung) | Linksklick | X |
| Konter (bei gelbem **!**, schlägt auch Korken zurück) | Rechtsklick | Y |
| Schwerer Angriff (bricht Schilde) / in der Luft Bodenstampfer | F | RB |
| Flammenstoß (Energie aus der Kombo) / in der Luft Raketen-Schub | Q | LB |
| Pause | Esc | Start |

Rotes **!!** lässt sich nicht kontern: ausweichen oder springen.
Gegen Leiter und Vorhang laufen = klettern. Kanten werden automatisch gegriffen.

## Assets neu erzeugen

Alles ist per Skript erzeugt, nichts von Hand modelliert:

```bash
"N:/Programme/Blender/blender.exe" --background --python-exit-code 1 --python tools/blender/build_figure.py -- blaze
```

Varianten: `blaze`, `knight`, `doll`, `soldier`, `king`. Das Zimmer:
`tools/blender/build_room.py` (Möbel, Kollision, Marker für Haken/Arenen/Sterne).
Sounds: `python tools/gen_sfx.py`. Vorschaubild eines Modells:
`tools/blender/preview.py -- <glb> <png> [winkel]`.

## Tests

Headless, je Szene; Exit-Code 1 bei Fehler:

```bash
"N:/Programme/EigeneProjekte/Godot/Godot_v4.7.1-stable_win64.exe" --headless --path . --quit-after 40000 res://scenes/tests/test_movement.tscn
```

`test_movement` (Sprunghöhen, Dash, Kanten, Klettern, Haken), `test_combat`
(Kombo, Schild, Konter, Hitstop, Arena), `test_enemies` (Soldat, Puppe, König),
`test_route` (ein Bot spielt jede Verbindung des Levels durch).
`shot_combat` / `shot_room` laufen im Fenster und speichern Bilder.
Entwickler-Parameter: `-- --skip-intro --shot=bild.png --shot-delay=3 --cam=x,y,z,zx,zy,zz --fps`.
