# Scanbike – Günstiger Prototyp / PoC mit Consumer-Hardware

**Stand:** 14.10.2026 | **Ziel:** Iteration 0–1 aus `SCANBIKE_Umsetzungsplan.md` für ~100–400 € fahren (mit 2× vorhandener Hero 8)
**Prinzip:** gebrauchter 360-/Actioncam-Bestand, Position per Multi-GNSS-Merge + PPK statt teurem Echtzeit-RTK, Rest aus der Schublade.
Kein Jetson, kein Wetterschutz — Trockenbetrieb, Post-Processing auf dem Laptop.

---

## 1. Was der PoC beweist (und was nicht)

**Beweist:** Kamerapositionen und Brennweiten am eigenen Trike, synchroner Bild+Positions-Log,
erste Zonenkarte in QGIS, Trainingsmaterial für YOLO, OCR-Erwartungswerte.

**Beweist nicht:** beweissichere Treffer an Zonengrenzen (Positionsgenauigkeit erst nach PPK, Rolling Shutter),
Nacht-/Regenbetrieb, Live-Erkennung. Alles außerhalb der PPK-Toleranz ist „unsicher“.

## 2. Stückliste

| Rolle | Empfehlung gebraucht | ca. Preis | Neu-Alternative |
|---|---|---|---|
| Seiten links+rechts in einem File | Insta360 X3 (5,7K-360, 1/2"-Sensor) | 180–300 € [^1] | X4/X5 neu |
| Front/Kontext + Schilder | GoPro Hero 10 Black (5,3K, GPS, Protune) | 170–200 € [^2] | Hero 11 (~250 €, letzte mit GPS [^3]) |
| Budget-Alternative Front | GoPro Hero 9 Black | 120–150 € | — |
| Position, cm-genau (nach der Fahrt) | u-blox M8T (Rohdaten) + PPK mit RTKLIB + SAPOS-RINEX, Details Abschnitt 5 | ~50 € gebraucht | RTK-Puck ZED-F9P ~300 € (erst ab Iteration 3 nötig) |
| Position, robust (während der Fahrt) | Multi-GNSS-Merge: Hero-8-GPS + Handy + M8T loggen, besten Track nehmen | 0 € | — |
| Strom | 2× Ersatzakku + Powerbank, Dauer-USB am Stand | ~50 € | — |
| Halterung (T-Riegel, siehe unten) | Querbalken 95–100 cm + Längsbalken 60 cm, Alu 20×20, 2 Spanngurte | ~40 € | — |

**~450-€-Kernpaket:** X3 + Hero 10 gebraucht. Mit M8T-PPK ~500 €, mit Handy-GPS-Merge ~450 €.

### Variante mit 2× Hero 8 (vorhanden, 0 €) — empfohlen

Zwei gleiche Kameras gratis sind besser als jede Kaufempfehlung:

* **Links + rechts:** je eine Hero 8, identische Einstellungen (gleiche Farbabstimmung und Geometrie — Vorteil gegenüber Mischbestückung). 4K reicht auf 2–7 m Seitendistanz für Kennzeichen + Bordstein.
* **Front:** Handy (reicht für Kontext/Schilder-Übersicht).
* **Kosten:** nur noch M8T-PPK (~50 €) + Halter/Strom (~90 €) = **~140 €**; ganz ohne Neuteile (Handy-GPS-Merge) **~90 €**. RTK-Puck erst ab Iteration 3 nötig.
* Beide Hero 8 per App/Remote gleichzeitig starten, dazu weiter Klatsch-Sync (Abschnitt 4).
* 360-Kamera entfällt — Reframing-Workflow entfällt ebenfalls, dafür zwei normale MP4-Files.

### T-Riegel: die PoC-Halterung (ein Nachmittag, ~40 €)

Statt gedämpftem Wechsel-Rack (erst ab Jetson-Stufe nötig, siehe `SCANBIKE_Rack_Schema.svg`):
ein T aus 2× Alu-Profil 20×20, das von oben auf den Bord gelegt wird.

* **Querbalken ~95–100 cm** über den Bord: steht beidseitig über, Seitenkameras schauen dadurch an den breiten hinteren Ecken vorbei. **Längsbalken ~60 cm** nach vorne für die Frontkamera über den schmalen Bug. Verbunden mit 2 Winkelblechen.
* **4 Gummifüße** (Türstopper) als Kontakt zum Bordrand, **2 Spanngurte** um die Box gegen Verrutschen/Abheben. Kein Bohren, keine Pfannen.
* Kameras auf Kugelköpfen oder festen 15°-Winkeln (Neigung: Platte auf 1–3 m in Bildmitte, per Testfahrt prüfen, siehe Abschnitt 3). GoPros nehmen intern auf → **null Verkabelung**, Powerbanks lose in der Box.
* **Abstriche (PoC-verträglich):** das T federt — Geometrie *zwischen* Kameras wackelt, egal (keine Stereo-Fusion im PoC); Wiederholgenauigkeit ±cm → pro Fahrt 30-s-Ausrichtungscheck; sieht nach Bastel aus (für privaten Prototyp ok).

**Gebrauchtkauf-Check:** Linse gegen Licht prüfen (Kratzer = Killer, bei 360-Linsen fatal fürs Stitching),
Akkus als Verschleiß einpreisen (Blähakkus ersetzen), Dichtungen alter Geräte nicht mehr trauen —
passt zum reinen Trockenbetrieb.

## 3. Kamera-Einstellungen (festnageln!)

GoPro (Protune an, Hero 8/9/10/11; Tipp: GoPro-Labs-Firmware für Skript-Start und fixe Belichtung):
* Auflösung maximal (Hero 8: 4K, Hero 10: 5,3K), Bitrate hoch, Kapitelung egal
* Weißabgleich fix (z. B. 5500 K), kein Auto-WB
* Verschlusszeit min. 1/500 (gegen Rolling-Shutter-Schräglage bei Fahrt)
* ISO-Limit eng (max. 800), Stabilisierung **aus** (verzieht Geometrie)
* GPS an (Hero 12/13 haben keins mehr [^3] — daher gezielt 8/9/10/11 nutzen)

Insta360 X3: 5,7K-360, Active HDR an, Belichtung manuell wo möglich, Stitching-Referenz zu Fahrtbeginn.

Fahrregel: trocken, <10 km/h. Sonst taugen weder Rolling Shutter noch Kompression.

## 4. Synchronisation ohne Trigger

1. Alle Geräte per Uhrzeit/NTP syncen, GoPro-GPS als Reserve-Logging an.
2. Zu Fahrtbeginn **einmal laut klatschen** (Audio-Peak in allen Files) + Referenzfoto einer Uhr.
3. Drift über 1 h: einige 100 ms (≈ Meter bei 4 m/s) — dokumentieren, für PoC ok.
4. Positions-Tracks (M8T-Rohdaten + Handy-GPS + GoPro-Telemetry) laufen parallel auf Handy/Laptop mit.

## 5. Position ohne RTK-Puck: Multi-GNSS-Merge + PPK

**Warum nicht einfach mitteln:** Mehrere Billig-Empfänger ergeben kein RTK. Die dominanten Fehler
(Ionosphäre, Ephemeriden, v. a. Multipath an Hauswänden) sind für alle Empfänger am gleichen Ort
korreliert — drei Empfänger auf der Box sehen fast denselben Meter-Fehler. Raus mittelt sich nur
Empfängerrauschen (Dezimeter), das ist nicht das Problem.

**Was Multi-GNSS trotzdem bringt (gratis):** alle Quellen mitloggen (Hero-GPS-Telemetry,
Handy-Track, M8T-Rohdaten), pro Sekunde den besten Track nehmen (Fix-Status, HDOP).
Das überbrückt Aussetzer und entlarvt Ausreißer (ein Track springt 15 m, die anderen nicht →
verwerfen). Heading aus dem Bewegungsvektor ab ~2 m/s Fahrt (Handy-Kompass ist am E-Motor/
Stahlrahmen unbrauchbar), Rad-Odometrie für Stillstand.

**PPK-Workflow (cm nach der Fahrt, ~50 € statt ~300 €):**
1. M8T loggt Rohdaten (UBX/RXM-RAWX) während der Fahrt auf Handy/Laptop.
2. Zu Hause: kostenlose SAPOS-RINEX-Daten des Tages laden [^5], mit RTKLIB auswerten [^4].
3. Ergebnis: cm-Track als GPX/CSV → mit Kamera-Timestamps mappen (Abschnitt 6, Schritt 3).
4. Kein NTRIP unterwegs nötig, kein Echtzeit-Fix-Stress — ideal, weil der PoC nichts live entscheiden muss.

**Upgrade-Pfad (erst wenn nötig):** NEO-M8P Single-Band-RTK (~100 €, langsamer Fix, leidet in
Schluchten) → RTK-Puck ZED-F9P + NTRIP (~300 €, ab Iteration 3 für Live-Events) →
Dual-Antenne 2×F9P (~600 €, exaktes Heading im Stand, erst Iteration 5).

## 6. Auswerte-Workflow (Laptop)

```bash
# 1. (nur 360-Variante) File in links/rechts reframieren (Insta360 Studio, Export 2× 4K)
# 2. Frames extrahieren, nur I-Frames für OCR-Crops
ffmpeg -i front.mp4 -vf fps=2 front_%05d.jpg
# 3. Timestamps (Creation-Time + fps) auf PPK-/Merge-Track mappen (Python-Skript, Toleranz ±100 ms)
# 4. Punkte mit Foto-Link nach QGIS (GeoJSON-Vorlage: parkzonen_beispiel.geojson)
```

Kennzeichen-Crops aus I-Frames ziehen (H.265 frisst an P-Frames Kanten), manuell labeln →
füttert `parkzonen_beispiel.geojson` und wird später YOLO-Trainingsmaterial.

## 7. Abnahme PoC

* [ ] 30-min-Trockenfahrt: alle Frames einer Pose zuordenbar, PPK-Fix-Anteil dokumentiert
* [ ] 10 Stellen mit Maßband-Gegenmessung der Gehweg-Restbreite (Foto-Schätzung vs. Band)
* [ ] QGIS: Track + 1 Halteverbots-Linie + 5 gelabelte Fälle
* [ ] Entscheidung: welche Brennweite/Position funktioniert → erst dann Profi-Kameras kaufen

Danach weiter mit Iteration 2–3 aus `SCANBIKE_Umsetzungsplan.md` (Jetson, Event-Pipeline).

## 8. Warum (noch) keine Onboard-Unit

Der PoC kommt bewusst ohne Rechner am Rad aus: aufzeichnen und loggen geht ohne,
gerechnet wird zu Hause.

* **Video:** nur Recording auf SD (Strom per Powerbank). YOLO, OCR und Blur laufen auf dem Laptop — eine Unit würde nur Strom fressen und Hitze produzieren.
* **GPS:** nur Logging (M8T-Rohdaten, Handy-Track, GoPro-Telemetry), PPK-Auswertung zu Hause. Kein Echtzeit-Fix nötig, weil nichts live entschieden wird.
* **Manuelle Meldungen:** Handy reicht (Foto mit GPS-/Zeitstempel). Optional Bluetooth-Fernauslöser (~15 €) am Lenker als Marker-Taster („hier prüfen“), später am Timestamp im Track wiederfinden. Oder OSMAnd-Favorit / simples HTML-Formular als PWA.

**Nötig wird eine Unit erst ab:** Iteration 2 (Live-Erkennung), Iteration 3 (Anonymize-first und
Event-Filter *vor* dem Upload — ohne Edge-Filter darf Rohvideo gar nicht hochgeladen werden,
Datenminimierung), Upload-Queue mit Resume, Echtzeit-Feedback.

**Kleinstmögliche Zwischenstufe (Komfort, kein Muss):** Raspberry Pi 5 (~100 €) als reiner Logger —
NTP-Zeitserver für alle Geräte, sammelt NMEA, WLAN-Vorschau der Kameras.

---

## Quellen

[^1]: mpb – gebrauchte Insta360 X3, 179–294 €. <https://www.mpb.com/de-at/produkt/insta360-x3>
[^2]: kleinanzeigen – GoPro Hero 10 Black gebraucht, ca. 170–300 € je Zustand. <https://www.kleinanzeigen.de/s-gopro-hero10/k0>
[^3]: GoPro Telemetry Extractor – Hero 12 ohne GPS-Option (Hero 11 letzte mit GPS). <https://goprotelemetryextractor.com/blog/go-pro-hero-12-gps-option-missing>
[^4]: RTKLIB – Open-Source-Programmpaket für RTK/PPK-Auswertung. <http://www.rtklib.com/>
[^5]: SAPOS – amtlicher Korrekturdienst, RINEX-Daten der Landesvermessung. <https://www.sapos.de/>
