-- Add Google Places integration columns to restaurants.
-- google_place_id: stable Google Places place ID (e.g. ChIJN1t_tDeuEmsRUsoyG83frY4)
-- google_data:     cached snapshot of rating, reviews, photo names, etc.
--                  Refreshed on demand by the restaurant owner.

ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS google_place_id text,
  ADD COLUMN IF NOT EXISTS google_data     jsonb NOT NULL DEFAULT '{}';
