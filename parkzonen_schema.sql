-- Scanbike Parkzonen-Schema (PostGIS, EPSG:25832 ETRS89/UTM32N für BW)
-- Version: v1.0, 2026-10-14
-- Verwendung: psql -d scanbike -f parkzonen_schema.sql

CREATE EXTENSION IF NOT EXISTS postgis;

--/dt Zonen: Erlaubnisse + explizite Verbote + abgeleitete Polygone
CREATE TABLE zones (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind          TEXT NOT NULL CHECK (kind IN (
    'bewohner','parkschein','e_laden','behindert','carsharing',
    'ladezone','halteverbot','eingeschraenktes_halteverbot',
    'feuerwehr','bushalt','gehweg','radweg','fahrbahn','bucht'
  )),
  geom          GEOMETRY(Geometry, 25832) NOT NULL,
  seite         TEXT CHECK (seite IN ('links','rechts','beide','flaeche')),
  zone_name     TEXT,                       -- z.B. 'S-Nord', 'Parkschein Zone 4'
  zeitregel     JSONB NOT NULL DEFAULT '{}',-- {"mo_fr":"09-18","max_min":120,"modus":"bewohner_oder_ticket"}
  quelle        TEXT NOT NULL DEFAULT 'manuell', -- alkis/osm/schilderkataster/mapping_mode
  map_version   TEXT NOT NULL DEFAULT 'v0.1',
  gueltig_ab    DATE NOT NULL DEFAULT CURRENT_DATE,
  gueltig_bis   DATE,
  notiz         TEXT,
  erfasst_am    TIMESTAMPTZ NOT NULL DEFAULT now(),
  erfasst_von   TEXT
);
CREATE INDEX zones_geom_gix ON zones USING GIST (geom);
CREATE INDEX zones_kind_idx ON zones (kind);
CREATE INDEX zones_version_idx ON zones (map_version);

-- Schilder: Punkte mit Wirkrichtung, Wirkstrecke wird als Zone fortgeführt
CREATE TABLE schilder (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  typ           TEXT NOT NULL, -- '283-10','283-11','286','290','314','1048-10' etc.
  geom          GEOMETRY(Point, 25832) NOT NULL,
  blickrichtung_deg REAL,      -- 0=N, 90=O
  wirkseite     TEXT CHECK (wirkseite IN ('links','rechts')),
  wirklaenge_m  REAL,          -- bis Einmündung/Schild, NULL=unbekannt
  foto_key      TEXT,
  map_version   TEXT NOT NULL DEFAULT 'v0.1',
  erfasst_am    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX schilder_geom_gix ON schilder USING GIST (geom);

-- Implizite Verbote (generiert, nicht handgezeichnet) z.B. Kreuzung 5m, Bordsteinabsenkung
CREATE TABLE implizit_verbote (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grund         TEXT NOT NULL CHECK (grund IN (
    'kreuzung_5m','bordsteinabsenkung','haltestelle_15m','sperrflaeche','kurve_unuebersichtlich'
  )),
  geom          GEOMETRY(Geometry, 25832) NOT NULL,
  quelle_id     TEXT, -- Kreuzungs-Node-ID, Haltestellen-ID
  map_version   TEXT NOT NULL DEFAULT 'v0.1'
);
CREATE INDEX implizit_geom_gix ON implizit_verbote USING GIST (geom);

-- Messungen: Restbreiten-Nachweise pro Event (vom Rad, ohne Absteigen)
CREATE TABLE restbreiten_messungen (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL,
  messzeit_utc  TIMESTAMPTZ NOT NULL,
  art           TEXT NOT NULL CHECK (art IN ('gehweg_rest','fahrbahn_rest','radweg_rest')),
  breite_m      REAL NOT NULL CHECK (breite_m >= 0 AND breite_m < 20),
  unsicherheit_m REAL NOT NULL DEFAULT 0.05, -- k=1
  methode       TEXT NOT NULL CHECK (methode IN ('lidar','stereo','ultraschall','bild_schaetzung')),
  pose_geom     GEOMETRY(Point, 25832),
  sensor_pose   JSONB, -- {lat,lon,rtk_fix,hdop,heading}
  calib_version TEXT NOT NULL,
  map_version   TEXT NOT NULL,
  roh_key       TEXT -- Pfad zu Scan-Snippet / Pointcloud-Ausschnitt
);

-- View: wirksame Verbote (explizit + implizit) für Matching
CREATE OR REPLACE VIEW v_verbote AS
SELECT id, kind::TEXT AS grund, geom, map_version FROM zones
 WHERE kind IN ('halteverbot','eingeschraenktes_halteverbot','feuerwehr')
UNION ALL
SELECT id, grund, geom, map_version FROM implizit_verbote;

COMMENT ON TABLE zones IS 'Parkzonen-Kataster Scanbike v1.0, Geometrien in EPSG:25832';
