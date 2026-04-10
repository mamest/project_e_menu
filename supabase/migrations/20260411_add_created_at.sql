-- Migration: add created_at to categories, items, item_variants
-- (restaurants already has created_at from the seed)

ALTER TABLE categories    ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE items         ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE item_variants ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- Backfill: use updated_at as an approximation for existing rows
UPDATE categories    SET created_at = updated_at WHERE created_at IS NULL;
UPDATE items         SET created_at = updated_at WHERE created_at IS NULL;
UPDATE item_variants SET created_at = updated_at WHERE created_at IS NULL;
