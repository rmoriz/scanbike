# Scanbike – Günstiger Prototyp / PoC mit Consumer-Hardware

**Stand:** 14.10.2026 | **Ziel:** Iteration 0–1 aus `SCANBIKE_Umsetzungsplan.md` für ~750–1.000 € fahren
**Prinzip:** gebrauchter 360-/Actioncam-Bestand + ein Neuteil (RTK-Puck), Rest aus der Schublade.
Kein Jetson, kein Wetterschutz — Trockenbetrieb, Post-Processing auf dem Laptop.

---

## 1. Was der PoC beweist (und was nicht)

**Beweist:** Kamerapositionen und Brennweiten am eigenen Trike, synchroner Bild+Positions-Log,
erste Zonenkarte in QGIS, Trainingsmaterial für YOLO, OCR-Erwartungswerte.

**Beweist nicht:** beweissichere Treffer an Zonengrenzen (kein RTK am Bild, Rolling Shutter),
Nacht-/Regenbetrieb, Live-Erkennung. Alles außerhalb ±5 m GPS-Toleranz ist „unsicher“.

## 2. Stückliste

| Rolle | Empfehlung gebraucht | ca. Preis | Neu-Alternative |
|---|---|---|---|
| Seiten links+rechts in einem File | Insta360 X3 (5,7K-360, 1/2"-Sensor) | 180–300 € [^1] | X4/X5 neu |
| Front/Kontext + Schilder | GoPro Hero 10 Black (5,3K, GPS, Protune) | 170–200 € [^2] | Hero 11 (~250 €, letzte mit GPS [^3]) |
| Budget-Alternative Front | GoPro Hero 9 Black | 120–150 € | — |
| Position, cm-genau | Ardusimple RTK-Kit (ZED-F9P) + NTRIP (SAPOS) | ~300 € neu | — |
| Notlösung Position | Handy + NTRIP-App (SW Maps), GPS ±3–5 m | 0 € | — |
| Strom | 2× Ersatzakku + Powerbank, Dauer-USB am Stand | ~50 € | — |
| Halterung | 1,4-m-Stange (360) + Alu-Winkel auf Box, Moosgummi-Dämpfung | ~40 € | — |

**~450-€-Kernpaket:** X3 + Hero 10 gebraucht. Mit RTK-Puck ~750 €, ohne (Handy-GPS) ~500 €.

### Variante mit 2× Hero 8 (vorhanden, 0 €) — empfohlen

Zwei gleiche Kameras gratis sind besser als jede Kaufempfehlung:

* **Links + rechts:** je eine Hero 8, identische Einstellungen (gleiche Farbabstimmung und Geometrie — Vorteil gegenüber Mischbestückung). 4K reicht auf 2–7 m Seitendistanz für Kennzeichen + Bordstein.
* **Front:** Handy (reicht für Kontext/Schilder-Übersicht).
* **Kosten:** nur noch RTK-Puck (~300 €) + Halter/Strom (~90 €) = **~400 €**; ohne Puck (Handy-GPS) **~90 €**.
* Beide Hero 8 per App/Remote gleichzeitig starten, dazu weiter Klatsch-Sync (Abschnitt 4).
* 360-Kamera entfällt — Reframing-Workflow entfällt ebenfalls, dafür zwei normale MP4-Files.

**Gebrauchtkauf-Check:** Linse gegen Licht prüfen (Kratzer = Killer, bei 360-Linsen fatal fürs Stitching),
Akkus als Verschleiß einpreisen (Blähakkus ersetzen), Dichtungen alter Geräte nicht mehr trauen —
passt zum reinen Trockenbetrieb.

## 3. Kamera-Einstellungen (festnageln!)

GoPro (Protune an, Hero 10/11; Tipp: GoPro-Labs-Firmware für Skript-Start und fixe Belichtung):
* Auflösung maximal (5,3K), Bitrate hoch, Kapitelung egal
* Weißabgleich fix (z. B. 5500 K), kein Auto-WB
* Verschlusszeit min. 1/500 (gegen Rolling-Shutter-Schräglage bei Fahrt)
* ISO-Limit eng (max. 800), Stabilisierung **aus** (verzieht Geometrie)
* GPS an (Hero 12/13 haben keins mehr [^3] — daher gezielt 9/10/11 kaufen)

Insta360 X3: 5,7K-360, Active HDR an, Belichtung manuell wo möglich, Stitching-Referenz zu Fahrtbeginn.

Fahrregel: trocken, <10 km/h. Sonst taugen weder Rolling Shutter noch Kompression.

## 4. Synchronisation ohne Trigger

1. Alle Geräte per Uhrzeit/NTP syncen, GoPro-GPS als Reserve-Logging an.
2. Zu Fahrtbeginn **einmal laut klatschen** (Audio-Peak in allen Files) + Referenzfoto einer Uhr.
3. Drift über 1 h: einige 100 ms (≈ Meter bei 4 m/s) — dokumentieren, für PoC ok.
4. RTK-Track (NMEA vom Puck, 10 Hz) läuft parallel auf Handy/Laptop mit.

## 5. Auswerte-Workflow (Laptop)

```bash
# 1. 360-File in links/rechts reframieren (Insta360 Studio, Export 2× 4K)
# 2. Frames extrahieren, nur I-Frames für OCR-Crops
ffmpeg -i front.mp4 -vf fps=2 front_%05d.jpg
# 3. Timestamps (Creation-Time + fps) auf NMEA-Track mappen (Python-Skript, Toleranz ±100 ms)
# 4. Punkte mit Foto-Link nach QGIS (GeoJSON-Vorlage: parkzonen_beispiel.geojson)
```

Kennzeichen-Crops aus I-Frames ziehen (H.265 frisst an P-Frames Kanten), manuell labeln →
füttert `parkzonen_beispiel.geojson` und wird später YOLO-Trainingsmaterial.

## 6. Abnahme PoC

* [ ] 30-min-Trockenfahrt: alle Frames einer Pose zuordenbar, RTK-Fixed-Anteil dokumentiert
* [ ] 10 Stellen mit Maßband-Gegenmessung der Gehweg-Restbreite (Foto-Schätzung vs. Band)
* [ ] QGIS: Track + 1 Halteverbots-Linie + 5 gelabelte Fälle
* [ ] Entscheidung: welche Brennweite/Position funktioniert → erst dann Profi-Kameras kaufen

Danach weiter mit Iteration 2–3 aus `SCANBIKE_Umsetzungsplan.md` (Jetson, Event-Pipeline).

---

## Quellen

[^1]: mpb – gebrauchte Insta360 X3, 179–294 €. <https://www.mpb.com/de-at/produkt/insta360-x3>
[^2]: kleinanzeigen – GoPro Hero 10 Black gebraucht, ca. 170–300 € je Zustand. <https://www.kleinanzeigen.de/s-gopro-hero10/k0>
[^3]: GoPro Telemetry Extractor – Hero 12 ohne GPS-Option (Hero 11 letzte mit GPS). <https://goprotelemetryextractor.com/blog/go-pro-hero-12-gps-option-missing>
