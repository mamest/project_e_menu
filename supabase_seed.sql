-- Supabase seed for digital restaurant menu
-- Run this in the Supabase SQL editor (or via psql) to create tables and insert example restaurants.
-- 
-- Restaurant ownership: Each restaurant has a restaurant_owner_uuid that links to auth.users
-- Restaurant owners can edit their own restaurants via Row Level Security policies

BEGIN;

-- Drop existing tables if they exist (clean slate)
DROP TABLE IF EXISTS item_variants CASCADE;
DROP TABLE IF EXISTS items CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS restaurants CASCADE;

-- Restaurants table
CREATE TABLE restaurants (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  address text NOT NULL,
  email text,
  phone text,
  description text,
  image_url text,
  cuisine_type text,
  delivers boolean DEFAULT false,
  opening_hours jsonb,
  payment_methods text[],
  latitude numeric(10, 8),
  longitude numeric(11, 8),
  restaurant_owner_uuid uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- Categories table (each restaurant has its own categories)
CREATE TABLE categories (
  id bigserial PRIMARY KEY,
  restaurant_id bigint NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_order int DEFAULT 0,
  image_url text
);

-- Items table (menu items belong to categories)
CREATE TABLE items (
  id bigserial PRIMARY KEY,
  category_id bigint NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  name text NOT NULL,
  item_number text,
  price numeric(8,2),
  description text,
  image_url text,
  available boolean DEFAULT true,
  has_variants boolean DEFAULT false
);

-- Item variants table (for sizes, options, etc.)
CREATE TABLE item_variants (
  id bigserial PRIMARY KEY,
  item_id bigint NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric(8,2) NOT NULL,
  display_order int DEFAULT 0,
  available boolean DEFAULT true
);

-- Insert example restaurants in Büren, Geseke, Brilon, and Salzkotten
INSERT INTO restaurants (id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods, latitude, longitude, restaurant_owner_uuid) VALUES
  (1, 'Golden Dragon', 'Königstraße 12, 33142 Büren, Germany', 'info@goldendragon.de', '+49 2951 123456', 
   'Authentic Chinese cuisine with traditional flavors',
   'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=800',
   'Chinese',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'PayPal'],
   51.551667, 8.559722, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (2, 'La Bella Vita', 'Bachstraße 8, 59590 Geseke, Germany', 'contact@labellavita.de', '+49 2942 234567', 
   'Traditional Italian restaurant serving homemade pasta and pizza',
   'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
   'Italian',
   true,
   '{"monday": "12:00-23:00", "tuesday": "12:00-23:00", "wednesday": "12:00-23:00", "thursday": "12:00-23:00", "friday": "12:00-00:00", "saturday": "12:00-00:00", "sunday": "Closed"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay', 'Google Pay'],
   51.640556, 8.516389, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (3, 'Taverna Olympia', 'Marktplatz 5, 59929 Brilon, Germany', 'hello@tavernaolympia.de', '+49 2961 345678', 
   'Greek taverna with Mediterranean specialties',
   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800',
   'Greek',
   false,
   '{"monday": "17:00-23:00", "tuesday": "17:00-23:00", "wednesday": "Closed", "thursday": "17:00-23:00", "friday": "17:00-00:00", "saturday": "12:00-00:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'EC Card'],
   51.393889, 8.570278, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (4, 'Sushi Heaven', 'Lange Straße 34, 33154 Salzkotten, Germany', 'info@sushiheaven.de', '+49 5258 456789', 
   'Premium Japanese sushi bar with fresh daily selections',
   'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800',
   'Japanese',
   true,
   '{"monday": "11:30-22:00", "tuesday": "11:30-22:00", "wednesday": "11:30-22:00", "thursday": "11:30-22:00", "friday": "11:30-23:00", "saturday": "12:00-23:00", "sunday": "12:00-21:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay'],
   51.672222, 8.605833, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (5, 'Curry Palace', 'Hauptstraße 45, 33142 Büren, Germany', 'info@currypalace.de', '+49 2951 567890', 
   'Authentic Indian cuisine with traditional tandoori specialties',
   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800',
   'Indian',
   true,
   '{"monday": "12:00-23:00", "tuesday": "12:00-23:00", "wednesday": "12:00-23:00", "thursday": "12:00-23:00", "friday": "12:00-00:00", "saturday": "13:00-00:00", "sunday": "13:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'PayPal', 'Google Pay'],
   51.548889, 8.563611, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (6, 'Le Bistro Parisien', 'Bürener Straße 22, 59590 Geseke, Germany', 'contact@lebistro.de', '+49 2942 678901', 
   'Classic French bistro with elegant dining experience',
   'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800',
   'French',
   false,
   '{"monday": "Closed", "tuesday": "18:00-23:00", "wednesday": "18:00-23:00", "thursday": "18:00-23:00", "friday": "18:00-00:00", "saturday": "18:00-00:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card'],
   51.638333, 8.520556, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (7, 'Taco Fiesta', 'Steinweg 18, 59929 Brilon, Germany', 'hola@tacofiesta.de', '+49 2961 789012', 
   'Vibrant Mexican restaurant with authentic street food',
   'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800',
   'Mexican',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Apple Pay', 'Google Pay'],
   51.396111, 8.567222, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (8, 'Saigon Street Kitchen', 'Vielser Straße 15, 33154 Salzkotten, Germany', 'info@saigonstreet.de', '+49 5258 890123', 
   'Vietnamese street food with modern twist',
   'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=800',
   'Vietnamese',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'PayPal'],
   51.669444, 8.611667, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (9, 'The American Diner', 'Bahnhofstraße 28, 33142 Büren, Germany', 'info@americandiner.de', '+49 2951 901234', 
   'Classic American diner serving burgers, shakes, and comfort food',
   'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
   'American',
   true,
   '{"monday": "10:00-23:00", "tuesday": "10:00-23:00", "wednesday": "10:00-23:00", "thursday": "10:00-23:00", "friday": "10:00-00:00", "saturday": "10:00-00:00", "sunday": "10:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay', 'Google Pay'],
   51.545278, 8.565000, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (10, 'Istanbul Grill', 'Erwitter Straße 42, 59590 Geseke, Germany', 'info@istanbulgrill.de', '+49 2942 012345', 
   'Traditional Turkish grill house with fresh kebabs',
   'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800',
   'Turkish',
   true,
   '{"monday": "10:00-23:00", "tuesday": "10:00-23:00", "wednesday": "10:00-23:00", "thursday": "10:00-23:00", "friday": "10:00-01:00", "saturday": "10:00-01:00", "sunday": "11:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'EC Card'],
   51.635556, 8.523333, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (11, 'Thai Orchid', 'Derkere Straße 12, 59929 Brilon, Germany', 'hello@thaiorchid.de', '+49 2961 123450', 
   'Authentic Thai restaurant with aromatic curries and pad thai',
   'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800',
   'Thai',
   true,
   '{"monday": "12:00-22:00", "tuesday": "12:00-22:00", "wednesday": "12:00-22:00", "thursday": "12:00-22:00", "friday": "12:00-23:00", "saturday": "12:00-23:00", "sunday": "13:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'PayPal'],
   51.390000, 8.573889, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (12, 'Seoul BBQ', 'Upsprunger Straße 8, 33154 Salzkotten, Germany', 'info@seoulbbq.de', '+49 5258 234561', 
   'Korean BBQ restaurant with table grills and banchan',
   'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=800',
   'Korean',
   false,
   '{"monday": "Closed", "tuesday": "17:00-23:00", "wednesday": "17:00-23:00", "thursday": "17:00-23:00", "friday": "17:00-00:00", "saturday": "12:00-00:00", "sunday": "12:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay'],
   51.665833, 8.608611, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2'),
  
  (13, 'Tapas y Vino', 'Alme 7, 33142 Büren, Germany', 'hola@tapasyvino.de', '+49 2951 345672', 
   'Spanish tapas bar with extensive wine selection',
   'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=800',
   'Spanish',
   false,
   '{"monday": "Closed", "tuesday": "17:00-00:00", "wednesday": "17:00-00:00", "thursday": "17:00-00:00", "friday": "17:00-01:00", "saturday": "12:00-01:00", "sunday": "12:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Apple Pay'],
   51.553056, 8.556944, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2')
ON CONFLICT (id) DO NOTHING;

-- Categories for Golden Dragon (Chinese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (1, 1, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop'),
  (2, 1, 'Soups', 2, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop'),
  (3, 1, 'Main Dishes', 3, 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&h=200&fit=crop'),
  (4, 1, 'Beverages', 4, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for La Bella Vita (Italian)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (5, 2, 'Antipasti', 1, 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=600&h=200&fit=crop'),
  (6, 2, 'Pizza', 2, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=200&fit=crop'),
  (7, 2, 'Pasta', 3, 'https://images.unsplash.com/photo-1551183053-bf91798d74b9?w=600&h=200&fit=crop'),
  (8, 2, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&h=200&fit=crop'),
  (9, 2, 'Drinks', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Taverna Olympia (Greek)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (10, 3, 'Mezze', 1, 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=200&fit=crop'),
  (11, 3, 'Grilled Specialties', 2, 'https://images.unsplash.com/photo-1529516548873-9ce57c8f155e?w=600&h=200&fit=crop'),
  (12, 3, 'Traditional Dishes', 3, 'https://images.unsplash.com/photo-1600803907087-f56d462fd26b?w=600&h=200&fit=crop'),
  (13, 3, 'Beverages', 4, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Sushi Heaven (Japanese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (14, 4, 'Nigiri', 1, 'https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=600&h=200&fit=crop'),
  (15, 4, 'Maki Rolls', 2, 'https://images.unsplash.com/photo-1617196034776-f26e5ead5356?w=600&h=200&fit=crop'),
  (16, 4, 'Special Rolls', 3, 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=600&h=200&fit=crop'),
  (17, 4, 'Sashimi', 4, 'https://images.unsplash.com/photo-1440638852823-f97a7f2ea9b0?w=600&h=200&fit=crop'),
  (18, 4, 'Drinks', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Curry Palace (Indian)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (19, 5, 'Starters', 1, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d6?w=600&h=200&fit=crop'),
  (20, 5, 'Tandoori', 2, 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&h=200&fit=crop'),
  (21, 5, 'Curries', 3, 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&h=200&fit=crop'),
  (22, 5, 'Biryani & Rice', 4, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=200&fit=crop'),
  (23, 5, 'Breads', 5, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&h=200&fit=crop'),
  (24, 5, 'Beverages', 6, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Le Bistro Parisien (French)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (25, 6, 'Entrées', 1, 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&h=200&fit=crop'),
  (26, 6, 'Plats Principaux', 2, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop'),
  (27, 6, 'Fromages', 3, 'https://images.unsplash.com/photo-1452195100486-9cc805987862?w=600&h=200&fit=crop'),
  (28, 6, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&h=200&fit=crop'),
  (29, 6, 'Vins', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Taco Fiesta (Mexican)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (30, 7, 'Antojitos', 1, 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&h=200&fit=crop'),
  (31, 7, 'Tacos', 2, 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&h=200&fit=crop'),
  (32, 7, 'Burritos & Quesadillas', 3, 'https://images.unsplash.com/photo-1561758033-7e924f619af0?w=600&h=200&fit=crop'),
  (33, 7, 'Mains', 4, 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=600&h=200&fit=crop'),
  (34, 7, 'Drinks', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Saigon Street Kitchen (Vietnamese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (35, 8, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop'),
  (36, 8, 'Pho', 2, 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&h=200&fit=crop'),
  (37, 8, 'Banh Mi', 3, 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&h=200&fit=crop'),
  (38, 8, 'Rice & Noodles', 4, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=600&h=200&fit=crop'),
  (39, 8, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for The American Diner (American)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (40, 9, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop'),
  (41, 9, 'Burgers', 2, 'https://images.unsplash.com/photo-1550317138-10000687a72b?w=600&h=200&fit=crop'),
  (42, 9, 'Mains', 3, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop'),
  (43, 9, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&h=200&fit=crop'),
  (44, 9, 'Shakes & Drinks', 5, 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Istanbul Grill (Turkish)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (45, 10, 'Mezze', 1, 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=200&fit=crop'),
  (46, 10, 'Kebabs', 2, 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&h=200&fit=crop'),
  (47, 10, 'Pide & Lahmacun', 3, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=200&fit=crop'),
  (48, 10, 'Mains', 4, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop'),
  (49, 10, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Thai Orchid (Thai)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (50, 11, 'Appetizers', 1, 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=600&h=200&fit=crop'),
  (51, 11, 'Soups', 2, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop'),
  (52, 11, 'Curries', 3, 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=600&h=200&fit=crop'),
  (53, 11, 'Stir-Fry', 4, 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&h=200&fit=crop'),
  (54, 11, 'Noodles & Rice', 5, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=600&h=200&fit=crop'),
  (55, 11, 'Beverages', 6, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Seoul BBQ (Korean)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (56, 12, 'Appetizers', 1, 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&h=200&fit=crop'),
  (57, 12, 'BBQ Meats', 2, 'https://images.unsplash.com/photo-1558030137-a56c1b004fa6?w=600&h=200&fit=crop'),
  (58, 12, 'Hot Pots', 3, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop'),
  (59, 12, 'Main Dishes', 4, 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&h=200&fit=crop'),
  (60, 12, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Categories for Tapas y Vino (Spanish)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url) VALUES
  (61, 13, 'Tapas Frías', 1, 'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=600&h=200&fit=crop'),
  (62, 13, 'Tapas Calientes', 2, 'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=600&h=200&fit=crop'),
  (63, 13, 'Raciones', 3, 'https://images.unsplash.com/photo-1534330207526-8e81f10ec6fc?w=600&h=200&fit=crop'),
  (64, 13, 'Postres', 4, 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&h=200&fit=crop'),
  (65, 13, 'Bebidas', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop')
ON CONFLICT (id) DO NOTHING;

-- Items for Golden Dragon (Chinese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Appetizers
  (1, 'Spring Rolls', '1', 4.50, 'Crispy vegetable spring rolls with sweet chili sauce', false),
  (1, 'Dumplings', '2', 5.90, 'Steamed pork dumplings (6 pieces)', false),
  (1, 'Sesame Prawn Toast', '3', 6.50, 'Crispy prawn toast with sesame seeds', false),
  -- Soups
  (2, 'Hot & Sour Soup', '4', 4.20, 'Spicy and tangy soup with tofu and mushrooms', false),
  (2, 'Wonton Soup', '5', 4.80, 'Clear broth with handmade wontons', false),
  -- Main Dishes
  (3, 'Kung Pao Chicken', '6', 11.90, 'Spicy chicken with peanuts and vegetables', false),
  (3, 'Sweet & Sour Pork', '7', 10.50, 'Crispy pork in sweet and sour sauce', false),
  (3, 'Beef with Broccoli', '8', 12.50, 'Tender beef stir-fried with fresh broccoli', false),
  (3, 'Fried Rice with Vegetables', '9', 8.90, 'Classic fried rice with mixed vegetables', false),
  -- Beverages
  (4, 'Jasmine Tea', '10', 2.50, 'Traditional Chinese jasmine tea', false),
  (4, 'Tsingtao Beer', '11', 3.80, 'Chinese lager beer (330ml)', false)
ON CONFLICT DO NOTHING;

-- Items for La Bella Vita (Italian)
INSERT INTO items (id, category_id, name, item_number, price, description, has_variants) VALUES
  -- Antipasti
  (101, 5, 'Bruschetta', '1', 5.50, 'Toasted bread with fresh tomatoes, garlic, and basil', false),
  (102, 5, 'Caprese Salad', '2', 7.90, 'Buffalo mozzarella, tomatoes, and fresh basil', false),
  (103, 5, 'Antipasto Misto', '3', 9.50, 'Mixed Italian cold cuts and cheeses', false),
  -- Pizza (with size variants)
  (104, 6, 'Margherita', '4', NULL, 'Tomato sauce, mozzarella, and fresh basil', true),
  (105, 6, 'Quattro Formaggi', '5', NULL, 'Four cheese pizza with gorgonzola, mozzarella, parmesan, and fontina', true),
  (106, 6, 'Diavola', '6', NULL, 'Spicy salami, tomato sauce, and mozzarella', true),
  -- Pasta
  (107, 7, 'Spaghetti Carbonara', '7', 9.50, 'Creamy sauce with pancetta and egg yolk', false),
  (108, 7, 'Penne Arrabiata', '8', 8.90, 'Spicy tomato sauce with garlic and chili', false),
  (109, 7, 'Lasagna al Forno', '9', 11.50, 'Homemade lasagna with meat sauce and béchamel', false),
  -- Desserts
  (110, 8, 'Tiramisu', '10', 5.90, 'Classic Italian dessert with mascarpone and coffee', false),
  (111, 8, 'Panna Cotta', '11', 5.50, 'Vanilla cream with berry sauce', false),
  -- Drinks
  (112, 9, 'Espresso', '12', 2.20, 'Italian espresso coffee', false),
  (113, 9, 'House Wine (glass)', '13', 4.50, 'Red or white wine', false)
ON CONFLICT (id) DO NOTHING;

-- Pizza size variants for La Bella Vita
INSERT INTO item_variants (item_id, name, price, display_order) VALUES
  -- Margherita sizes
  (104, '20cm', 7.50, 1),
  (104, '28cm', 9.50, 2),
  (104, '32cm', 12.50, 3),
  -- Quattro Formaggi sizes
  (105, '20cm', 9.90, 1),
  (105, '28cm', 12.90, 2),
  (105, '32cm', 15.90, 3),
  -- Diavola sizes
  (106, '20cm', 8.90, 1),
  (106, '28cm', 10.90, 2),
  (106, '32cm', 13.90, 3)
ON CONFLICT DO NOTHING;

-- Items for Taverna Olympia (Greek)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Mezze
  (10, 'Tzatziki', '1', 4.50, 'Greek yogurt dip with cucumber and garlic', false),
  (10, 'Taramosalata', '2', 5.20, 'Fish roe dip with lemon and olive oil', false),
  (10, 'Dolmades', '3', 5.90, 'Stuffed grape leaves with rice and herbs', false),
  (10, 'Greek Salad', '4', 6.50, 'Tomatoes, cucumber, feta cheese, olives, and onions', false),
  -- Grilled Specialties
  (11, 'Souvlaki', '5', 11.90, 'Grilled pork skewers with pita bread and tzatziki', false),
  (11, 'Gyros Plate', '6', 10.50, 'Traditional gyros with fries, salad, and tzatziki', false),
  (11, 'Lamb Chops', '7', 16.90, 'Grilled lamb chops with lemon potatoes', false),
  -- Traditional Dishes
  (12, 'Moussaka', '8', 12.50, 'Baked eggplant with minced meat and béchamel sauce', false),
  (12, 'Pastitsio', '9', 11.90, 'Greek pasta bake with meat sauce and cheese', false),
  (12, 'Spanakopita', '10', 9.50, 'Spinach and feta cheese pie in phyllo pastry', false),
  -- Beverages
  (13, 'Greek Coffee', '11', 2.80, 'Traditional Greek coffee', false),
  (13, 'Ouzo', '12', 3.50, 'Greek anise-flavored aperitif', false),
  (13, 'Mythos Beer', '13', 3.80, 'Greek lager beer (330ml)', false)
ON CONFLICT DO NOTHING;

-- Items for Sushi Heaven (Japanese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Nigiri
  (14, 'Salmon Nigiri', '1a', 4.50, 'Fresh salmon on seasoned rice (2 pieces)', false),
  (14, 'Tuna Nigiri', '1b', 5.20, 'Premium tuna on seasoned rice (2 pieces)', false),
  (14, 'Eel Nigiri', '1c', 5.50, 'Grilled eel with sweet sauce (2 pieces)', false),
  -- Maki Rolls
  (15, 'California Roll', '2a', 6.90, 'Crab, avocado, and cucumber', false),
  (15, 'Spicy Tuna Roll', '2b', 7.50, 'Tuna with spicy mayo and sesame', false),
  (15, 'Salmon Avocado Roll', '2c', 7.20, 'Fresh salmon and avocado', false),
  -- Special Rolls
  (16, 'Dragon Roll', '3a', 12.90, 'Eel, cucumber, topped with avocado', false),
  (16, 'Rainbow Roll', '3b', 13.50, 'California roll topped with assorted fish', false),
  -- Sashimi
  (17, 'Salmon Sashimi', '4', 11.50, 'Fresh salmon slices (8 pieces)', false),
  (17, 'Mixed Sashimi', '5', 15.90, 'Assorted fresh fish (12 pieces)', false),
  -- Drinks
  (18, 'Green Tea', '6', 2.50, 'Hot Japanese green tea', false),
  (18, 'Sake', '7', 5.50, 'Japanese rice wine (100ml)', false)
ON CONFLICT DO NOTHING;

-- Items for Curry Palace (Indian)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Starters
  (19, 'Samosas', '1', 4.50, 'Crispy pastries filled with spiced potatoes (2 pieces)', false),
  (19, 'Pakoras', '2', 5.20, 'Mixed vegetable fritters', false),
  (19, 'Chicken Tikka', '3', 6.90, 'Marinated chicken pieces from tandoor', false),
  -- Tandoori
  (20, 'Tandoori Chicken', '4', 11.90, 'Half chicken marinated in yogurt and spices', false),
  (20, 'Lamb Seekh Kebab', '5', 12.50, 'Minced lamb kebabs with Indian spices', false),
  (20, 'Paneer Tikka', '6', 10.50, 'Grilled cottage cheese with peppers', false),
  -- Curries
  (21, 'Butter Chicken', '7', 12.90, 'Creamy tomato curry with tender chicken', false),
  (21, 'Lamb Rogan Josh', '8', 13.50, 'Aromatic lamb curry with Kashmiri spices', false),
  (21, 'Palak Paneer', '9', 10.90, 'Spinach curry with cottage cheese', false),
  (21, 'Chicken Vindaloo', '10', 12.50, 'Spicy and tangy Goan curry', false),
  -- Biryani & Rice
  (22, 'Chicken Biryani', '11', 11.90, 'Fragrant rice with spiced chicken', false),
  (22, 'Lamb Biryani', '12', 13.50, 'Basmati rice with tender lamb', false),
  (22, 'Vegetable Biryani', '13', 9.90, 'Rice with mixed vegetables and spices', false),
  -- Breads
  (23, 'Naan', '14', 2.50, 'Traditional Indian bread', false),
  (23, 'Garlic Naan', '15', 3.20, 'Naan with garlic and butter', false),
  (23, 'Paratha', '16', 3.50, 'Layered flatbread', false),
  -- Beverages
  (24, 'Mango Lassi', '17', 3.80, 'Sweet yogurt drink with mango', false),
  (24, 'Masala Chai', '18', 2.50, 'Spiced Indian tea', false)
ON CONFLICT DO NOTHING;

-- Items for Le Bistro Parisien (French)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Entrées
  (25, 'French Onion Soup', '1', 7.50, 'Classic soup with caramelized onions and gruyère', false),
  (25, 'Escargots de Bourgogne', '2', 9.90, 'Burgundy snails with garlic butter (6 pieces)', false),
  (25, 'Pâté de Campagne', '3', 8.50, 'Country-style pâté with cornichons', false),
  -- Plats Principaux
  (26, 'Coq au Vin', '4', 18.90, 'Chicken braised in red wine with mushrooms', false),
  (26, 'Boeuf Bourguignon', '5', 21.50, 'Beef stew with burgundy wine and vegetables', false),
  (26, 'Sole Meunière', '6', 19.90, 'Pan-fried sole with lemon butter sauce', false),
  (26, 'Steak Frites', '7', 22.50, 'Ribeye steak with french fries', false),
  -- Fromages
  (27, 'Cheese Plate', '8', 12.50, 'Selection of French cheeses', false),
  -- Desserts
  (28, 'Crème Brûlée', '9', 7.50, 'Vanilla custard with caramelized sugar', false),
  (28, 'Tarte Tatin', '10', 8.20, 'Upside-down caramelized apple tart', false),
  (28, 'Mousse au Chocolat', '11', 7.90, 'Rich chocolate mousse', false),
  -- Vins
  (29, 'Bordeaux (glass)', '12', 6.50, 'Red wine from Bordeaux', false),
  (29, 'Champagne (glass)', '13', 9.90, 'French sparkling wine', false)
ON CONFLICT DO NOTHING;

-- Items for Taco Fiesta (Mexican)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Antojitos
  (30, 'Nachos Supreme', '1', 7.90, 'Tortilla chips with cheese, jalapeños, and salsa', false),
  (30, 'Guacamole & Chips', '2', 6.50, 'Fresh avocado dip with tortilla chips', false),
  (30, 'Quesito Fundido', '3', 5.90, 'Melted cheese with chorizo', false),
  -- Tacos
  (31, 'Carne Asada Taco', '4', 3.90, 'Grilled beef with onions and cilantro', false),
  (31, 'Al Pastor Taco', '5', 3.70, 'Marinated pork with pineapple', false),
  (31, 'Fish Taco', '6', 4.20, 'Battered fish with cabbage slaw', false),
  (31, 'Veggie Taco', '7', 3.50, 'Grilled vegetables with black beans', false),
  -- Burritos & Quesadillas
  (32, 'Beef Burrito', '8', 9.90, 'Large tortilla with beef, rice, beans, and cheese', false),
  (32, 'Chicken Quesadilla', '9', 8.50, 'Grilled tortilla with chicken and cheese', false),
  (32, 'Veggie Burrito', '10', 8.90, 'Rice, beans, vegetables, and guacamole', false),
  -- Mains
  (33, 'Enchiladas', '11', 11.50, 'Rolled tortillas with chicken and cheese sauce', false),
  (33, 'Fajitas', '12', 13.90, 'Sizzling beef or chicken with peppers and onions', false),
  -- Drinks
  (34, 'Margarita', '13', 7.50, 'Classic tequila cocktail', false),
  (34, 'Cerveza', '14', 3.80, 'Mexican beer', false)
ON CONFLICT DO NOTHING;

-- Items for Saigon Street Kitchen (Vietnamese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Appetizers
  (35, 'Summer Rolls', '1', 5.50, 'Fresh rice paper rolls with shrimp and herbs (2 pieces)', false),
  (35, 'Fried Spring Rolls', '2', 4.90, 'Crispy rolls with pork and vegetables (3 pieces)', false),
  (35, 'Vietnamese Dumplings', '3', 5.20, 'Steamed dumplings with pork filling', false),
  -- Pho
  (36, 'Pho Bo', '4', 9.50, 'Beef noodle soup with rice noodles', false),
  (36, 'Pho Ga', '5', 8.90, 'Chicken noodle soup with herbs', false),
  (36, 'Pho Chay', '6', 8.50, 'Vegetarian pho with tofu', false),
  -- Banh Mi
  (37, 'Banh Mi Thit', '7', 6.50, 'Vietnamese sandwich with grilled pork', false),
  (37, 'Banh Mi Ga', '8', 6.20, 'Sandwich with lemongrass chicken', false),
  (37, 'Banh Mi Chay', '9', 5.90, 'Vegetarian sandwich with tofu', false),
  -- Rice & Noodles
  (38, 'Bun Cha', '10', 10.90, 'Grilled pork with vermicelli and herbs', false),
  (38, 'Com Tam', '11', 9.50, 'Broken rice with grilled pork chop', false),
  (38, 'Pad Thai', '12', 9.90, 'Stir-fried rice noodles', false),
  -- Beverages
  (39, 'Vietnamese Coffee', '13', 3.50, 'Strong coffee with condensed milk', false),
  (39, 'Fresh Coconut', '14', 3.80, 'Young coconut water', false)
ON CONFLICT DO NOTHING;

-- Items for The American Diner (American)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Appetizers
  (40, 'Buffalo Wings', '1', 7.90, 'Spicy chicken wings with blue cheese dip (8 pieces)', false),
  (40, 'Mozzarella Sticks', '2', 6.50, 'Breaded mozzarella with marinara sauce', false),
  (40, 'Onion Rings', '3', 5.50, 'Crispy beer-battered onion rings', false),
  -- Burgers
  (41, 'Classic Cheeseburger', '4', 10.90, 'Beef patty with cheese, lettuce, tomato', false),
  (41, 'Bacon BBQ Burger', '5', 12.50, 'Double patty with bacon and BBQ sauce', false),
  (41, 'Veggie Burger', '6', 9.90, 'Plant-based patty with avocado', false),
  -- Mains
  (42, 'NY Strip Steak', '7', 19.90, 'Grilled steak with mashed potatoes', false),
  (42, 'BBQ Ribs', '8', 16.50, 'Half rack of baby back ribs', false),
  (42, 'Mac & Cheese', '9', 8.90, 'Creamy macaroni and cheese', false),
  (42, 'Fish & Chips', '10', 11.50, 'Battered cod with fries', false),
  -- Desserts
  (43, 'Brownie Sundae', '11', 6.90, 'Warm brownie with ice cream', false),
  (43, 'Apple Pie', '12', 5.50, 'Classic American apple pie', false),
  (43, 'Cheesecake', '13', 6.50, 'New York style cheesecake', false),
  -- Shakes & Drinks
  (44, 'Chocolate Shake', '14', 5.50, 'Thick chocolate milkshake', false),
  (44, 'Strawberry Shake', '15', 5.50, 'Fresh strawberry milkshake', false),
  (44, 'Coca-Cola', '16', 2.50, 'Classic soft drink', false)
ON CONFLICT DO NOTHING;

-- Items for Istanbul Grill (Turkish)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Mezze
  (45, 'Hummus', '1', 4.50, 'Chickpea dip with olive oil', false),
  (45, 'Baba Ghanoush', '2', 4.90, 'Smoked eggplant dip', false),
  (45, 'Mixed Mezze Platter', '3', 9.90, 'Selection of Turkish dips and salads', false),
  -- Kebabs
  (46, 'Adana Kebab', '4', 11.90, 'Spicy minced meat kebab', false),
  (46, 'Shish Kebab', '5', 12.50, 'Marinated lamb cubes on skewer', false),
  (46, 'Chicken Shish', '6', 10.90, 'Grilled chicken breast pieces', false),
  (46, 'Mixed Grill', '7', 15.90, 'Combination of all kebabs', false),
  -- Pide & Lahmacun
  (47, 'Cheese Pide', '8', 8.50, 'Turkish flatbread with cheese', false),
  (47, 'Meat Pide', '9', 9.90, 'Boat-shaped pizza with minced meat', false),
  (47, 'Lahmacun', '10', 6.50, 'Thin flatbread with spiced meat', false),
  -- Mains
  (48, 'Iskender Kebab', '11', 13.50, 'Sliced döner with tomato sauce and yogurt', false),
  (48, 'Manti', '12', 10.90, 'Turkish dumplings with yogurt sauce', false),
  -- Beverages
  (49, 'Turkish Tea', '13', 2.00, 'Traditional black tea', false),
  (49, 'Ayran', '14', 2.50, 'Salted yogurt drink', false)
ON CONFLICT DO NOTHING;

-- Items for Thai Orchid (Thai)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Appetizers
  (50, 'Thai Spring Rolls', '1', 5.50, 'Vegetable spring rolls with sweet chili sauce', false),
  (50, 'Satay Chicken', '2', 6.90, 'Grilled chicken skewers with peanut sauce', false),
  (50, 'Tom Yum Goong', '3', 7.50, 'Spicy and sour shrimp soup', false),
  -- Soups
  (51, 'Tom Kha Gai', '4', 6.90, 'Coconut milk soup with chicken', false),
  (51, 'Tom Yum', '5', 6.50, 'Hot and sour soup with mushrooms', false),
  -- Curries
  (52, 'Green Curry', '6', 11.50, 'Spicy green curry with chicken or beef', false),
  (52, 'Red Curry', '7', 11.50, 'Thai red curry with vegetables', false),
  (52, 'Massaman Curry', '8', 12.50, 'Mild curry with potatoes and peanuts', false),
  (52, 'Panang Curry', '9', 11.90, 'Rich and creamy peanut curry', false),
  -- Stir-Fry
  (53, 'Pad Krapow', '10', 10.90, 'Stir-fried basil with minced meat', false),
  (53, 'Cashew Chicken', '11', 11.50, 'Chicken with cashews and vegetables', false),
  -- Noodles & Rice
  (54, 'Pad Thai', '12', 9.90, 'Stir-fried rice noodles with shrimp', false),
  (54, 'Pad See Ew', '13', 9.50, 'Flat noodles with soy sauce', false),
  (54, 'Thai Fried Rice', '14', 8.90, 'Jasmine rice with egg and vegetables', false),
  -- Beverages
  (55, 'Thai Iced Tea', '15', 3.50, 'Sweet milk tea with ice', false),
  (55, 'Singha Beer', '16', 3.80, 'Thai lager beer', false)
ON CONFLICT DO NOTHING;

-- Items for Seoul BBQ (Korean)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Appetizers
  (56, 'Kimchi', '1', 4.50, 'Fermented spicy cabbage', false),
  (56, 'Mandu', '2', 6.50, 'Korean dumplings (steamed or fried)', false),
  (56, 'Japchae', '3', 7.90, 'Stir-fried glass noodles with vegetables', false),
  -- BBQ Meats
  (57, 'Bulgogi', '4', 14.90, 'Marinated beef for table grill', false),
  (57, 'Galbi', '5', 16.90, 'Marinated beef short ribs', false),
  (57, 'Samgyeopsal', '6', 13.50, 'Pork belly slices for grilling', false),
  (57, 'BBQ Combo', '7', 24.90, 'Mixed meats platter for 2 persons', false),
  -- Hot Pots
  (58, 'Kimchi Jjigae', '8', 10.90, 'Spicy kimchi stew with pork', false),
  (58, 'Sundubu Jjigae', '9', 11.50, 'Soft tofu stew with seafood', false),
  -- Main Dishes
  (59, 'Bibimbap', '10', 10.50, 'Mixed rice with vegetables and egg', false),
  (59, 'Dolsot Bibimbap', '11', 11.90, 'Bibimbap in hot stone pot', false),
  (59, 'Korean Fried Chicken', '12', 12.50, 'Crispy fried chicken with sweet-spicy sauce', false),
  -- Beverages
  (60, 'Soju', '13', 5.50, 'Korean distilled spirit', false),
  (60, 'Makgeolli', '14', 6.50, 'Traditional rice wine', false)
ON CONFLICT DO NOTHING;

-- Items for Tapas y Vino (Spanish)
INSERT INTO items (category_id, name, item_number, price, description, has_variants) VALUES
  -- Tapas Frías
  (61, 'Jamón Ibérico', '1', 9.90, 'Iberian ham with bread', false),
  (61, 'Manchego', '2', 7.50, 'Spanish sheep cheese with quince', false),
  (61, 'Aceitunas', '3', 4.50, 'Marinated olives with herbs', false),
  (61, 'Pan con Tomate', '4', 5.50, 'Toasted bread with tomato and olive oil', false),
  -- Tapas Calientes
  (62, 'Patatas Bravas', '5', 6.50, 'Fried potatoes with spicy sauce', false),
  (62, 'Gambas al Ajillo', '6', 9.90, 'Garlic shrimp in olive oil', false),
  (62, 'Croquetas', '7', 7.50, 'Creamy ham croquettes (4 pieces)', false),
  (62, 'Chorizo al Vino', '8', 8.50, 'Spanish sausage in red wine', false),
  (62, 'Pimientos de Padrón', '9', 6.90, 'Fried green peppers with sea salt', false),
  -- Raciones
  (63, 'Paella Valenciana', '10', 16.90, 'Traditional rice with chicken and seafood', false),
  (63, 'Pulpo a la Gallega', '11', 14.50, 'Galician-style octopus with paprika', false),
  (63, 'Tortilla Española', '12', 8.90, 'Spanish potato omelette', false),
  -- Postres
  (64, 'Crema Catalana', '13', 5.90, 'Catalan custard with caramelized sugar', false),
  (64, 'Churros con Chocolate', '14', 6.50, 'Fried dough with hot chocolate', false),
  -- Bebidas
  (65, 'Sangria', '15', 5.50, 'Spanish red wine punch', false),
  (65, 'Rioja (glass)', '16', 6.50, 'Spanish red wine', false)
ON CONFLICT DO NOTHING;

-- Reset sequences to the current max id
SELECT setval(pg_get_serial_sequence('restaurants','id'), COALESCE((SELECT MAX(id) FROM restaurants), 1));
SELECT setval(pg_get_serial_sequence('categories','id'), COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval(pg_get_serial_sequence('items','id'), COALESCE((SELECT MAX(id) FROM items), 1));
SELECT setval(pg_get_serial_sequence('item_variants','id'), COALESCE((SELECT MAX(id) FROM item_variants), 1));

-- Enable Row Level Security on restaurants table
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can view all restaurants (read access)
CREATE POLICY "Allow public read access to restaurants"
  ON restaurants
  FOR SELECT
  USING (true);

-- Policy: Authenticated users can insert new restaurants (they become the owner)
CREATE POLICY "Allow authenticated users to insert restaurants"
  ON restaurants
  FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL AND restaurant_owner_uuid = auth.uid());

-- Policy: Restaurant owners can update their own restaurants
CREATE POLICY "Allow owners to update their restaurants"
  ON restaurants
  FOR UPDATE
  USING (restaurant_owner_uuid = auth.uid())
  WITH CHECK (restaurant_owner_uuid = auth.uid());

-- Policy: Restaurant owners can delete their own restaurants
CREATE POLICY "Allow owners to delete their restaurants"
  ON restaurants
  FOR DELETE
  USING (restaurant_owner_uuid = auth.uid());

-- Enable RLS on related tables
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_variants ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read categories, items, and variants
CREATE POLICY "Allow public read access to categories"
  ON categories FOR SELECT USING (true);

CREATE POLICY "Allow public read access to items"
  ON items FOR SELECT USING (true);

CREATE POLICY "Allow public read access to item_variants"
  ON item_variants FOR SELECT USING (true);

-- Policy: Restaurant owners can manage their restaurant's categories
CREATE POLICY "Allow owners to manage categories"
  ON categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM restaurants
      WHERE restaurants.id = categories.restaurant_id
      AND restaurants.restaurant_owner_uuid = auth.uid()
    )
  );

-- Policy: Restaurant owners can manage their items (through categories)
CREATE POLICY "Allow owners to manage items"
  ON items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM categories
      JOIN restaurants ON restaurants.id = categories.restaurant_id
      WHERE categories.id = items.category_id
      AND restaurants.restaurant_owner_uuid = auth.uid()
    )
  );

-- Policy: Restaurant owners can manage their item variants
CREATE POLICY "Allow owners to manage item_variants"
  ON item_variants
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM items
      JOIN categories ON categories.id = items.category_id
      JOIN restaurants ON restaurants.id = categories.restaurant_id
      WHERE items.id = item_variants.item_id
      AND restaurants.restaurant_owner_uuid = auth.uid()
    )
  );

COMMIT;
