-- Table that controls which languages the platform translates menus into.
-- English (en) is always required and cannot be deleted.
-- Adding a row here is the signal to run the backfill-language edge function.

CREATE TABLE IF NOT EXISTS supported_languages (
  code        text PRIMARY KEY,          -- BCP-47 language code, e.g. 'en', 'de', 'fr'
  name        text NOT NULL,             -- Human-readable name, e.g. 'English'
  is_required boolean NOT NULL DEFAULT false,  -- true = cannot be removed (English)
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Row-level security: publicly readable, only service role can write
ALTER TABLE supported_languages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supported_languages_select"
  ON supported_languages FOR SELECT
  USING (true);

-- Seed the two initial languages
INSERT INTO supported_languages (code, name, is_required) VALUES
  ('en', 'English', true),
  ('de', 'German',  false)
ON CONFLICT (code) DO NOTHING;
