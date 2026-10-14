# Scanbike

Fahrradbasierte Erfassung von Falschparkern im öffentlichen Raum — auf Basis **Bakfiets CargoTrike**.
Fahrrad-Version eines Scan-Cars: schmal, wendig, für Radwege, Altstadt und Schulvorfelder.
Kein vollautomatisches Knöllchen — das System erzeugt beweissichere Evidence-Pakete,
ein Sachbearbeiter im Ordnungsamt gibt frei.

## Dokumente

| Dokument | Inhalt |
|---|---|
| [SCANBIKE_Architektur.md](SCANBIKE_Architektur.md) | Gesamtarchitektur, Use Cases, Rechtsrahmen (§ 63g StVG), Datenfluss, Roadmap |
| [SCANBIKE_Hardware_Netzwerk_Strom_Steuerung.md](SCANBIKE_Hardware_Netzwerk_Strom_Steuerung.md) | Trike-Aufbau, Sensorik, PoE-/LTE-Topologie, 75-W-Lastbilanz, Betriebsmodi |
| [SCANBIKE_Software_Architektur.md](SCANBIKE_Software_Architektur.md) | Edge-Pipeline (GStreamer + YOLOv8 + OCR auf Jetson Orin NX), Backend (PostGIS, Review-UI, OWiG-Export) |
| [SCANBIKE_Parkzonen_Restbreiten.md](SCANBIKE_Parkzonen_Restbreiten.md) | Zonenkataster, Kartier-Workflow, automatische Restbreitenmessung ohne Absteigen |
| [SCANBIKE_Umsetzungsplan.md](SCANBIKE_Umsetzungsplan.md) | Iterativer Plan in 6 Stufen ab vorhandenem Trike, ohne Wetterschutz |

## Kartier-Artefakte

| Datei | Verwendung |
|---|---|
| [parkzonen_schema.sql](parkzonen_schema.sql) | PostGIS-Schema (EPSG:25832): `zones`, `schilder`, `implizit_verbote`, `restbreiten_messungen` |
| [parkzonen_beispiel.geojson](parkzonen_beispiel.geojson) | 6 Beispiel-Features zum Ausprobieren in QGIS |
| [parkzonen_style.qml](parkzonen_style.qml) | QGIS-Style, kategorisiert nach `kind` |

## Schnellstart

1. Gesamtbild lesen: `SCANBIKE_Architektur.md`
2. Testgebiet in QGIS öffnen: `parkzonen_beispiel.geojson` laden, `parkzonen_style.qml` als Stil laden
3. Echtes Schema anlegen: `psql -d scanbike -f parkzonen_schema.sql`
4. Hardware planen: siehe Hardware-Dokument (MVP ca. 13–20 k€ ohne LiDAR)
5. Rechtliches vor Pilot klären: § 63g StVG, DSFA, Löschkonzept — Details im Architektur-Dokument

## Prinzipien

- **Anonymize-first:** nur Verdachts-Events verlassen das Fahrzeug
- **Mensch entscheidet:** keine automatisierte Entscheidung nach Art. 22 DSGVO
- **Beweis statt Bauchgefühl:** Zeit + Pose (RTK-GNSS) + Kalibrierung + Hash pro Event
