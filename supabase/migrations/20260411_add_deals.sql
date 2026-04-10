-- Migration: add daily deals / promotions system

-- Deals table
CREATE TABLE IF NOT EXISTS deals (
  id bigserial PRIMARY KEY,
  restaurant_id bigint NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  discount_type text NOT NULL DEFAULT 'percentage'
    CHECK (discount_type IN ('percentage', 'fixed')),
  discount_value numeric(6,2) NOT NULL CHECK (discount_value > 0),
  applies_to text NOT NULL DEFAULT 'all'
    CHECK (applies_to IN ('all', 'category', 'item')),
  day_of_week int[],       -- NULL = every day; 1=Mon..7=Sun (ISO weekday)
  valid_from date,
  valid_until date,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Deal → categories (many-to-many)
CREATE TABLE IF NOT EXISTS deal_categories (
  deal_id bigint NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  category_id bigint NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (deal_id, category_id)
);

-- Deal → items (many-to-many)
CREATE TABLE IF NOT EXISTS deal_items (
  deal_id bigint NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  item_id bigint NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  PRIMARY KEY (deal_id, item_id)
);

-- Keep updated_at current on deals
DROP TRIGGER IF EXISTS trg_deals_updated_at ON deals;
CREATE TRIGGER trg_deals_updated_at
  BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- RLS
ALTER TABLE deals           ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_items      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read deals"            ON deals;
DROP POLICY IF EXISTS "Public read deal_categories"  ON deal_categories;
DROP POLICY IF EXISTS "Public read deal_items"       ON deal_items;
DROP POLICY IF EXISTS "Owner manage deals"           ON deals;
DROP POLICY IF EXISTS "Owner manage deal_categories" ON deal_categories;
DROP POLICY IF EXISTS "Owner manage deal_items"      ON deal_items;

CREATE POLICY "Public read deals"
  ON deals FOR SELECT USING (true);

CREATE POLICY "Public read deal_categories"
  ON deal_categories FOR SELECT USING (true);

CREATE POLICY "Public read deal_items"
  ON deal_items FOR SELECT USING (true);

CREATE POLICY "Owner manage deals"
  ON deals FOR ALL
  USING (
    restaurant_id IN (
      SELECT id FROM restaurants WHERE restaurant_owner_uuid = auth.uid()
    )
  );

CREATE POLICY "Owner manage deal_categories"
  ON deal_categories FOR ALL
  USING (
    deal_id IN (
      SELECT d.id FROM deals d
      JOIN restaurants r ON r.id = d.restaurant_id
      WHERE r.restaurant_owner_uuid = auth.uid()
    )
  );

CREATE POLICY "Owner manage deal_items"
  ON deal_items FOR ALL
  USING (
    deal_id IN (
      SELECT d.id FROM deals d
      JOIN restaurants r ON r.id = d.restaurant_id
      WHERE r.restaurant_owner_uuid = auth.uid()
    )
  );
