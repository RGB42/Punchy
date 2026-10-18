# Punchy — Design

Ein 3D-Action-Adventure: Spielzeug-Actionfiguren sind in einem normalen Haus
lebendig geworden. Gameplay-Mischung aus den alten **God of War** (wuchtige
Arena-Kämpfe, Kletter- und Sprungpassagen durch handgebaute Level) und
**Batman Arkham** (Freeflow-Kampf gegen Gruppen, Konter, flüssige Bewegung).

## Warum / Erfolgskriterium

Der Spieler soll sich **wuchtig** und **frei** fühlen. Jeder Treffer hat Gewicht
(Hitstop, Kamerawackler, Funken, Rückstoß, Sound), die Figur ist winzig, aber
extrem beweglich. Scheitern = technisch läuft alles, aber Kämpfe fühlen sich
schwammig an oder Bewegung fühlt sich wie Schienen an.

## Erste spielbare Version (Ziel)

- **Ein Level = ein Zimmer** (Kinderzimmer), sichtbar markiertes Ziel auf der
  anderen Seite (leuchtendes offenes Fenster), **20–30 Minuten** Spielzeit.
- Start: Figur klettert aus der Schranktür, **Kameraschwenk** über den Raum.
- **Eine** spielbare Figur: **Blaze** — rot-orange, Feuerkräfte.
- 4–6 Kampfarenen, 3–4 große Kletter-/Sprungabschnitte, kleinere Wege dazwischen.
- Gegner: Ritter-Soldat (Schwert, Schild), Puppe (schnell, schwach),
  Zinnsoldat-Schütze (Fernkampf), Drachenfigur als Endgegner.
- Gamepad + Tastatur/Maus.

**Bewusst nicht drin:** Menüs außer Pause, Figurenauswahl, Story, weitere
Zimmer, Speicherstände. Die anderen 6 Figuren kommen, wenn Kampf und Bewegung
sitzen (Eis = blau-weiß, Blitz = schwarz-gelb, …).

## Maßstab

Figur real 15 cm, im Spiel **1,8 Einheiten** (Faktor 12). Zimmer real
4,5 × 4,5 × 2,5 m → im Spiel **54 × 54 × 30**. Alles wird in Figurgröße
modelliert, damit Physik, Kamera und Sprungwerte normale Zahlen haben. Der
Miniatur-Eindruck kommt aus Proportionen, Details (Teppichfasern,
Holzmaserung, riesige Steckdosen) und Tiefenunschärfe.

## Bewegung

Laufen, Sprung, **Doppelsprung**, **Schleuder-Dash** (vorwärts in der Luft,
oder nach oben), **Gleiten** (Sprung halten im Fall), **Greifhaken** (Ziehen zu
Haken-Punkten / Schwingen an Schwing-Punkten), **Kanten greifen + hochziehen +
hangeln**, **Klettern** an markierten Flächen (Vorhang, Bettdecke, Korkwand).
Coyote-Time und Jump-Buffer, damit es sich großzügig anfühlt.

## Kampf (Freeflow)

- **Angriff** zielt automatisch auf den Gegner in Stick-Richtung und stürzt
  sich auf ihn (Arkham-Lunge). 4er-Kombo, der 4. Schlag ist ein Finisher.
- **Schwerer Angriff** (halten): Schild brechen, Gegner wegschleudern / hoch.
- **Konter**: Gegner zeigt vor dem Angriff ein Warnzeichen; Konter im Fenster
  → Gegner taumelt, Kombo läuft weiter.
- **Ausweichen** (Rolle mit kurzen I-Frames).
- **Feuerkraft**: Energie aus der Kombo; Flammenstoß (Kegel) und
  Feuer-Bodenstampfer aus der Luft (Flächenschaden).
- **Treffer-Feedback**: Hitstop (globale Zeitlupe 40–120 ms je nach Schlag),
  Trauma-basierter Kamerawackler, weißer Treffer-Blitz am Gegner, Funken- und
  Plastiksplitter-Partikel, Rückstoß, Soundschicht; letzter Gegner einer Arena
  → Zeitlupe + Kamera-Zoom.
- **Gegnergruppen**: Nur 1–2 Gegner greifen gleichzeitig an (Angriffs-Tokens),
  die anderen umkreisen den Spieler.
- **Arenen**: Betreten schließt Barrieren (Bauklötze fahren hoch), Wellen
  spawnen, nach dem Sieg öffnet sich der Weg.

## Art Direction

Glänzendes Spielzeugplastik vor warm beleuchtetem Zimmer. Starke Farbcodes:
Spielerfiguren gesättigt, Gegner etwas gedämpfter, interaktive Punkte
(Haken, Kletterflächen) mit dezentem Leuchten. Sonnenstrahlen durchs Fenster
mit Staub (volumetrischer Nebel), SSAO, Glow, Tiefenunschärfe in der Ferne.

## Wie es gebaut wird (meine Entscheidungen)

- **Godot 4.7.1**, Forward+, GDScript, Jolt-Physik.
  `N:\Programme\EigeneProjekte\Godot\Godot_v4.7.1-stable_win64.exe`
- **Blender 5.2.2** (`N:\Programme\Blender\blender.exe`) per Python-Skript im
  Hintergrund → `.glb`. Figuren bestehen aus festen Plastikteilen mit einem
  Knochen pro Teil (starr gewichtet) — wie echte Actionfiguren.
- **Animationen** entstehen in Godot aus Schlüsselposen (Knochenrotationen)
  mit Zeitkurven. Angriffsdaten (Ausholen, Trefferfenster, Erholung, Schaden,
  Rückstoß) und Posen stehen in derselben Tabelle — Animation und Kampf-Timing
  können nicht auseinanderlaufen. Gleiches Skelett für humanoide Gegner.
- **Möbel** per Blender-Skript mit abgerundeten Kanten; Kollision als einfache
  Boxen aus derselben Layout-Tabelle.
- **Sound**: prozedural per Python erzeugte WAVs (wie in Toddlerfall), später
  austauschbar.
- **Tests**: Headless-Test-Szenen, die die Figur per Code steuern und Werte
  prüfen (Sprunghöhe, Kombo trifft, Arena öffnet sich).
