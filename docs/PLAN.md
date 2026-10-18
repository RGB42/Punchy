# Punchy — Umsetzungsplan

> **Stand 2026-10-18:** M1–M7 umgesetzt, 72 Headless-Tests grün (Bewegung 17, Kampf 20,
> Gegner 6, Route 5, Helden 24). M5 = Finisher, Boden-Takedown, Luftkombo, Wand-Aufprall,
> Kampfkamera. M6 = Auswahlbildschirm, Frost (Eis), Volt (Blitz), dynamische Musik.
> M7 = alle 7 Figuren: Boulder (Stein), Venom (Gift), Gale (Wind), Shade (Schatten).
> M8 = Level 2 Küche (Gefahren Wasser/Herdplatte), Aufziehroboter, Dino, Endgegner Drache,
> Level-Basisklasse + Levelwahl, Kraftfeld-Barrieren, Bosskamera. 91 Tests grün. Offen: Anspielen durch Ralph (Gefühl, Spieldauer 20–30 min prüfen),
> Musik, weitere Figuren. Abweichungen vom Plan: Bosskampf ist der „Blechkönig“
> (Riesenritter) statt eines Drachen; Animationen laufen ohne Skinning über Gelenk-Nodes.

> Spec: [DESIGN.md](DESIGN.md). Ausführung: nativ, Meilenstein für Meilenstein.
> Nach jedem Meilenstein spielt Ralph an — Gefühl lässt sich nicht headless testen.

**Goal:** Ein Zimmer-Level, 20–30 min, mit Freeflow-Kampf und freier Bewegung, gespielt mit Blaze (Feuer).
**Architecture:** CharacterBody3D-Spieler mit Zustandsmaschine; Posen-Animator auf einem starren Figuren-Skelett; Kampf über Treffer-Dictionaries und ein Juice-Autoload (Hitstop, Shake, Zeitlupe); Level aus einer Layout-Tabelle gebaut.
**Tech Stack:** Godot 4.7.1 (Forward+, Jolt), GDScript, Blender 5.2.2 Python, Python für SFX.

## Global Constraints

- Maßstab: Figur 1,8 Einheiten hoch, Zimmer 54 × 54 × 30 (Faktor 12).
- Godot ist Y-up, Figuren schauen nach −Z.
- Tests laufen als gebootete Szene: `godot --headless --path . --quit-after 600 res://scenes/tests/<t>.tscn`; Ausgabe `PASS <name>` / `FAIL <name>: <grund>`, Exit-Code 1 bei Fehler.
- Kein neues Plugin/Addon ohne Not.
- Eingaben über InputMap-Aktionen: `move_*`, `look_*`, `jump`, `attack`, `heavy`, `counter`, `dodge`, `power`, `grapple`, `pause`.

## Review Focus

1. Kanten/Kletterflächen: Figur bleibt an Kanten hängen oder fällt durch dünne Möbel → Kollision immer Box, Mindestdicke 0,4.
2. Kamera in Wänden/Möbeln bei engen Passagen → SpringArm mit Kollisionsmaske nur für Level.
3. Hitstop stapelt sich bei Mehrfachtreffern zu langem Einfrieren → Hitstop nimmt Maximum, nie Summe.
4. Gegner fällt von Möbeln / bleibt außerhalb der Arena hängen → Respawn zum Arena-Mittelpunkt, wenn Y unter Arena-Boden − 5.
5. Spieler fällt in den Abgrund → Respawn am letzten Checkpoint, mit Schaden.

## Dateistruktur

```
project.godot
scripts/autoload/juice.gd        Hitstop, Kamerawackler, Zeitlupe, FX-Spawns
scripts/anim/figure_animator.gd  Posen-Blending auf Skeleton3D
scripts/anim/poses.gd            Posen-Tabelle (Knochen → Euler-Grad)
scripts/player/player.gd         Bewegung + Zustandsmaschine
scripts/player/player_combat.gd  Kombo, Konter, Ausweichen, Feuerkraft
scripts/player/moves.gd          Angriffs-Tabelle (Timing, Schaden, Posen)
scripts/camera/player_camera.gd  Orbit-Kamera, Kampf-Framing, Intro-Schwenk
scripts/enemies/enemy.gd         Gegner-Basis (Zustände, Treffer, Tod)
scripts/level/arena.gd           Trigger, Wellen, Barrieren, Angriffs-Tokens
scripts/level/room_builder.gd    Zimmer aus Layout-Tabelle (@tool)
scripts/level/grapple_point.gd   Haken-/Schwingpunkt
scenes/main.tscn, player.tscn, enemies/*.tscn, tests/*.tscn
tools/blender/build_figure.py    Actionfigur (Mesh + Skelett) → assets/models/
tools/blender/build_furniture.py Möbel-Kit → assets/models/furniture/
tools/blender/preview.py         Kontrollbild eines .glb
tools/gen_sfx.py                 Prozedurale Sounds → assets/sfx/
```

## M1 — Fundament & Bewegung

1. **Projekt**: `project.godot` (Forward+, Jolt, InputMap inkl. Gamepad), Ordner, Test-Runner `scripts/tests/test_base.gd` (`check(cond, name, msg)`, `finish()` → Exit-Code).
2. **Figur**: `build_figure.py` baut Blaze aus starren Teilen (Kopf mit Helm/Flammenkamm, Torso mit Brustpanzer, Becken, Ober-/Unterarme, Hände, Ober-/Unterschenkel, Füße), Knochen `hips, spine, chest, neck, head, upper_arm.L/R, lower_arm.L/R, hand.L/R, thigh.L/R, shin.L/R, foot.L/R`, Höhe 1,8 ± 0,05, < 15k Dreiecke. Farb-Parameter, damit Gegner und andere Helden dasselbe Skript nutzen. Prüfung: Skript-`check()` + Vorschaubild.
3. **Animator**: `FigureAnimator.play(pose_or_clip: StringName, blend: float)`, `set_locomotion(speed: float, grounded: bool)`; Clips = Liste `[pose, dauer, kurve]`. Laufzyklus prozedural (Sinus auf Beinen/Armen, Neigung in Laufrichtung).
4. **Bewegung** (`player.gd`): Zustände `GROUND, AIR, GLIDE, DASH, LEDGE, CLIMB, GRAPPLE_PULL, GRAPPLE_SWING`. Werte: Laufen 9/s, Sprint 13/s, Sprung-Apex 3,2, Doppelsprung-Apex 2,6, Dash 22/s für 0,18 s (1× pro Luftphase), Gleiten Fallgeschw. max 3/s, Coyote 0,12 s, Buffer 0,12 s. Haken-Reichweite 18. Tests: Apex-Höhen ±0,15, Dash-Distanz, Kante greifen aus Sprung, Haken zieht bis Punkt.
5. **Kamera**: SpringArm (Länge 5, im Kampf bis 7,5), Maus/Stick-Orbit, automatisches Nachführen bei Bewegung, Kollision nur mit Level-Layer.
6. **Testraum** `scenes/tests/gym.tscn`: Boxen, Kanten, Kletterwand, Haken- und Schwingpunkte, zum Anspielen.

## M2 — Kampf

1. `juice.gd`: `hitstop(sec)` (Maximum, nicht Summe), `shake(trauma)`, `slowmo(scale, sec)`, `spawn_fx(name, pos, dir)`.
2. `moves.gd`: je Angriff `{pose_windup, pose_strike, windup, active, recover, damage, knockback, launch, hitstop, shake}`; Kombo light 1–4, heavy, slam, counter, Flammenstoß.
3. `player_combat.gd`: Zielwahl (Kegel 60° um Stick-Richtung, Reichweite 9, sonst nächster), Lunge bis 0,9 vor Ziel, Kombo-Fenster 0,35 s, Konter-Fenster ab Warnzeichen 0,5 s, Ausweichrolle 0,35 s mit I-Frames 0,25 s, Energie +10 pro Treffer (max 100), Flammenstoß 35.
4. `enemy.gd`: Zustände `IDLE, STRAFE, APPROACH, WINDUP (Warnzeichen), ATTACK, STAGGER, KNOCKDOWN, DEAD`; `take_hit(hit: Dictionary)`. Ritter-Soldat zuerst (Schild blockt leichte Angriffe von vorn).
5. `arena.gd`: Trigger, Wellen `[{scene, count}]`, Barrieren, max. 2 Angriffs-Tokens, `cleared`-Signal, Zeitlupe auf letztem Treffer.
6. HUD: Leben, Energie, Kombo-Zähler. Tests: Kombo tötet Puppe in ≤ 4 Treffern, Konter im Fenster taumelt Gegner, Hitstop nie > 0,15 s, Arena öffnet nach letzter Welle.

## M3 — Das Zimmer

1. `build_furniture.py`: Kleiderschrank (mit offener Tür, Fächer innen), Bett mit Decke, Nachttisch, Schreibtisch + Stuhl + Lampe, Bücherregal, Kommode, Fensterbank, Zimmerpflanze (Monstera), Deckenlampe, Teppich, Spielzeugkiste, Bauklötze, Bücher, Stifte.
2. `room_builder.gd`: Layout-Tabelle → Mesh-Instanzen + Box-Kollisionen + Kletterflächen + Hakenpunkte + Arenen + Checkpoints.
3. Route (Entwurf): Schrank unten → Teppich-Arena → Spielzeugkiste → Bettdecke hochklettern → Bett-Arena → Nachttisch → Haken zur Schreibtischlampe → Schreibtisch-Arena → Regal hochklettern (Kanten) → Pflanze schwingen → Regal-Top-Arena → Deckenlampe schwingen → Kommode → Fensterbank: Drachen-Boss → Ziel.
4. Licht: Sonne durchs Fenster, volumetrischer Nebel, warmes Innenlicht, SSAO, Glow, DOF.

## M4 — Inhalt & Politur

Puppe, Zinnsoldat-Schütze, Drachen-Boss; Feuer-VFX; Sound; Intro-Schwenk; Checkpoints/Tod; Ziel-Sequenz; Pause-Menü; Tuning auf 20–30 min.
