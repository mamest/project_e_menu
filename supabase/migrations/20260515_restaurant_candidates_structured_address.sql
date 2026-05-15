-- Split the compound address column into structured fields.
-- The original `address` column is kept as a full formatted string for display.

ALTER TABLE restaurant_candidates
  ADD COLUMN IF NOT EXISTS street       text,
  ADD COLUMN IF NOT EXISTS city         text,
  ADD COLUMN IF NOT EXISTS country_code text,
  ADD COLUMN IF NOT EXISTS postal_code  text;
