# Scanbike – Parkzonen-Kataster und automatische Restbreitenmessung

**Gehört zu:** `SCANBIKE_Architektur.md` | **Artefakte:** `parkzonen_schema.sql`, `parkzonen_beispiel.geojson`, `parkzonen_style.qml`
**Stand:** 14.10.2026 | **Koordinatensystem:** EPSG:25832 (ETRS89/UTM32N)

---

## 1. Warum ein Zonenkataster nötig ist

Das Scanbike sieht „da steht ein Auto“, aber erst die Karte sagt „dort darf es nicht stehen“.
Scan-Cars gleichen Kennzeichen mit Parkberechtigungen ab [^1] und speichern bei Verstoß Bild,
Kennzeichen, Ort und Zeit, sonst wird unverzüglich gelöscht [^2]. Das setzt voraus, dass
Verbots- und Erlaubnis-Polygone bekannt sind.

## 2. Layer-Modell (4 Schichten)

1. **Erlaubnisse:** Bucht, Bewohnerzone, Parkschein, E-Laden, Behindertenplatz, Ladezone
2. **Explizite Verbote:** Z.283/286, Z.290, Sperrfläche, Feuerwehrzufahrt (Schilder + Markierung)
3. **Implizite Verbote:** Gehweg, Radweg, Kreuzung 5 m, Bordsteinabsenkung, Bushalt 15 m –
   gelten ohne Schild und müssen abgeleitet werden
4. **Geometrie-Basis:** Bordstein, Fahrbahnrand, Gehwegpolygon aus ALKIS/OSM

Erst `Verbote minus Erlaubnisse` ergibt den Treffer. Das deckt z. B. Gehwegparken ab,
wo meist kein Schild steht.

## 3. Zonentypen

| Typ | Geometrie | Attribute |
|---|---|---|
| `bucht` / `bewohner` / `parkschein` | Polygon / Linien-Puffer | `zone_name, seite, zeitregel(JSON), quelle` |
| `halteverbot` (283) / `eingeschraenktes_halteverbot` (286) | Linie + Wirkrichtung | `von_mast, bis_einmuendung, seite` |
| `sonderplatz` (`e_laden`, `behindert`, `carsharing`, `feuerwehr`) | Polygon | `berechtigung_noetig, max_min` |
| `gehweg` / `radweg` / `fahrbahn` | Polygon | `restbreite_soll_m, quelle: alkis` |
| `schild` | Punkt + Blickrichtung | `typ: 283-10, blickrichtung_deg, foto_key` |
| `implizit_verbote` | Polygon/Linie | `grund: kreuzung_5m, bordsteinabsenkung, haltestelle_15m` |

OSM-Vorbild für straßenbegleitendes Parken: `parking:left/right/both=lane/street_side/on_kerb/half_on_kerb/no`
mit `orientation=parallel/perpendicular` [^3]; neues Schema nach 2022 nutzt `parking:side` [^4][^5].
Für Scanbike eigene PostGIS-Tabellen führen — OSM ist zu lückenhaft für Bußgeld.
ALKIS liefert Flurstücke, Nutzung, Gebäude und Hausnummern als Basis [^6][^7],
aber keine Halteverbote — dafür Verkehrszeichenkataster + eigene Befahrung.

## 4. Datenmodell

Volles DDL in `parkzonen_schema.sql`. Kern:

```sql
zones(id, kind, geom, seite, zone_name, zeitregel JSONB, quelle, map_version, gueltig_ab, gueltig_bis)
schilder(id, typ, geom POINT, blickrichtung_deg, wirkseite, wirklaenge_m, foto_key, map_version)
implizit_verbote(id, grund, geom, quelle_id, map_version)
restbreiten_messungen(id, event_id, art, breite_m, unsicherheit_m, methode, pose_geom, calib_version, map_version)
VIEW v_verbote AS zones(halteverbot...) UNION implizit_verbote
```

Regeln: Jede Tour referenziert `map_version` im Evidence-Paket (sonst angreifbar).
Kennzeichen in DB nur als salted Hash, Rohbilder nur bei Verdacht.

Beispiel-Zeitregel:

```json
{"modus": "bewohner_oder_ticket", "zone": "S-Nord", "zeit": "Mo-Fr 09-18", "max_min": 120}
```

## 5. Beispiel

`parkzonen_beispiel.geojson` enthält 6 Features (Bucht, Halteverbots-Linie 40 m,
Gehwegpolygon, E-Laden, Schild 283-10, Kreuzung-5m-Polygon). Schema:

```
Bordstein ──Gehweg── ║ H H H ║ ──Fahrbahn──
                     ^^ Schild 283-10 (Punkt)
XXXXXXXXXXXX Wirkstrecke 40 m (Linie, links) XXXXXX
[____ Bewohner-Bucht P1 (Polygon) ____]
```

QGIS: GeoJSON laden → `parkzonen_style.qml` laden (kategorisiert nach `kind`:
rot = 283, orange-gestrichelt = 286, blau = Bewohner, grün = Parkschein,
lila = E-Laden, grau-schraffiert = Gehweg) → als GeoPackage speichern.

## 6. Erfassungs-Workflow

1. **Import (1 Tag/Stadtteil):** ALKIS-WFS + OSM-Export + Schilderliste Tiefbauamt +
   Bewohnerzonen-Shape in QGIS laden.
2. **Mapping-Mode mit Trike:** langsam fahren, Frontkamera alle 2 m Foto. Im Review-Tool
   Schild anklicken → Punkt + Wirkstrecke als Linie bis nächste Einmündung verlängern.
   Gehwegpolygone per Bordstein-Segmentierung vorschlagen, manuell bestätigen.
3. **Implizite Verbote per Script ableiten (nicht handzeichnen):**
   Kreuzungspuffer 5 m, Haltestelle 15 m aus GTFS, Bordsteinabsenkung 3 m beidseitig,
   Gehwegpolygon minus erlaubte `on_kerb`-Abschnitte = Rest = Verbot.

## 7. Matching zur Laufzeit

1. Edge hält 500-m-Kachel offline (vereinfacht).
2. Fahrzeug-Footprint (Segmentierungsmaske → Welt) verschneiden:
   `footprint ∩ halteverbot > 0,3 m² → Verdacht`,
   `footprint ∩ gehweg > 30 % → Verdacht + Restbreite messen`.
3. Backend prüft final exakt + Permit-Abgleich (Bewohner/Parkschein-Hash).
4. Ohne `RTK-Fixed/Float` kein Treffer, nur „unsicher“ loggen (Zonen-Grenzen!).

### 7.1 Irreguläre Parkwinkel (z. B. 90° zum Radweg)

Kein Sonderfall nötig: Das Matching ist maskenbasiert, die Orientierung ist egal. Quersteller
erzeugen großen Polygon-Overlap → Treffer eher zuverlässiger als knapp parkende Parallelparker.
Optional Winkel per OBB mitloggen als Label („quer über Radweg“) für Review und Statistik.
Restbreite als Minimum über die Messstrecke (Hindernis + 1 m beidseitig), nicht mitteln.
Kennzeichen: beide Platten (Front + Seite) suchen, beste Konfidenz gewinnt; unlesbar → Event mit
„Platte unlesbar“, Sachbearbeiter entscheidet anhand Kontextbild. Halb-halb-Fälle (Gehweg +
Fahrbahn): beide Overlaps prüfen, ein Event mit zwei Regelgründen.

## 8. Restbreite automatisch messen ohne Absteigen

### 8.1 Was zählt

* **Gehweg-Rest:** Außenkante Auto → Hauswand/Hecke (Soll 1,2–1,5 m für Rollstuhl/Kinderwagen).
* **Fahrbahn-Rest:** für Rettungsfahrzeuge ca. 3,05 m.
* Gemessen wird die kürzeste Senkrechte zwischen `A = Fahrzeug-Außenkante` und
  `B = Hindernis` in Bodenprojektion, während das Trike parallel vorbeifährt.

### 8.2 Sensorvergleich

| Methode | Genauigkeit | Kosten | Urteil |
|---|---|---|---|
| 2× Ultraschall seitlich | ±3 cm bis 4 m | ~80 € | nur 1 Punkt, gut als Redundanz |
| Stereo (2× Global-Shutter, 12 cm Basis, seitlich) | ±2–4 cm bis 6 m | vorhanden | MVP: nutzt eh vorhandene Kameras |
| Depth-Cam (z. B. ZED 2i) seitlich | ±2 cm bis 8 m | ~500 € | schnellster MVP, ROS-2-Treiber fertig |
| LiDAR (Livox Mid-360 quer) | ±2 cm bis 40 m | ~800 € | Vollausbau, 3D-Beweis |

Empfehlung: MVP = Stereo/Depth links + 1× Ultraschall rechts zur Plausibilisierung.
Vollausbau = LiDAR quer unter Dach; dichter 2D-Scan durch Akkumulation via Odometrie.

### 8.3 Pipeline (Edge)

1. Fahrzeugmaske (YOLO-seg) → Unterkante = Reifenaufstandslinie `A`.
2. Gegenlinie `B`: Gehweg-Hinterkante via Segmentierung + Stereo-Disparität;
   bei LiDAR RANSAC-Ebenen Wand/Boden.
3. Beide Linien in Weltkoordinaten (Pose RTK + Kalibrierung), Senkrechte über 2 m
   mitteln, Minimum nehmen.
4. Speichern in `restbreiten_messungen`:
   `breite_m + unsicherheit_m + methode + calib_version + Pointcloud-Ausschnitt`,
   Messlinie ins Kontextbild einblenden für Sachbearbeiter.

### 8.4 Beweissicherung und Fehlerbudget

* Kalibrierung monatlich gegen Referenz (2-m-Latte quer am Trike, automatisch erkannt),
  Gate: Reprojektionsfehler < 2 px, sonst kein Scan-Modus.
* Immer `breite ± unsicherheit` loggen, z. B. `0,92 m ± 0,05 m`.
* Bei `RTK-Float/Single`, Regen/Gegenlicht oder Verdeckung nur „Schätzung“, kein Treffer.
* GNSS-Störer beachten: USB3-Kabel schirmen, Antenne mit Abstand zu Compute [^8].

---

## Quellen

[^1]: ADAC – Scan Cars: Was ist erlaubt? Bis 1000 Kennzeichen/h, § 63g StVG, Datenminimierung.
<https://www.adac.de/verkehr/recht/verkehrsvorschriften-deutschland/scan-cars-was-ist-erlaubt>
[^2]: VM Baden-Württemberg – Scan-Fahrzeuge im Praxistest: Bild/Kennzeichen/Ort/Zeit,
Verschlüsselung, Löschung. <https://vm.baden-wuerttemberg.de/de/politik-zukunft/zukunftskonzepte/digitale-mobilitaet/scan-fahrzeuge-im-praxistest-schnellere-parkraumkontrolle-in-innenstaedten>
[^3]: OSM Wiki – Street parking (Tagging-Tabelle lane/street_side/on_kerb).
<https://wiki.openstreetmap.org/wiki/Street_parking>
[^4]: OSM Wiki – Tag:parking=lane. <https://wiki.openstreetmap.org/wiki/Tag:parking%3Dlane>
[^5]: OSM Wiki – Key:parking:lane (both/left/right, 2022 neu geordnet).
<https://wiki.openstreetmap.org/wiki/Key:parking:lane>
[^6]: IOER Monitor – ALKIS: bundeseinheitliches Liegenschaftskataster aus ALK+ALB (AdV).
<https://www.ioer-monitor.de/en/methodology/glossary/a/alkis>
[^7]: CLGE – The ALKIS Approach (AFIS-ALKIS-ATKIS, GeoInfoDok, NAS).
<https://www.clge.eu/wp-content/uploads/2012/05/alkis.pdf>
[^8]: u-blox Community – GNSS-Interferenz durch USB3/Realsense bei Kompakt-Rovern.
<https://portal.u-blox.com/s/question/0D5Oj00000r21SyKAI/ublox-zedf9p-how-to-mitigate-gnss-interference-from-intel-realsense-d405-in-ultracompact-rover>
