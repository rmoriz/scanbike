# Scanbike – Software-Architektur
## Edge + Backend für beweissichere Falschparker-Erfassung

**Gehört zu:** `SCANBIKE_Architektur.md`

---

## 1. Leitprinzipien

1. **Anonymize-first:** Gesichter/Kennzeichen Unbeteiligter verlassen nie das Fahrzeug. Nur Verdachts-Events werden übertragen – analog zu ARGOS „Auswertung im Fahrzeug“ [^1].
2. **Mensch entscheidet:** Kein Bescheid ohne Sachbearbeiter-Freigabe (Art. 22 DSGVO [^2]).
3. **Beweis statt Bauchgefühl:** Jedes Event mit Zeit, Pose, Kalibrierung, Hash.
4. **Offline-fähig:** Volle Erfassung ohne Netz, Upload als Warteschlange.
5. **Datenminimierung:** Ringpuffer statt Dauerarchiv; Nichttreffer sofort löschen [^3][^4].

## 2. Gesamt-Stack

```
EDGE (Jetson Orin NX, Ubuntu 22.04, Docker)
 capture (GStreamer) -> sync/time -> anonymize -> detect -> ocr
        -> localize/fusion -> rule-prefilter -> event-store -> uploader

BACKEND (Hetzner/kommunales RZ, Docker Compose / k3s)
 ingest -> GIS-rule-engine (PostGIS) -> permit-match -> review-UI
        -> export OWiG -> audit-log + retention-cleaner
```

Sprachen: Python (Pipeline, Modelle), Rust oder Go (Uploader, Hash), TypeScript/React (Review-UI), SQL (Regeln).

## 3. Edge-Software im Detail

### 3.1 Basis

* OS: Jetson Linux (Ubuntu 22.04), JetPack 6, Chrony mit GNSS-PPS
* Middleware: ROS 2 Jazzy nur für Recording/Sync (`rosbag2`, `ublox`-/`nmea`-Treiber [^5]), Inferenz bewusst ohne ROS (GStreamer + TensorRT direkt = weniger Latenz)
* Container: `capture`, `perception`, `fusion`, `store`, `ui-edge` (je 1 Docker, Updates via Mender/OSTree)
* Modelle: Ultralytics YOLOv8 (anchor-free, Echtzeit, n/s/m-Varianten [^6]) als Basis, TensorRT FP16/INT8 kompiliert

### 3.2 Pipeline-Stufen

**A. Capture (10–15 fps Scan, 1 fps Transit)**
* GStreamer `nvarguscamerasrc`/`aravissrc` → NVMM → JPEG + H.264-Proxy
* Pro Frame: `frame_id, cam_id, hw_timestamp, sys_timestamp, exposure, gain`
* Ringpuffer 60 s im RAM (tmpfs), Platte nur bei Event

**B. Time-Sync & Pose**
* GNSS (ZED-F9P, 10 Hz) + IMU (100 Hz) + Odometrie → EKF (robot_localization)
* Output: 50 Hz Pose + Kovarianz + `RTK-Fixed/Float/Single`
* Frames ohne Pose (±50 ms) werden verworfen – keine haltlose Anschuldigung

**C. Anonymize-first (vor Speicherung!)**
* YOLOv8n-face → Blur Gesichter + Fahrradfahrer
* Kennzeichen Unbeteiligter (Gegenfahrbahn, zu weit) → Blur, außer Zielfahrzeug im Verdachts-Polygon
* Erst danach darf ein Frame auf NVMe

**D. Perception (Jetson Orin NX 16 GB: bis 100 TOPS @10–25 W [^7], Super bis 157 TOPS [^8])**
* `yolov8m-seg` (Fahrzeug-Segmentierung) → Maske pro parkendem Fahrzeug
* `yolov8s-licenseplate` (Custom-Training auf deutschen EU-Kennzeichen, 3–8 m Distanz) → Box + Crop
* `yolov8s-sign` (Z. 283/286, Behinderten-/E-Schild, Feuerwehrzufahrt) → Stützinformation
* `curb-seg` (Bordstein, Gehweg, Radweg-Markierung,pretrained + Feintuning) → Geometrie
* Budget: 4×1080p@12 fps ≈ 35–45 ms/Frame auf Orin NX (FP16), parallel OCR

**E. OCR**
* Crop → Deblur/Super-Res → OCR (RapidOCR / PaddleOCR + deutsche Plate-Heuristik: 1–3 Buchstaben, E/H-Suffix, FE-Schrift-Toleranz)
* Output: Text + Konfidenz. Schwelle: <0,85 → „unsicher“, Review muss manuell lesen
* Profi-Referenz: VITRONIC/Jenoptik lesen mehrspurig bei Fahrt/Wetter [^9][^10] – Scanbike-Ziel einfacher (nah, langsam), aber deutsche Umlaute/Stadt-Kürzel als Wörterbuch hinterlegen

**F. Fusion & Regel-Vorfilter Edge**
* Projiziere Fahrzeug-Maske via Kalibrierung + Pose in Weltkoordinaten
* Grobregeln Edge (schnell, recall-orientiert):
  * `auf_gehweg = maske ∩ gehweg_polygon > 30 %`
  * `restbreite < 1,50 m` (Ultraschall/LiDAR oder Bildschätzung)
  * `in_halteverbot_polygon` (grobes GIS-Cache auf Edge, 500 m-Kachel)
* Nur wenn eine Regel feuert → Event erzeugen. Sonst Frame verwerfen.

**G. Event-Store**
* SQLite/WAL: `events(event_id, ts, pose, rule, plate, conf, media_paths, hash)`
* Media: `kontext.jpg` (Front/Seite weit) + `plate_crop.jpg` + optional 5 s `.mp4`
* Hash SHA-256 über Bilder+Metadaten sofort, Signatur mit Geräte-Key (TPM)
* Upload-Queue: priorisiert, Resume bei Funkloch, kein Löschen vor Server-ACK

### 3.3 Edge-Konfiguration (Beispiel)

```yaml
cameras: {left: {fps_scan: 12, exposure_max: 1/1000}, right: {...}, front: {...}}
gnss: {rate_hz: 10, require_fix: [RTK-Fixed, RTK-Float], max_age_ms: 100}
ocr: {min_conf: 0.85, allow_manual: true}
retention_ram_s: 60
retention_disk_untriaged_h: 48
uploader: {batch: 5, tls: true, vpn: wireguard}
```

## 4. Backend-Architektur

### 4.1 Dienste (Compose)

* `ingest-api` (FastAPI): nimmt Events, prüft Signatur/Hash, legt in `events` an
* `gis-engine` (PostGIS): finale Regelprüfung gegen amtliche Polygone
* `permit-service`: Abgleich Kennzeichen ↔ Bewohner/Parkschein/E-Ausnahme (nur Hash-Vergleich, kein Vollzugriff)
* `review-ui` (React + MapLibre): Freigabe/Ablehnung, Korrektur OCR, Begründung
* `export-owig`: XML/PDF an Fachverfahren (OWI21/IKOL), inkl. Bilder + Track
* `retention-cleaner` (Cron): löscht Nichttreffer <72 h, protokolliert Löschung
* `audit-log` (append-only): wer hat wann was freigegeben

### 4.2 Datenmodell (vereinfacht)

```sql
events(id, ts_utc, geom, rule_type, plate_text, ocr_conf, status);
media(event_id, kind, s3_key, sha256);
permits(plate_hash, zone, valid_from, valid_to, type);
zones(id, geom, kind); -- halteverbot, bewohner, e-laden, behindert, feuerwehr
decisions(event_id, reviewer, decision, reason, decided_at);
```

* Kennzeichen in DB nur als salted Hash + Verschlüsselung ruhend (vgl. BW: verschlüsselte Übertragung [^3])
* Rohbilder nur bei `status=verdacht`, Zugriff per Rolle (Sachbearbeiter, DSB-Audit)

### 4.3 GIS-Regelengine

Eingang: Pose + Fahrzeug-Footprint + optional Schilderkennung.
Prüfung in Reihenfolge:

1. Liegt Footprint in `halteverbot`/`feuerwehr`/`kreuzung_5m`? → Treffer
2. Liegt Footprint auf `gehweg`/`radweg`? + Restbreite → Treffer mit Maß
3. Liegt Punkt in bewirtschafteter Zone? → Permit-Abgleich; ohne gültige Berechtigung → Treffer („Schwarzparken“ [^4])
4. Sonst → Nichttreffer → sofort löschen [^3]

Kartenquelle: ALKIS + Verkehrszeichenkataster + manuell gepflegte Hotspot-Layer. Kachel-Cache aufs Edge-Rad für Offline-Vorfilter.

### 4.4 Review-UI (Mensch-in-der-Loop)

Pflichtfelder pro Event: Karte mit Pose+Footprint, Kontextbild, Kennzeichen-Crop (manuell korrigierbar), Regelgrund, GNSS-Qualität, Zeit. Buttons: `Freigeben / Ablehnen / Unscharf-Nachfahrt`. Ablehnung braucht Grund (Trainingsdaten für Modell-Retraining).

Durchsatz-Ziel: <30 s/Event. Bei 100 Events/Schicht ≈ 50 min Sachbearbeitung.

## 5. Schnittstellen

* `POST /v1/events` (Edge→Backend, mTLS + JWT-Gerätezertifikat)
* `GET /v1/zones?bbox=` (Backend→Edge Kachel-Sync, ETag)
* `POST /v1/permits/check {plate_hash, ts, zone}` (intern, kein Klartext-Log)
* `POST /v1/owig/export {event_ids}` (Backend→Fachverfahren)
* NTRIP-Client Edge→SAPOS (RTCM3)

Alle Uhren NTP-synced, Nachweis über Chrony-Logs.

## 6. Datenschutz- und Sicherheitsarchitektur

* DSFA vor Pilot, AV-Vertrag, Rollenkonzept, Verschlüsselung TLS 1.3 + LUKS + S3-SSE
* Löschfristen als Code (`retention-cleaner`): Nichttreffer unverzüglich/≤72 h, Treffer bis Verfahrensende [^3]
* Keine Gesichts-/Personen-DB, kein Tracking über Events hinweg (kein Re-ID)
* Audit-Log unveränderbar, jährlicher DSB-Export
* Rechtliche Leitplanken: § 63g StVG [^11][^12], ADAC-Einordnung Datenminimierung/Zweckbindung [^4], dsn-group-Kritikpunkte [^13], kein Fahndungsabgleich ohne Norm [^14]

## 7. DevOps, Test, Qualität

* Repo-Layout: `edge/`, `backend/`, `models/`, `gis/`, `docs/`
* CI: Lint + Unit + Modell-Eval (Precision/Recall Plate, mAP [^6]) + GIS-Regression (100 annotierte Szenen)
* Testdaten: eigene Aufnahmen mit verpixelten Schildern + synthetische Kennzeichen (keine echten Plates in Git!)
* Kalibrier-Artefakt versioniert, Reprojektionsfehler-Gate <2 px
* Metriken: OCR-Accuracy @0,85, False-Positive-Rate <5 %, Pose-HDOP, Upload-Lag
* Updates OTA via Mender, Rollback-Fähigkeit, Staging-Trike vor Flotte

## 8. Leistungsbudget (Orin NX)

* YOLOv8m-seg FP16 640px: ~25 ms, YOLOv8s-Plate: ~8 ms, Face-Blur n: ~6 ms, OCR: ~15 ms (je Crop) → Pipeline ~55 ms, 12 fps mit 2 Streams parallel machbar. Bei Engpass: auf `n`-Varianten oder DLA ausweichen, Frontkamera niedrigere Rate.
* Referenz Basiswerte YOLOv8 (n/s/m/l/x, mAP vs. Latenz) siehe Ultralytics-Doku [^6]; Orin-Leistung bis 100 TOPS [^7], Super-Modus bis 157 TOPS [^8].

## 9. Stream vs. Frames – Entscheidung: Frames, kein Stream

Es wird **kein Videostream** ins Backoffice übertragen, sondern nur ausgewählte Event-Frames.
Gründe:

* **Bandbreite/Funklöcher:** 4 Kameras als Stream (≈ 8 Mbit/s Dauerlast) sind über LTE am Rad illusorisch. Ein Event (2 JPEGs + Metadaten ≈ 1 MB) geht per Store-and-forward mit Resume — 100 Events/Schicht ≈ 100 MB.
* **Datenschutz:** Ein Dauer-Stream ist laufende Videoüberwachung des öffentlichen Raums und mit Datenminimierung/Zweckbindung kaum vereinbar (vgl. BW-Pilot: nur Verstoß-Daten speichern, Rest unverzüglich löschen [^3]). Ein im Stream übersehenes Gesicht ist bereits übertragen = bereits ein Verstoß. Bei Frames gilt: Blur auf Edge prüfen, dann hochladen; Backend verifiziert den Blur vor der Review-Anzeige ein zweites Mal.
* **Kein Echtzeitbedarf:** Kein Fluchtfahrzeug, keine Schranke — Review in <30 s/Event genügt.

**Frame-Auswahl pro Verdacht (Edge):** Burst von 3–5 Frames puffern, dann wählen —
Kontext-Frame = schärfstes Bild (Laplacian-Varianz, Fahrzeug + Umgebung + ggf. Schild),
Crop-Frame = höchste OCR-Konfidenz. Optional 5-s-Clip (niedrigbitratig, vorgeblurrt) als
Bewegungskontext. Rest des Bursts und alles ohne Verdacht: löschen.

**Ausnahmen:** Debug-Preview im Pilotbetrieb (480p, 1 fps, stark geblurrt, nur auf expliziten
Fernwartungs-Knopf, nicht dauerhaft) sowie Metrik-Herzschlag ohne Bild (Position, Zähler, Status).

---

## Quellen

[^1]: ARGOS Scan-Cars: Auswertung im Fahrzeug, nur Falschparker übertragen. <http://argos-cars.de>
[^2]: Art. 22 DSGVO – Automatisierte Entscheidungen. <https://dsgvo-gesetz.de/art-22-dsgvo>
[^3]: VM Baden-Württemberg – Scan-Fahrzeuge Praxistest: Datenarten, Verschlüsselung, Löschung. <https://vm.baden-wuerttemberg.de/de/politik-zukunft/zukunftskonzepte/digitale-mobilitaet/scan-fahrzeuge-im-praxistest-schnellere-parkraumkontrolle-in-innenstaedten>
[^4]: ADAC – Scan Cars Regeln/Datenschutz: § 63g StVG, 1000 Kennzeichen/h, Datenminimierung. <https://www.adac.de/verkehr/recht/verkehrsvorschriften-deutschland/scan-cars-was-ist-erlaubt>
[^5]: Ardusimple – ZED-F9P in ROS 2 Jazzy integrieren. <https://www.ardusimple.com/tutorials/how-to-integrate-u-blox-zed-f9p-gnss-rtk-receiver-into-ros-2-jazzy>
[^6]: Ultralytics – YOLOv8 Doku: anchor-free, Accuracy-Speed-Tradeoff, Modellvarianten. <https://docs.ultralytics.com/models/yolov8>
[^7]: NVIDIA – Jetson Orin NX bis 100 TOPS (10–25 W). <https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin>
[^8]: Syslogic – Super Mode: NX 157 TOPS/40 W, Nano 67 TOPS. <https://www.syslogic.com/blog/jetson-orin-nano-nx-nvidia-performance-boost-opens-up-new-possibilities>
[^9]: VITRONIC – Automatische Kennzeichenerkennung. <https://www.vitronic.com/de-de/verkehrstechnik/automatische-kennzeichenerkennung>
[^10]: Jenoptik – Kennzeichenerfassung VECTOR. <https://www.jenoptik.de/produkte/zivile-sicherheit/kennzeichenerfassung>
[^11]: GAR NRW – § 63g StVG seit 01.07.2026. <https://gar-nrw.de/news/parkraumkontrolle-per-scan-fahrzeug-was-kommunen-jetzt-wissen-muessen>
[^12]: ihgp-recht – § 63g StVG Erhebung/Löschfristen. <https://ihgp-recht.de/parkraumkontrolle-digital>
[^13]: dsn-group – Scan-Cars Datenschutz. <https://www.dsn-group.de/datenschutz-notizen/scan-cars-in-deutschland>
[^14]: Bundestag Drucksache 21/3505 – Fahndungsabgleich-Debatte. <https://dserver.bundestag.de/btd/21/035/2103505.pdf>
