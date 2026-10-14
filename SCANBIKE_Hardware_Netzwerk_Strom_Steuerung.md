# Scanbike – Hardware, Vernetzung, Stromversorgung und Steuerung
## Detaildokument zur Fahrzeugplattform Bakfiets CargoTrike

**Gehört zu:** `SCANBIKE_Architektur.md` | **Schwester:** `SCANBIKE_Software_Architektur.md`

---

## 1. Fahrzeugbasis

### 1.1 Bakfiets CargoTrike – Annahmen

* Dreirad: 2 gelenkte Vorderräder + 1 Hinterrad, Lenkstabilisator ab Werk [^1]
* Classic Wide: ca. 210 cm lang, ca. 85–95 cm breit, Box-Boden ca. 86×65 cm [^2]; Narrow-Variante ca. 210×~80 cm [^3]
* Eigengewicht >50 kg ohne E-Antrieb [^4]; Lasten-Trikes generell 100–300 kg Tragfähigkeit [^5]
* Vorteil: kippsicher im Stand/langsam [^1] → Kalibrierung stabil, ideal für 8–18 km/h Scan-Tempo

Vor Umbau wiegen und vermessen: zul. Gesamtgewicht, Schwerpunkt mit Aufbau, Bremsleistung (Scheibenbremse empfohlen).

### 1.2 Mechanischer Aufbau

**Prinzip: Box = Wanne, Dach = Rig, kein Eingriff in Rahmen.**

* **Bodenwanne:** 12 mm Siebdruckplatte in Box, darauf 19"-halb-Tray für Akku + Compute (tief = Schwerpunkt unten). Anti-Rutsch, Kondensat-Ablauf.
* **Dachrahmen:** 4× Alu-Profil 20×20 (Item/Motedis), Höhe Oberkante 1,50 m über Boden. Oben Sensorplatte 60×80 cm, 4× Sorbothane-Dämpfer 30 Shore.
* **Wetterschutz:** PETG-Hauben über Kameras (Hydrophob-Beschichtung), Dachplane PVC mit Klarsicht-Fenstern, Kameras schauen unter Traufkante heraus (Regen + Gegenlicht).
* **Antennenmast:** GNSS-Antenne mittig Dach + 10 cm Groundplane (Alublech), Abstand >20 cm zu LTE-Antennen (Entkopplung), USB3-Kabel mit Ferrit (bekannte GNSS-Störung durch USB3/Realsense-Hardware [^6]).
* **Diebstahl/Vandalismus:** alle Schrauben Torx-TR, Akku/Compute abschließbar, AirTag + GPS-Tracker separat.
* **Sichtbarkeit:** umlaufend Reflexfolie (Sicherheit), neutrales Schild „Prototyp – Kameraaufzeichnung (Forschung)“. Kein öffentlicher Auftrag → keine Behörden-Optik, keine Gelbleuchte mit Amts-Anmutung.

Gewichtsbudget (Beispiel Wide mit E-Antrieb):

| Posten | kg |
|---|---|
| Dachrahmen + Hauben | 9 |
| Kameras + Halter (4) | 3 |
| Compute + Switch + Verkabelung | 4 |
| LiDAR optional | 0,9 |
| Zusatzakku 24 V 50 Ah | 12 |
| Fahrer | 80 |
| Reserve | 10 |
| **Summe Aufbau ohne Fahrer** | **~29** |

Mit Fahrer und Trike-Eigengewicht im Rahmen der 100–300 kg-Klasse [^5], aber Bremsprobe Pflicht.

## 2. Sensorik – Auswahl und Montage

### 2.1 Kameras (Pflicht)

Anforderung: Global Shutter (Trike-Vibration + Fahrt), HDR >70 dB, IP65 oder Haube, Hardware-Trigger.

| Pos | Typ | Objektiv | Aufgabe | Distanz |
|---|---|---|---|---|
| Links | 5 MP GS (z. B. Basler daA2500 / Allied Vision Alvium) | 6 mm (~60° HFOV) | Kennzeichen + Bordstein links | 2–7 m |
| Rechts | dto. | 6 mm | Kennzeichen + Bordstein rechts | 2–7 m |
| Front | 8 MP GS / 4K | 4 mm (~80°) | Kontext, Schilder 283/286, Feuerwehrzufahrt | 5–25 m |
| Heck | 5 MP GS | 6 mm | Nachweiskette, zweite Perspektive | 2–10 m |

* Auslösung: 10–15 fps im Scan-Modus, 1 fps im Transit (Strom sparen).
* Belichtung: 1/1000 s bei Tag (Bewegungsunschärfe <1 px bei 5 m/s), nachts IR-Blitz 850 nm gepulst (Achtung: StVZO-Blendverbot, nur indirekt/gepulst, Abstimmung nötig – Profi-ALPR-Kameras nutzen IR-Blitz + Filter [^7]).
* Kalibrierung: intrinsisch (Schachbrett) + extrinsisch (LiDAR-/Laser-Kreuz + Maßband). Versionieren (`calib_v1.3`), bei jedem Evidence-Paket mitloggen.

Warum nicht Rolling-Shutter-Webcam: Vibration + Fahrt = schräge Kennzeichen, OCR bricht ein.

### 2.2 Positionierung

* **RTK-GNSS:** u-blox ZED-F9P, Multiband, GPS+GLONASS+Galileo+BeiDou gleichzeitig, cm-Genauigkeit mit Korrekturdaten, bis 10–20 Hz [^8][^9]. Antenne: u-blox ANN-MB oder Ardusimple Tripleband auf Groundplane.
* **Korrektur:** NTRIP via LTE (SAPOS BW/DE), Fallback PPP-RTK ohne Basis (längere Konvergenz, für Test ok [^10]).
* **IMU:** Bosch BNO085 (Neigung/Kompass) oder VectorNav VN-100 (ab LiDAR-Phase). Montage starr auf Sensorplatte, Achsen dokumentieren.
* **Odometrie (Pflicht ab Iteration 1, ~25 €):** Radimpulse stützen Position und Heading zwischen GNSS-Fixes, frieren die Position im Stand ein (Zero-Velocity-Update, kein Ampel-Schmieren) und überbrücken GNSS-Schatten für 10–30 s. Konkrete Kaufempfehlung:
  * Hall-Sensor-Modul KY-003 (TLE4906L, 5 V, Open-Collector, ~4 €) — kein Prellen wie Reedkontakt, mit Schrumpfschlauch + Heißkleber wetterfest genug für Trockenbetrieb
  * 6× Neodym-Magnet 10×3 mm N35 (~8 €), gleichmäßig am Hinterrad verteilt kleben → 6 Pulse/Umdrehung (bei 2 m/s noch ~5 Hz, fein genug für langsames Schieben und Anfahren)
  * Raspberry Pi Pico (~6 €) als Zähler: Interrupt pro Puls, sendet `ticks, timestamp_ms` per USB-Serial an Jetson — saubere Zeiten ohne GPIO-Jitter am Hauptprozessor
  * Montage: Sensor an Ketten-/Sitzstrebe mit Kabelbindern + Abstandshalter, Luftspalt Magnet↔Sensor 3–8 mm, Kabel entlang Bremszug nach vorne
  * Kalibrierung: Abrolltest (3× 10 m schieben, Mittelwert) → `m_pro_tick` in Config; E-Bike-Tacho nur als Plausibilität, kein Eingriff in den Motor-Kabelbaum (Garantie)
* **Zeitsync:** GNSS-PPS → PTP-Master auf Compute, Kameras via Software-PTP ( GigE) oder Trigger-Board (z. B. Arducam Trigger). Ziel <5 ms Offset, sonst Pose↔Bild-Versatz bei 5 m/s = 2,5 cm pro ms.

Praxis-Hinweis: USB3 stört GNSS L1/L2 – Kabel schirmen, Antenne weg von Compute verlegen [^6].

### 2.3 Abstand/Geometrie (optional Phase 3)

* **MVP ohne LiDAR:** Stereo-Disparität li/re + 2× Ultraschall (MaxBotix) seitlich für Bordsteinabstand + Restgehwegbreite (Genauigkeit ±3 cm bis 4 m).
* **Vollausbau:** Livox Mid-360 (360°×59°, 40 m, 0,9 kg) oder Ouster OS0-32. Misst: steht Fahrzeug auf Gehweg? Restdurchgang? Direkter 3D-Nachweis, wetterfester als reine Bildschätzung.

### 2.4 Sonstige Sensoren

* Temperatur/Feuchte in Elektronikbox (Beweiskette: kein Überhitzen), Neigungssensor Diebstahl, Mikrofon **nicht** verbauen (DSGVO-Risiko).

## 3. Vernetzung (In-Fahrzeug + Funk)

### 3.1 Topologie

```
[Cam Li]--GigE--\
[Cam Re]--GigE---> [PoE-Switch 5p] --1x 10GbE--> [Jetson Orin NX]
[Cam Fr]--GigE--/                        |
[Cam He]--USB3---------------------------+--USB3 Hub aktiv
[ZED-F9P]--USB/UART--> Jetson
[IMU]--UART/I2C--> Jetson
[LiDAR]--GigE--> Switch
[LTE-Router]--Eth--> Jetson + Switch-Mgmt
```

* **Kabel:** GigE-Kameras mit PoE (1 Kabel pro Kamera), USB3 nur kurz (<2 m) aktiv, geschirmt.
* **Switch:** industriell 5–8 Port, PoE+ 30 W/Port, -20…+60 °C, z. B. M12-Variante für Vibration.
* **Funk:** Teltonika RUTX50 (5G/LTE, Dual-SIM, GPS-Passthrough) + 2× MIMO-Dachantenne. VPN WireGuard zum Backend, NTRIP über gleichen Tunnel.
* **Bandbreite:** kein Rohvideo-Upload. Nur Events: 2× JPEG ~800 KB + Metadaten ~50 KB ≈ 1 MB/Event. Bei 100 Events/Schicht = 100 MB – problemlos LTE.
* **Zeitsync draußen:** Chrony mit GNSS-PPS als Stratum-1 auf Jetson, Router als NTP-Client.

### 3.2 Sicherheit Netz

* Kameras in isoliertem VLAN ohne Internet, nur Jetson darf lesen
* SSH nur per Key + Tailscale/WireGuard, kein offener Port
* Plattenverschlüsselung LUKS, Kamerabilder im RAM-Ringpuffer (tmpfs) bis Event-Entscheidung

## 4. Stromversorgung – Lastbilanz und Auslegung

**Designregel: E-Bike-Akku nicht anzapfen.** Eigener Traktions-/Systemakku.

### 4.1 Verbraucher (Dauer Scan-Modus)

| Verbraucher | Leistung | Bemerkung |
|---|---|---|
| Jetson Orin NX 16 GB (10–25 W, bis 100 TOPS [^11]) | 25 W peak / 18 W avg | + Super-Modus bis 40 W möglich [^12], aber thermisch meiden |
| 4× Kamera PoE | 4×4 W = 16 W | |
| PoE-Switch | 8 W | |
| LTE-Router | 10 W | |
| ZED-F9P + IMU + Trigger | 4 W | |
| LiDAR (optional) | 14 W | nur Phase 3 |
| Lüfter + Licht + Warnleuchte | 10 W | |
| DC-DC-Verluste 10 % | ~7 W | |
| **Summe ohne LiDAR** | **~75 W** | **mit LiDAR ~90 W** |

### 4.2 Akku-Dimensionierung

Ziel 8 h Schicht ohne Nachladen:

* Energiebedarf: 75 W × 8 h = 600 Wh (+20 % Alterung/ Kälte = 720 Wh)
* Wahl: LiFePO4 24 V 40 Ah = 960 Wh nutzbar ~800 Wh (80 % DoD), 12 kg, 2000+ Zyklen. Alternativ 2× 12 V 50 Ah in Reihe.
* Lichtmaschine/Dynamo sinnlos – reine Batterielösung + abends laden.
* Optional: 60 W Solar-Faltmodul aufs Dach für Standby (kein Scan-Betrieb, nur Erhaltung).

### 4.3 Schaltplan (logisch)

```
[LiFePO4 24V] -> [Hauptschalter + 30A Sicherung] -> [Victron Orion 24/12 DC-DC 20A]
  -> [Verteiler mit Einzel-Sicherungen 5A/7,5A]
     -> Jetson (12V via PD-Trigger), Switch (12V PoE), Kameras (PoE vom Switch)
     -> Router (12V), LiDAR (24V direkt), Licht (12V)
  -> [SmartShunt] -> [Jetson GPIO: Spannung/Strom loggen, bei <22V graceful shutdown]
Ladung: [230V Ladegerät LiFePO4 20A] über Neutrik PowerCon, Ladezeit ~2,5 h
```

* Massepunkt sternförmig, geschirmte Leitungen, Sicherung <20 cm ab Batterie
* Not-Aus (Pilz) griffbereit am Lenker: trennt Systemakku, nicht Fahrakku
* Thermik: Jetson-Kühler + 2× 40 mm Lüfter aus Box heraus, Luftfilter gegen Staub

## 5. Steuerung und Betriebsmodi

### 5.1 Modi (Drehschalter + Web-UI)

* **AUS:** alles stromlos, Akku-Trennschalter offen
* **TRANSIT:** nur GNSS-Logger + 1 fps Front, ~25 W
* **SCAN:** alle Kameras 12 fps + Inferenz, ~75 W, Event-Speicherung an
* **REVIEW/STOP:** Upload-Warteschlange abarbeiten, Lüfter nachlaufen
* **SERVICE:** Kalibrier-Overlay, Live-Bilder aller Kameras, Trigger-Test

Umschaltung per beleuchtetem Wahlschalter am Lenker + Bestätigungstaster (Zweihand gegen Fehlbedienung).

### 5.2 Fahrzeugsteuerung (nicht-autonom!)

* Kein Drive-by-Wire. Fahrer fährt, System steuert nur Sensorik.
* Akustisches Feedback: kurzer Piep bei Event (abschaltbar), LED-Balken GNSS-Fix (rot/gelb/grün).
* Safety: bei Unterspannung <22 V oder CPU >85 °C → automatischer Wechsel SCAN→TRANSIT→Shutdown mit Ansage.
* Watchdog: Hardware-Watchdog auf Carrier-Board startet Jetson bei Hänger neu, rosbag wird geschlossen wiederhergestellt.

### 5.3 Inbetriebnahme-Checkliste

1. Reifendruck + Bremsen + Licht (StVZO)
2. Dachschrauben Drehmoment, Hauben sauber
3. GNSS-Fix abwarten (RTK-Fixed, nicht nur 3D)
4. Kalibrier-Version prüfen (`calib_v*.yaml` in Evidence-Header)
5. Test-Event auslösen, Upload + Hash prüfen
6. Schild „Kameraaufzeichnung“ montiert

### 5.4 Wartung

* Täglich: Linsen reinigen, Log auf Fehler sichten
* Wöchentlich: Kalibrier-Kontrolle (1 Runde um Block, Reprojektionsfehler <2 px)
* Monatlich: Sicherung/Schrauben, Akku-Kapazitätstest, Antennen-Sichtprüfung
* Jährlich: Kalibrier-Zertifikat erneuern, DSB-Audit

---

## Quellen

[^1]: Bakfiets.nl – Cargobike Models: Trike stabil im Stillstand/langsam. <https://www.bakfiets.nl/en-en/models>
[^2]: Bakfiets.nl – E-CargoTrike Classic Wide: 210×85 cm, Boden 86×65 cm. <https://www.bakfiets.nl/en-en/models/electric-cargo-trike/wide/classic>
[^3]: Bakfix – CargoTrike Classic Wide: 210×95 cm. <https://bakfix.com/en/bakfiets-nl-cargotrike-classic-wide-trike-2-50261>
[^4]: e-lastenrad.de – Bakfiets Classic Wide ohne E-Antrieb, >50 kg. <https://www.e-lastenrad.de/bakfiets-cargotrike>
[^5]: Wikipedia – Cargo bike: Trikes 100–300 kg, ~1 m³. <https://en.wikipedia.org/wiki/Cargo_bike>
[^6]: u-blox Community – GNSS-Interferenz durch Intel RealSense/USB3-Kompakt-Rover. <https://portal.u-blox.com/s/question/0D5Oj00000r21SyKAI/ublox-zedf9p-how-to-mitigate-gnss-interference-from-intel-realsense-d405-in-ultracompact-rover>
[^7]: Jens / Symphony ALPR – IR-Blitz + Filter für Kennzeichenkameras (Video-Transkript). <https://www.youtube.com/watch?v=34LGZIObibE>
[^8]: u-blox ZED-F9P Datasheet: Multiband RTK, alle 4 Konstellationen gleichzeitig, cm-Genauigkeit. <https://content.u-blox.com/sites/default/files/ZED-F9P-04B_DataSheet_UBX-21044850.pdf>
[^9]: u-blox/NVIDIA Partnership: ZED-F9 RTK cm-genau, robust. <https://www.u-blox.com/en/partnerships/nvidia>
[^10]: MDPI Sensors – Low-Cost GNSS PPP-RTK mit ZED-F9P: PPP-RTK ohne Basis möglich, Konvergenzzeit beachten. <https://www.mdpi.com/1424-8220/23/13/6074>
[^11]: NVIDIA – Jetson Orin NX bis 100 TOPS bei 10–25 W; Nano bis 40 TOPS bei 7–15 W. <https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin>
[^12]: Syslogic – Jetson Orin Super Mode: Nano 67 TOPS/25 W, NX 157 TOPS/40 W, höhere Taktraten. <https://www.syslogic.com/blog/jetson-orin-nano-nx-nvidia-performance-boost-opens-up-new-possibilities>
