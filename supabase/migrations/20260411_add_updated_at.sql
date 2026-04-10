-- Migration: add updated_at to all tables + menu_updated_at bubble-up on restaurants
-- Run this once in the Supabase SQL editor.

-- 1. Add updated_at columns
ALTER TABLE restaurants   ADD COLUMN IF NOT EXISTS updated_at     timestamptz DEFAULT now();
ALTER TABLE restaurants   ADD COLUMN IF NOT EXISTS menu_updated_at timestamptz;
ALTER TABLE categories    ADD COLUMN IF NOT EXISTS updated_at     timestamptz DEFAULT now();
ALTER TABLE items         ADD COLUMN IF NOT EXISTS updated_at     timestamptz DEFAULT now();
ALTER TABLE item_variants ADD COLUMN IF NOT EXISTS updated_at     timestamptz DEFAULT now();

-- 2. Generic trigger function: keep updated_at current on every UPDATE
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_restaurants_updated_at   ON restaurants;
DROP TRIGGER IF EXISTS trg_categories_updated_at    ON categories;
DROP TRIGGER IF EXISTS trg_items_updated_at         ON items;
DROP TRIGGER IF EXISTS trg_item_variants_updated_at ON item_variants;

CREATE TRIGGER trg_restaurants_updated_at
  BEFORE UPDATE ON restaurants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_items_updated_at
  BEFORE UPDATE ON items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_item_variants_updated_at
  BEFORE UPDATE ON item_variants
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 3. Bubble-up: any change in categories → restaurants.menu_updated_at
CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_category()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_rid bigint;
BEGIN
  v_rid := COALESCE(NEW.restaurant_id, OLD.restaurant_id);
  UPDATE restaurants SET menu_updated_at = now() WHERE id = v_rid;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_categories_bubble_menu ON categories;
CREATE TRIGGER trg_categories_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON categories
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_category();

-- 4. Bubble-up: any change in items → restaurants.menu_updated_at (via category)
CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_item()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cid bigint;
BEGIN
  v_cid := COALESCE(NEW.category_id, OLD.category_id);
  UPDATE restaurants r
  SET menu_updated_at = now()
  FROM categories c
  WHERE c.id = v_cid AND r.id = c.restaurant_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_items_bubble_menu ON items;
CREATE TRIGGER trg_items_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON items
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_item();

-- 5. Bubble-up: any change in item_variants → restaurants.menu_updated_at (via item → category)
CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_variant()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_iid bigint;
BEGIN
  v_iid := COALESCE(NEW.item_id, OLD.item_id);
  UPDATE restaurants r
  SET menu_updated_at = now()
  FROM items i
  JOIN categories c ON c.id = i.category_id
  WHERE i.id = v_iid AND r.id = c.restaurant_id;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_item_variants_bubble_menu ON item_variants;
CREATE TRIGGER trg_item_variants_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON item_variants
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_variant();

-- 6. Backfill: set menu_updated_at = now() for all restaurants that already have items
UPDATE restaurants r
SET menu_updated_at = now()
FROM categories c
WHERE c.restaurant_id = r.id
  AND r.menu_updated_at IS NULL;
