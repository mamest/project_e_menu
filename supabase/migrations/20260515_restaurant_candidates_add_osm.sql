-- Extend restaurant_candidates to support OSM-sourced results alongside Google Places.

-- 1. Make google_place_id nullable — OSM results have no Google ID.
ALTER TABLE restaurant_candidates
  ALTER COLUMN google_place_id DROP NOT NULL;

-- 2. Add osm_id — unique per OSM element (format: "node/123", "way/456", "relation/789").
ALTER TABLE restaurant_candidates
  ADD COLUMN IF NOT EXISTS osm_id text UNIQUE;

-- 3. Add source column to distinguish data origin.
ALTER TABLE restaurant_candidates
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'google'
    CHECK (source IN ('google', 'osm'));

-- 4. Ensure every row has at least one external identifier.
ALTER TABLE restaurant_candidates
  ADD CONSTRAINT restaurant_candidates_has_external_id
    CHECK (google_place_id IS NOT NULL OR osm_id IS NOT NULL);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_restaurant_candidates_osm_id
  ON restaurant_candidates (osm_id)
  WHERE osm_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_restaurant_candidates_source
  ON restaurant_candidates (source);
