-- Restaurant candidates discovered via Google Places API (postal code search).
-- Used for research/outreach: which restaurants in an area aren't on the platform yet.
-- Access: service-role only (no RLS policies → public cannot read/write).

CREATE TABLE IF NOT EXISTS restaurant_candidates (
  id                 bigserial    PRIMARY KEY,
  google_place_id    text         UNIQUE NOT NULL,
  name               text         NOT NULL,
  address            text,
  phone              text,
  website            text,
  rating             numeric(3,1),
  user_rating_count  int,
  opening_hours      jsonb,
  types              text[],
  price_level        text,
  latitude           numeric(10,8),
  longitude          numeric(11,8),
  postal_code        text,        -- the search term that produced this result
  google_data        jsonb        NOT NULL DEFAULT '{}',  -- full raw Place object
  status             text         NOT NULL DEFAULT 'new'
                                  CHECK (status IN ('new', 'contacted', 'uploaded', 'rejected')),
  notes              text,
  restaurant_id      bigint       REFERENCES restaurants(id) ON DELETE SET NULL,
  created_at         timestamptz  NOT NULL DEFAULT now(),
  updated_at         timestamptz  NOT NULL DEFAULT now()
);

-- Index for common filter patterns
CREATE INDEX IF NOT EXISTS idx_restaurant_candidates_postal_code
  ON restaurant_candidates (postal_code);

CREATE INDEX IF NOT EXISTS idx_restaurant_candidates_status
  ON restaurant_candidates (status);

CREATE INDEX IF NOT EXISTS idx_restaurant_candidates_restaurant_id
  ON restaurant_candidates (restaurant_id)
  WHERE restaurant_id IS NOT NULL;

-- Auto-update updated_at on row changes
CREATE TRIGGER set_restaurant_candidates_updated_at
  BEFORE UPDATE ON restaurant_candidates
  FOR EACH ROW
  EXECUTE FUNCTION set_updated_at();

-- No RLS enabled: this table is internal/admin-only, accessed via service role key only.
-- If you later want to expose it to authenticated admins, enable RLS and add policies here.
