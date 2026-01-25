-- Supabase seed for categories and items
-- Run this in the Supabase SQL editor (or via psql) to create tables and insert example rows.

BEGIN;

CREATE TABLE IF NOT EXISTS categories (
  id bigserial PRIMARY KEY,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS items (
  id bigserial PRIMARY KEY,
  category_id bigint REFERENCES categories(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric(8,2) NOT NULL,
  description text
);

-- Example categories
INSERT INTO categories (id, name) VALUES
  (1, 'Starters'),
  (2, 'Mains'),
  (3, 'Drinks')
ON CONFLICT (id) DO NOTHING;

-- Example items
INSERT INTO items (category_id, name, price, description) VALUES
  (1, 'Bruschetta', 4.50, 'Toasted bread with tomatoes.'),
  (1, 'Soup of the day', 3.90, 'Ask staff for today''s soup.'),
  (2, 'Margherita Pizza', 8.50, 'Classic tomato & mozzarella.'),
  (2, 'Pasta Carbonara', 9.50, 'Creamy pancetta pasta.'),
  (3, 'Mineral Water', 1.50, 'Still or sparkling.'),
  (3, 'Soda', 2.00, 'Coke, Fanta, Sprite.')
ON CONFLICT DO NOTHING;

-- Reset sequences to the current max id
SELECT setval(pg_get_serial_sequence('categories','id'), COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval(pg_get_serial_sequence('items','id'), COALESCE((SELECT MAX(id) FROM items), 1));

COMMIT;
