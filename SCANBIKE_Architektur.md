# Scanbike – Gesamtarchitektur
## Fahrradbasierte Erfassung von Falschparkern auf Basis Bakfiets CargoTrike

**Stand:** 14.10.2026 | **Status:** Entwurf | **Fahrzeugbasis:** Bakfiets CargoTrike (Dreirad, 2 vorne / 1 hinten)

Dieses Dokument ist die Klammer über Hardware-Dokument und Software-Dokument. Details siehe:

* `SCANBIKE_Hardware_Netzwerk_Strom_Steuerung.md`
* `SCANBIKE_Software_Architektur.md`

---

## 1. Motivation und Einordnung

Scan-Cars erfassen beim Vorbeifahren bis zu 1000 Kennzeichen pro Stunde und gleichen sie mit Parkberechtigungen ab [1]. Deutsche Städte testen das seit 2025, u. a. in Baden-Württemberg an Universität Hohenheim, Heidelberg, Mannheim, Waldshut-Tiengen und Freiburg [2]. Der Fahrrad-Ansatz schließt die Lücke, die Autos nicht abdecken: Radwege, Gehwege, Einbahnstraßen gegen die Richtung, Altstadtgassen, Parks, Schulvorfelder.

Rechtlich neu: § 63g StVG regelt seit 01.07.2026 bundeseinheitlich Erhebung, Löschfristen und Grenzen der digitalen Parkraumkontrolle mittels Scan-Fahrzeugen [3][4]. Er unterscheidet im Kern zwei Fallgruppen, die auch das Scanbike abbilden muss:

1. **Parken ohne Berechtigung** (Bewohnerzone, Parkschein, E-Ladeplatz, Behindertenplatz)
2. **Allgemein verbotswidriges Halten/Parken** (Gehweg, Radweg, Halteverbot Z. 283/286, Feuerwehrzufahrt, Kreuzungsbereich 5 m, Bordsteinabsenkung)

Ein Scanbike ist rechtlich ein Scan-Fahrzeug ohne Motor – kein Sonderstatus. Die gleichen Anforderungen an Erforderlichkeit, Datenminimierung und unverzügliche Löschung bei Nichttreffern gelten [1][5].

## 2. Ziele und Nicht-Ziele

**Ziele (MVP):**
* Beweissichere Dokumentation von sichtbaren Parkverstößen bei 8–18 km/h Fahrgeschwindigkeit
* Edge-Vorfilterung: nur Verdachtsfälle verlassen das Fahrzeug, Rest wird nach 24–72 h gelöscht
* Mensch-prüft-Maschine: kein vollautomatisches Knöllchen, Sachbearbeiter gibt frei (Art. 22 DSGVO)
* Nachvollziehbarkeit: Zeit (NTP/PTP), Position (RTK-GNSS+IMU), Kalibrierprotokoll pro Evidence-Paket

**Nicht-Ziele (bewusst ausgeklammert):**
* Geschwindigkeits- oder Rotlichtüberwachung
* Fahndungsabgleich mit Polizeidatenbanken (vom Bundesrat diskutiert, nicht beschlossen) [6]
* Dauer-Videoüberwachung des öffentlichen Raums
* Privates Inkasso ohne kommunalen Auftrag

## 3. Warum CargoTrike als Träger

Das Bakfiets CargoTrike ist ein Lasten-Dreirad mit zwei gelenkten Vorderrädern und Box vorne. Herstellerpositionierung: steht auch im Stillstand und bei langsamer Fahrt stabil aufrecht [7]. Varianten Classic Wide: ca. 210 cm lang, ca. 85–95 cm breit, Bodenfläche Box ca. 86×65 cm [8]. Lastendreiräder tragen typischerweise 100–300 kg bei ca. 1 m³ Volumen [9].

Relevanz für Scanbike:

| Eigenschaft | Auswirkung |
|---|---|
| Dreirad, kein Umfallen | Einmalige extrinsische Kamerakalibrierung bleibt gültig, kein Neigungswinkel wie Zweirad |
| Starre Box vorne | Ideale stabile Sensorwanne, kurzer Hebelarm zu Dach |
| Langsam fahrbar 5–15 km/h | Mehr Pixel pro Kennzeichen, weniger Motion Blur |
| Schmal 0,9 m | Befährt Rad-/Gehwegkanten zur Dokumentation der Restbreite |
| E-Antrieb Option | Rangieren mit 80–100 kg Aufbau ohne Ermüdung |
| Nachteil: hart, ungefedert | Global-Shutter + gedämpfte Montage Pflicht, sonst Rolling-Shutter-Artefakte |

## 4. Systemkontext

```
Akteure: Fahrer*in | Ordnungsamt Sachbearbeitung | Datenschutzbeauftragte
         Parkraumbetreiber (Berechtigungs-DB) | IT-Betrieb | Bürger*in (Betroffene)

Scanbike --LTE/5G--> Backend --> Fachverfahren OWiG
    |                    |
    v                    v
Sensor-Rig          Review-Client + GIS-Regelengine + Audit-Log
```

Externe Systeme:
* Parkberechtigungsdatenbank (Bewohner, Parkschein per Kennzeichen, E-/Schwerbehinderten-Ausnahmen)
* Verkehrszeichenkataster / ALKIS / Parkraumkarte (Halteverbote, Ladezonen)
* SAPOS/NTRIP Korrekturdienst für RTK
* OWiG-Fachverfahren (z. B. OWI21, IKOL)

## 5. Funktionsarchitektur (Übersicht)

1. **Erfassung:** 2× Seite + 1× Front + 1× Heck, GNSS-RTK + IMU + Odometrie, optional LiDAR
2. **Synchronisation:** Hardware-Trigger + PTP, gemeinsame Zeitbasis <5 ms
3. **Anonymisierung zuerst:** Gesichter sofort blurren, Umgebung nur bei Verdacht speichern (Privacy-by-Design, vgl. Vorgehen ARGOS: Auswertung im Fahrzeug, nur Falschparker übertragen [10])
4. **Detektion Edge:** Fahrzeug-Segmentierung, Kennzeichen-Box, Schilder, Bordstein/Markierung
5. **OCR:** Kennzeichen-Text + Konfidenz
6. **Lokalisierung:** Pose des Scanbikes + Projektion: steht Zielfahrzeug in Verbots-Polygon?
7. **Event-Filter:** Nur Verdacht erzeugt Evidence-Paket (2 Fotos + optional 5 s Clip + Metadaten)
8. **Übertragung:** verschlüsselt (TLS 1.3, VPN), Warteschlange bei Funkloch
9. **Backend-Prüfung:** GIS-Regelengine + Berechtigungsabgleich + Sachbearbeiter-Freigabe
10. **Löschung:** Nichttreffer unverzüglich, Treffer bis Verfahrensende [2][5]

Referenz zum Stand der Technik: VITRONIC POLISCAN und Jenoptik VECTOR lesen Kennzeichen mehrspurig auch bei Fahrt und schlechtem Wetter [11][12]. Scanbike übernimmt das Prinzip, aber bei niedriger Geschwindigkeit und kürzerer Distanz (3–8 m statt 10–30 m).

## 6. Datenfluss und Evidence-Paket

Pro Verdachtsfall genau ein Paket:

```json
{
  "event_id": "uuid",
  "timestamp_utc": "2026-10-14T...",
  "pose": {"lat": 48.7, "lon": 9.1, "rtk_fix": "RTK-Fixed", "hdop": 0.7},
  "sensors": {"cam_left": "frame_id", "calib_version": "v1.3"},
  "detections": {"plate": "S-AB 1234", "ocr_conf": 0.93, "vehicle_class": "Pkw"},
  "rule": {"type": "Gehwegparken", "polygon_id": "STG-042", "restbreite_m": 0.9},
  "media": ["kontext.jpg", "kennzeichen_crop.jpg"],
  "hash": "sha256..."
}
```

* Bilder: Kontext (Fahrzeug + Umgebung) + Crop (Kennzeichen lesbar)
* Kein Dauerupload. Praxisvorgabe aus BW-Pilot: Kennzeichen verschlüsselt, Personen unkenntlich, keine Zweckentfremdung [2]
* ADAC-Zusammenfassung: nur erforderliche Daten, Zweckbindung Parkvorschriften [1]

## 7. Betriebsmodell

* **Touren:** 2 Schichten à 3–4 h (Akkulimit), 25–40 km, Fokus Hotspots (Schulen, Radwege, Ladezonen)
* **Zweitbefahrung:** bei zeitabhängigen Verstößen (Parkscheibe, Ladezeit) zweite Runde +10–15 min für Dauer-Nachweis
* **Fahrer:** keine hoheitliche Entscheidung, nur Fahrt + Systemstart/Stopp + Sichtprüfung
* **Wartung:** wöchentliche Kalibrier-Kontrolle (Schachbrett + Testrunde), monatliche GNSS-Antennenprüfung

## 8. Recht, Datenschutz, Ethik

Pflicht vor Pilotbetrieb:

* Rechtsgrundlage dokumentieren (§ 63g StVG + Landesrecht, z. B. Landesmobilitätsgesetz BW seit 03/2025 [2]), Zuständigkeit der Kommune
* Datenschutz-Folgenabschätzung (DSFA), AV-Vertrag, Löschkonzept
* Keine automatisierte Entscheidung i. S. v. Art. 22 DSGVO ohne menschliche Prüfung [13]
* Kennzeichnung am Rad („Kommunale Parkraumkontrolle – Kameraaufzeichnung“), Info-Datenschutzerklärung per QR
* Speicher: Treffer bis Verfahrensende, Nichttreffer sofort löschen [2]
* Kritikpunkt aus Datenschutzsicht ausführlich bei dsn-group [5]: Erforderlichkeit, Verhältnismäßigkeit, keine flächendeckende Bewegungsprofile

Empfehlung: erst stationärer Test mit verpixelten Kennzeichen + DSB-Freigabe, dann Straßentest in einer Bewohnerzone.

## 9. Phasen-Roadmap

* **Phase 0 (4 Wochen):** Dachrahmen + 3 Kameras + GNSS-Logger, manuelle Auswertung. Ziel: Bildqualität + Pose beweisen.
* **Phase 1 (8 Wochen):** Jetson + YOLO + OCR Edge, Event-Filter, LTE-Upload, Review-Prototyp
* **Phase 2 (12 Wochen):** GIS-Regelengine + Berechtigungsabgleich + OWiG-Export
* **Phase 3:** LiDAR für Restbreitenmessung, Schilderkennung Z. 283/286, Zweitbefahrungs-Logik

## 10. Kostenrahmen (MVP ohne LiDAR)

 ca. 13–20 k€ Material + Eigenleistung Software (Open Source). Details in Hardware-Dokument.

## 11. Risiken

* GPS-Abschattung Innenstadt → ohne IMU/Odometrie keine haltbare Zuordnung
* Schilderkennung bei Verdeckung → GIS-Polygon muss führen, Kamera nur stützen
* Akzeptanz/Vandalismus → neutrales Design, keine „Straf-Rad“-Optik
* Wetter (Regen/Gegenlicht) → IP65-Hauben, HDR-Kameras, Reinigungsplan

---

## Quellen

[1] ADAC – Scan Cars: Was ist erlaubt? Regeln und Datenschutz – Rechtsgrundlage § 63g StVG, bis 1000 Kennzeichen/h, Kennzeichen als personenbezogene Daten, Datenminimierung. https://www.adac.de/verkehr/recht/verkehrsvorschriften-deutschland/scan-cars-was-ist-erlaubt
[2] Ministerium für Verkehr Baden-Württemberg – Scan-Fahrzeuge im Praxistest: erfasste Daten (Bild, Kennzeichen, Ort, Zeit), Verschlüsselung, Unkenntlichmachung, Speicherung nur bei Verstoß bis Verfahrensende, sonst unverzügliche Löschung; Tests Hohenheim/Heidelberg/Mannheim/Waldshut-Tiengen/Freiburg. https://vm.baden-wuerttemberg.de/de/politik-zukunft/zukunftskonzepte/digitale-mobilitaet/scan-fahrzeuge-im-praxistest-schnellere-parkraumkontrolle-in-innenstaedten
[3] GAR NRW – Parkraumkontrolle per Scan-Fahrzeug: § 63g StVG seit 01.07.2026 bundeseinheitlich. https://gar-nrw.de/news/parkraumkontrolle-per-scan-fahrzeug-was-kommunen-jetzt-wissen-muessen
[4] ihgp-recht – Parkraumkontrolle Digital: § 63g StVG regelt Erhebung, Löschfristen, Grenzen. https://ihgp-recht.de/parkraumkontrolle-digital
[5] dsn-group – Scan-Cars in Deutschland: datenschutzrechtliche Einordnung § 63g StVG. https://www.dsn-group.de/datenschutz-notizen/scan-cars-in-deutschland
[6] Bundestag Drucksache 21/3505, S. 11: Bitte um Prüfung Fahndungsabgleich in § 63g StVG. https://dserver.bundestag.de/btd/21/035/2103505.pdf
[7] Bakfiets.nl – Cargobike Models: Trike bleibt auch im Stillstand/langsam stabil aufrecht. https://www.bakfiets.nl/en-en/models
[8] Bakfiets.nl – E-CargoTrike Classic Wide: 210×85 cm, Boden 86×65 cm. https://www.bakfiets.nl/en-en/models/electric-cargo-trike/wide/classic
[9] Wikipedia – Cargo bike: Trikes 100–300 kg, ~1 m³, halbe Kleintransporter-Kapazität. https://en.wikipedia.org/wiki/Cargo_bike
[10] ARGOS Scan-Cars: Auswertung im Fahrzeug, nur Falschparker-Daten übertragen, DSGVO-konform. http://argos-cars.de
[11] VITRONIC – Automatische Kennzeichenerkennung / POLISCAN: Lesen bei Fahrt/Stillstand, mehrere Spuren, schlechtes Wetter. https://www.vitronic.com/de-de/verkehrstechnik/automatische-kennzeichenerkennung
[12] Jenoptik – Automatische Kennzeichenerfassung VECTOR: mehrspurige Erfassung bei hoher Geschwindigkeit. https://www.jenoptik.de/produkte/zivile-sicherheit/kennzeichenerfassung
[13] Art. 22 DSGVO – Automatisierte Entscheidungen im Einzelfall. https://dsgvo-gesetz.de/art-22-dsgvo
[14] WDR – Scan-Autos gegen Falschparker Modellversuch: Kennzeichen-Datenbankabgleich, Verschlüsselung, Löschung korrekt parkender Fahrzeuge. https://www1.wdr.de/nachrichten/scan-cars-falschparker-kontrollieren-100.html
