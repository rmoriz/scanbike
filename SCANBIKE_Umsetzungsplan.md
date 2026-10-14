# Scanbike – Iterativer Umsetzungsplan

**Stand:** 14.10.2026 | **Gegeben:** Bakfiets CargoTrike vorhanden | **Annahme:** kein Wetterschutz (nur Trocken-Tests, Häuserkampf gegen Regen entfällt vorerst)
**Zugehörige Docs:** `SCANBIKE_Architektur.md`, `SCANBIKE_Hardware_Netzwerk_Strom_Steuerung.md`, `SCANBIKE_Software_Architektur.md`, `SCANBIKE_Parkzonen_Restbreiten.md`

Prinzip: jede Iteration endet mit einer fahrenden, testbaren Stufe. Kein Big Bang.
Wetterschutz (Hauben, Plane, Lüfterfilter) ist bewusst auf Iteration 6+ verschoben —
bis dahin nur bei Trockenheit fahren, Elektronik bei Regen abdecken/abbrechen.

## Übersicht

| # | Iteration | Ergebnis (fahrbar) | ca. Aufwand | ca. Material |
|---|---|---|---|---|
| 0 | Manuelle Baseline | Foto-Doku + GPS-Track + 1. Zone in QGIS | 1 Woche | 0 € (Handy reicht) |
| 1 | Logger-Trike | 3 Kameras + RTK-GNSS loggen synchron auf Laptop | 2–3 Wochen | ~2.500 € |
| 2 | Edge-Sehen | Jetson erkennt Fahrzeuge/Schilder live, nur Zähler | 3–4 Wochen | ~1.500 € |
| 3 | Event-Pipeline | Verdachts-Events mit Bild + Pose + Hash, Upload-Prototyp | 3–4 Wochen | ~500 € |
| 4 | Regel + Review | GIS-Abgleich + Sachbearbeiter-UI, 1. beweissicheres Paket | 4 Wochen | ~0 € (Server/VM) |
| 5 | Restbreite | Automatische Gehweg-Restmessung ±5 cm ohne Absteigen | 3–4 Wochen | ~500 € |
| 6+ | Härtung | Strom-Autonomie 8 h, Wetterschutz, 2. Trike/Replikation | laufend | ~2.000 € |

Recht/Datenschutz läuft parallel ab Iteration 0 (DSB-Gespräch, Testgebiet, Löschkonzept) —
Details siehe `SCANBIKE_Architektur.md` Kap. 8.

---

## Iteration 0 – Manuelle Baseline (1 Woche)

**Ziel:** beweisen, dass Strecke + Zonenkarte + Foto-Doku funktionieren, bevor Geld fließt.

- [ ] Testgebiet 500×500 m festlegen (z. B. um Wohnort, mit Bewohnerzone + Halteverbot)
- [ ] `parkzonen_schema.sql` in PostGIS oder GeoPackage anlegen, `parkzonen_beispiel.geojson` als Vorlage in QGIS laden
- [ ] 1 Befahrung mit Handy: alle Schilder + Buchten fotografieren, GPS-Track (GPX) aufzeichnen
- [ ] 10–20 Parkverstöße manuell in QGIS einzeichnen (Punkt + Foto verlinken)

**Abnahme:** QGIS zeigt Track + 1 Halteverbots-Linie + 1 Gehwegpolygon + 5 dokumentierte Fälle.
**Kosten:** 0 €.

## Iteration 1 – Logger-Trike (2–3 Wochen)

**Ziel:** synchrones Rohmaterial (Bild + cm-Position) vom fahrenden Trike.

Hardware (ohne Wetterschutz — Kameras nur angesteckt, bei Regen Abbruch):
- [ ] Alu-Winkel als provisorischer Kamerabügel auf der Box (Höhe ~1,35 m), gedämpft (Moosgummi reicht vorerst)
- [ ] 2× Seitenkamera + 1× Frontkamera (Global Shutter, gebraucht ok), Laptop statt Jetson (weniger Integrationsaufwand)
- [ ] u-blox ZED-F9P + Antenne mit Groundplane aufs Brett, NTRIP via Handy-Hotspot (SAPOS-Testzugang)
- [ ] USB-Hub aktiv, Kabel mit Ferrit, GNSS-Antenne weg von USB3 (Interferenz! [^1])

Software:
- [ ] GStreamer-Recording 10 fps + GNSS/IMU-Log, gemeinsamer Zeitstempel (Chrony + PPS)
- [ ] `rosbag2` oder plain MP4+CSV — egal, Hauptsache Frame↔Pose ±50 ms zuordenbar

**Abnahme:** 30-min-Trockenfahrt → alle Frames haben Pose, RTK-Fixed-Anteil >80 %, Reprojektions-Check ok.
**Material:** ~2.500 € (Kameras ~1.800, GNSS ~600, Kleinteile ~100).

[^1]: u-blox Community – GNSS-Interferenz durch USB3. <https://portal.u-blox.com/s/question/0D5Oj00000r21SyKAI/ublox-zedf9p-how-to-mitigate-gnss-interference-from-intel-realsense-d405-in-ultracompact-rover>

## Iteration 2 – Edge-Sehen (3–4 Wochen)

**Ziel:** Trike „sieht“ live: Fahrzeuge, Kennzeichen-Boxen, Schilder — noch ohne Speichern/Upload.

- [ ] NVIDIA Jetson Orin NX 16 GB (bis 100 TOPS @10–25 W [^2]) + NVMe, auf Holzbrett in Box (Strom vorerst aus EcoFlow/Verlängerung am Startpunkt bzw. kleiner 12-V-Akku)
- [ ] YOLOv8m-seg (Fahrzeuge) + YOLOv8s-Plate + YOLOv8s-Sign als TensorRT FP16, Evaluierung auf Iteration-1-Material (Precision/Recall) [^3]
- [ ] Nur Live-Overlay + Zähler (z. B. „14 Fahrzeuge, 3 im Gehwegpolygon“), kein Bild speichern (DSB-freundlich)

**Abnahme:** Testrunde: >90 % der parkenden Fahrzeuge erkannt, <10 % False Positives, 10 fps stabil.
**Material:** ~1.500 € (Jetson-Set ~800, NVMe/Kleinteile ~200, gebrauchter Monitor/Tastatur entbehrlich).

[^2]: NVIDIA – Jetson Orin NX. <https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin>
[^3]: Ultralytics – YOLOv8 Doku. <https://docs.ultralytics.com/models/yolov8>

## Iteration 3 – Event-Pipeline (3–4 Wochen)

**Ziel:** aus „Sehen“ werden Events: nur Verdacht wird gespeichert und hochgeladen.

- [ ] Anonymize-first: Face-Blur vor Speicherung; Ringpuffer RAM 60 s, Platte nur bei Event
- [ ] OCR (RapidOCR/PaddleOCR + DE-Heuristik), Schwelle 0,85 → darunter „unsicher“
- [ ] Event-Store (SQLite): `event_id, ts, pose, plate, conf, regel, media, sha256`, Geräte-Signatur
- [ ] LTE-Router (Teltonika o. ä.) + WireGuard, Upload-Queue mit Resume; Server: 20-€-VM mit FastAPI-Ingest
- [ ] Löschjob: Nichttreffer ≤72 h, Rest nur bis Review (vgl. BW-Pilot: Treffer bis Verfahrensende, sonst unverzüglich löschen [^4])

**Abnahme:** 1 Schicht → Events auf Server mit Bild + Pose + Hash, Nichttreffer lokal gelöscht (Log als Nachweis).
**Material:** ~500 € (Router + Antennen + VM).

[^4]: VM Baden-Württemberg – Scan-Fahrzeuge im Praxistest. <https://vm.baden-wuerttemberg.de/de/politik-zukunft/zukunftskonzepte/digitale-mobilitaet/scan-fahrzeuge-im-praxistest-schnellere-parkraumkontrolle-in-innenstaedten>

## Iteration 4 – Regel + Review (4 Wochen)

**Ziel:** erstes beweissicheres Paket inkl. menschlicher Freigabe.

- [ ] GIS-Regelengine (PostGIS, `v_verbote`-View aus `parkzonen_schema.sql`) + Permit-Abgleich per Hash
- [ ] Review-UI (React + MapLibre): Karte + Kontextbild + Crop + Regelgrund + GNSS-Qualität; Buttons Freigeben/Ablehnen
- [ ] OWiG-Export (PDF/XML) an Test-Fachverfahren oder Ordner-Ablage
- [ ] Zweitbefahrungs-Logik für zeitabhängige Fälle (Parkscheibe/Ladezeit, +15 min)

**Abnahme:** 20 echte Events → Sachbearbeiter-Testperson entscheidet in <30 s/Event, Export enthält Zeit/Pose/Kalibrier-Version/Hash.
**Material:** ~0 € (eigene Arbeitszeit, VM läuft).

## Iteration 5 – Restbreite (3–4 Wochen)

**Ziel:** Gehweg-Restbreite automatisch, ohne Absteigen (Detail in `SCANBIKE_Parkzonen_Restbreiten.md` Kap. 8).

- [ ] Depth-Cam (z. B. ZED 2i) oder Stereo-Paar links + 1× Ultraschall rechts als Plausibilität
- [ ] Pipeline: Fahrzeug-Unterkante `A` vs. Wand-/Bordsteinkante `B` → Minimum über 2 m, inkl. Unsicherheit
- [ ] Referenz: 2-m-Latte quer am Trike, monatlicher Selbsttest (Gate: Reprojektionsfehler <2 px)
- [ ] Anzeige: Messlinie im Kontextbild, Wert als `0,92 m ± 0,05 m` in `restbreiten_messungen`

**Abnahme:** 10 Stellen mit Maßband-Gegenmessung → Abweichung ≤5 cm, bei RTK-Float nur „Schätzung“.
**Material:** ~500 € (Depth-Cam oder Ultraschall + Halter).

## Iteration 6+ – Härtung (nach Bedarf)

Erst wenn 0–5 stehen:
- [ ] Strom-Autonomie: LiFePO4 24 V 40 Ah (~960 Wh) für 8-h-Schicht bei ~75 W (Rechnung im Hardware-Dok)
- [ ] Wetterschutz: Hauben, Plane, Lüfterfilter, IP65-Deckel (bis dahin: Schönwetter-Betrieb)
- [ ] Mender/OSTree-Updates, Watchdog, 2. Trike aus Image klonen
- [ ] DSB-Abnahme, Kalibrier-Zertifikat jährlich, Flottenbetrieb

## Risiken pro Iteration

| Risiko | Trifft | Gegenmittel |
|---|---|---|
| Regen ohne Hauben | 1–5 | nur trocken fahren, Elektronik-Schnellabdeckung (Müllsack-Prinzip), Abbruchkriterium |
| GNSS-Schatten Innenstadt | 1, 3–5 | IMU+Odometrie, „unsicher“-Label statt Treffer |
| Zonenkarte unvollständig | 0, 4 | klein starten (1 Gebiet), Version pinnen (`map_version` im Event) |
| OCR bei Dreck/Dämmerung | 3 | Konfidenzschwelle + manuelle Lesung im Review |
| Akku leer nach 2 h | 2–3 | vorerst verkürzte Runden, Autonomie erst in 6 |
