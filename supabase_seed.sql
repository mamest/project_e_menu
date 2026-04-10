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
  menu_html_url text,
  translations jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  menu_updated_at timestamptz
);

-- Categories table (each restaurant has its own categories)
CREATE TABLE categories (
  id bigserial PRIMARY KEY,
  restaurant_id bigint NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_order int DEFAULT 0,
  image_url text,
  translations jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
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
  has_variants boolean DEFAULT false,
  translations jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Item variants table (for sizes, options, etc.)
CREATE TABLE item_variants (
  id bigserial PRIMARY KEY,
  item_id bigint NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  name text NOT NULL,
  price numeric(8,2) NOT NULL,
  display_order int DEFAULT 0,
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Trigger function: keep updated_at current
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

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

-- Bubble-up triggers: child table changes update restaurants.menu_updated_at
CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_category()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_rid bigint;
BEGIN
  v_rid := COALESCE(NEW.restaurant_id, OLD.restaurant_id);
  UPDATE restaurants SET menu_updated_at = now() WHERE id = v_rid;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_categories_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON categories
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_category();

CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_item()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_cid bigint;
BEGIN
  v_cid := COALESCE(NEW.category_id, OLD.category_id);
  UPDATE restaurants r SET menu_updated_at = now()
  FROM categories c WHERE c.id = v_cid AND r.id = c.restaurant_id;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_items_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON items
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_item();

CREATE OR REPLACE FUNCTION bubble_menu_updated_at_from_variant()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_iid bigint;
BEGIN
  v_iid := COALESCE(NEW.item_id, OLD.item_id);
  UPDATE restaurants r SET menu_updated_at = now()
  FROM items i JOIN categories c ON c.id = i.category_id
  WHERE i.id = v_iid AND r.id = c.restaurant_id;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_item_variants_bubble_menu
  AFTER INSERT OR UPDATE OR DELETE ON item_variants
  FOR EACH ROW EXECUTE FUNCTION bubble_menu_updated_at_from_variant();

-- Insert example restaurants in Büren, Geseke, Brilon, and Salzkotten
INSERT INTO restaurants (id, name, address, email, phone, description, image_url, cuisine_type, delivers, opening_hours, payment_methods, latitude, longitude, restaurant_owner_uuid, translations) VALUES
  (1, 'Golden Dragon', 'Königstraße 12, 33142 Büren, Germany', 'info@goldendragon.de', '+49 2951 123456', 
   'Authentic Chinese cuisine with traditional flavors',
   'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=800',
   'Chinese',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'PayPal'],
   51.551667, 8.559722, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Authentic Chinese cuisine with traditional flavors"},"en":{"name":"","description":"Authentic Chinese cuisine with traditional flavors"},"de":{"name":"","description":"Authentische chinesische Küche mit traditionellen Aromen"}}'::jsonb),
  
  (2, 'La Bella Vita', 'Bachstraße 8, 59590 Geseke, Germany', 'contact@labellavita.de', '+49 2942 234567', 
   'Traditional Italian restaurant serving homemade pasta and pizza',
   'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
   'Italian',
   true,
   '{"monday": "12:00-23:00", "tuesday": "12:00-23:00", "wednesday": "12:00-23:00", "thursday": "12:00-23:00", "friday": "12:00-00:00", "saturday": "12:00-00:00", "sunday": "Closed"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay', 'Google Pay'],
   51.640556, 8.516389, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Traditional Italian restaurant serving homemade pasta and pizza"},"en":{"name":"","description":"Traditional Italian restaurant serving homemade pasta and pizza"},"de":{"name":"","description":"Traditionelles italienisches Restaurant mit hausgemachten Nudeln und Pizza"}}'::jsonb),
  
  (3, 'Taverna Olympia', 'Marktplatz 5, 59929 Brilon, Germany', 'hello@tavernaolympia.de', '+49 2961 345678', 
   'Greek taverna with Mediterranean specialties',
   'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800',
   'Greek',
   false,
   '{"monday": "17:00-23:00", "tuesday": "17:00-23:00", "wednesday": "Closed", "thursday": "17:00-23:00", "friday": "17:00-00:00", "saturday": "12:00-00:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'EC Card'],
   51.393889, 8.570278, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Greek taverna with Mediterranean specialties"},"en":{"name":"","description":"Greek taverna with Mediterranean specialties"},"de":{"name":"","description":"Griechische Taverne mit mediterranen Spezialitäten"}}'::jsonb),
  
  (4, 'Sushi Heaven', 'Lange Straße 34, 33154 Salzkotten, Germany', 'info@sushiheaven.de', '+49 5258 456789', 
   'Premium Japanese sushi bar with fresh daily selections',
   'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800',
   'Japanese',
   true,
   '{"monday": "11:30-22:00", "tuesday": "11:30-22:00", "wednesday": "11:30-22:00", "thursday": "11:30-22:00", "friday": "11:30-23:00", "saturday": "12:00-23:00", "sunday": "12:00-21:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay'],
   51.672222, 8.605833, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Premium Japanese sushi bar with fresh daily selections"},"en":{"name":"","description":"Premium Japanese sushi bar with fresh daily selections"},"de":{"name":"","description":"Erstklassige japanische Sushi-Bar mit täglich frischen Angeboten"}}'::jsonb),
  
  (5, 'Curry Palace', 'Hauptstraße 45, 33142 Büren, Germany', 'info@currypalace.de', '+49 2951 567890', 
   'Authentic Indian cuisine with traditional tandoori specialties',
   'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800',
   'Indian',
   true,
   '{"monday": "12:00-23:00", "tuesday": "12:00-23:00", "wednesday": "12:00-23:00", "thursday": "12:00-23:00", "friday": "12:00-00:00", "saturday": "13:00-00:00", "sunday": "13:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'PayPal', 'Google Pay'],
   51.548889, 8.563611, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Authentic Indian cuisine with traditional tandoori specialties"},"en":{"name":"","description":"Authentic Indian cuisine with traditional tandoori specialties"},"de":{"name":"","description":"Authentische indische Küche mit traditionellen Tandoori-Spezialitäten"}}'::jsonb),
  
  (6, 'Le Bistro Parisien', 'Bürener Straße 22, 59590 Geseke, Germany', 'contact@lebistro.de', '+49 2942 678901', 
   'Classic French bistro with elegant dining experience',
   'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=800',
   'French',
   false,
   '{"monday": "Closed", "tuesday": "18:00-23:00", "wednesday": "18:00-23:00", "thursday": "18:00-23:00", "friday": "18:00-00:00", "saturday": "18:00-00:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card'],
   51.638333, 8.520556, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Classic French bistro with elegant dining experience"},"en":{"name":"","description":"Classic French bistro with elegant dining experience"},"de":{"name":"","description":"Klassisches französisches Bistro mit elegantem Speiseerlebnis"}}'::jsonb),
  
  (7, 'Taco Fiesta', 'Steinweg 18, 59929 Brilon, Germany', 'hola@tacofiesta.de', '+49 2961 789012', 
   'Vibrant Mexican restaurant with authentic street food',
   'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800',
   'Mexican',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Apple Pay', 'Google Pay'],
   51.396111, 8.567222, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Vibrant Mexican restaurant with authentic street food"},"en":{"name":"","description":"Vibrant Mexican restaurant with authentic street food"},"de":{"name":"","description":"Lebhaftes mexikanisches Restaurant mit authentischem Straßenessen"}}'::jsonb),
  
  (8, 'Saigon Street Kitchen', 'Vielser Straße 15, 33154 Salzkotten, Germany', 'info@saigonstreet.de', '+49 5258 890123', 
   'Vietnamese street food with modern twist',
   'https://images.unsplash.com/photo-1559314809-0d155014e29e?w=800',
   'Vietnamese',
   true,
   '{"monday": "11:00-22:00", "tuesday": "11:00-22:00", "wednesday": "11:00-22:00", "thursday": "11:00-22:00", "friday": "11:00-23:00", "saturday": "12:00-23:00", "sunday": "12:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'PayPal'],
   51.669444, 8.611667, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Vietnamese street food with modern twist"},"en":{"name":"","description":"Vietnamese street food with modern twist"},"de":{"name":"","description":"Vietnamesisches Straßenessen mit modernem Touch"}}'::jsonb),
  
  (9, 'The American Diner', 'Bahnhofstraße 28, 33142 Büren, Germany', 'info@americandiner.de', '+49 2951 901234', 
   'Classic American diner serving burgers, shakes, and comfort food',
   'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
   'American',
   true,
   '{"monday": "10:00-23:00", "tuesday": "10:00-23:00", "wednesday": "10:00-23:00", "thursday": "10:00-23:00", "friday": "10:00-00:00", "saturday": "10:00-00:00", "sunday": "10:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay', 'Google Pay'],
   51.545278, 8.565000, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Classic American diner serving burgers, shakes, and comfort food"},"en":{"name":"","description":"Classic American diner serving burgers, shakes, and comfort food"},"de":{"name":"","description":"Klassisches amerikanisches Diner mit Burgern, Milchshakes und Wohlfühlküche"}}'::jsonb),
  
  (10, 'Istanbul Grill', 'Erwitter Straße 42, 59590 Geseke, Germany', 'info@istanbulgrill.de', '+49 2942 012345', 
   'Traditional Turkish grill house with fresh kebabs',
   'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=800',
   'Turkish',
   true,
   '{"monday": "10:00-23:00", "tuesday": "10:00-23:00", "wednesday": "10:00-23:00", "thursday": "10:00-23:00", "friday": "10:00-01:00", "saturday": "10:00-01:00", "sunday": "11:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'EC Card'],
   51.635556, 8.523333, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Traditional Turkish grill house with fresh kebabs"},"en":{"name":"","description":"Traditional Turkish grill house with fresh kebabs"},"de":{"name":"","description":"Traditionelles türkisches Grillhaus mit frischen Kebabs"}}'::jsonb),
  
  (11, 'Thai Orchid', 'Derkere Straße 12, 59929 Brilon, Germany', 'hello@thaiorchid.de', '+49 2961 123450', 
   'Authentic Thai restaurant with aromatic curries and pad thai',
   'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=800',
   'Thai',
   true,
   '{"monday": "12:00-22:00", "tuesday": "12:00-22:00", "wednesday": "12:00-22:00", "thursday": "12:00-22:00", "friday": "12:00-23:00", "saturday": "12:00-23:00", "sunday": "13:00-22:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'PayPal'],
   51.390000, 8.573889, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Authentic Thai restaurant with aromatic curries and pad thai"},"en":{"name":"","description":"Authentic Thai restaurant with aromatic curries and pad thai"},"de":{"name":"","description":"Authentisches Thai-Restaurant mit aromatischen Currys und Pad Thai"}}'::jsonb),
  
  (12, 'Seoul BBQ', 'Upsprunger Straße 8, 33154 Salzkotten, Germany', 'info@seoulbbq.de', '+49 5258 234561', 
   'Korean BBQ restaurant with table grills and banchan',
   'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=800',
   'Korean',
   false,
   '{"monday": "Closed", "tuesday": "17:00-23:00", "wednesday": "17:00-23:00", "thursday": "17:00-23:00", "friday": "17:00-00:00", "saturday": "12:00-00:00", "sunday": "12:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Debit Card', 'Apple Pay'],
   51.665833, 8.608611, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Korean BBQ restaurant with table grills and banchan"},"en":{"name":"","description":"Korean BBQ restaurant with table grills and banchan"},"de":{"name":"","description":"Koreanisches BBQ-Restaurant mit Tischgrills und Beilagen"}}'::jsonb),
  
  (13, 'Tapas y Vino', 'Alme 7, 33142 Büren, Germany', 'hola@tapasyvino.de', '+49 2951 345672', 
   'Spanish tapas bar with extensive wine selection',
   'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=800',
   'Spanish',
   false,
   '{"monday": "Closed", "tuesday": "17:00-00:00", "wednesday": "17:00-00:00", "thursday": "17:00-00:00", "friday": "17:00-01:00", "saturday": "12:00-01:00", "sunday": "12:00-23:00"}'::jsonb,
   ARRAY['Cash', 'Credit Card', 'Apple Pay'],
   51.553056, 8.556944, '2f60fdc0-6bf2-4200-8ea4-6a5612c9ade2',
   '{"_source":{"name":"","desc":"Spanish tapas bar with extensive wine selection"},"en":{"name":"","description":"Spanish tapas bar with extensive wine selection"},"de":{"name":"","description":"Spanische Tapas-Bar mit umfangreichem Weinangebot"}}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- Categories for Golden Dragon (Chinese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (1, 1, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop', '{"_source":{"name":"Appetizers"},"en":{"name":"Appetizers"},"de":{"name":"Vorspeisen"}}'),
  (2, 1, 'Soups', 2, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop', '{"_source":{"name":"Soups"},"en":{"name":"Soups"},"de":{"name":"Suppen"}}'),
  (3, 1, 'Main Dishes', 3, 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&h=200&fit=crop', '{"_source":{"name":"Main Dishes"},"en":{"name":"Main Dishes"},"de":{"name":"Hauptgerichte"}}'),
  (4, 1, 'Beverages', 4, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for La Bella Vita (Italian)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (5, 2, 'Antipasti', 1, 'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?w=600&h=200&fit=crop', '{"_source":{"name":"Antipasti"},"en":{"name":"Antipasti"},"de":{"name":"Antipasti"}}'),
  (6, 2, 'Pizza', 2, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=200&fit=crop', '{"_source":{"name":"Pizza"},"en":{"name":"Pizza"},"de":{"name":"Pizza"}}'),
  (7, 2, 'Pasta', 3, 'https://images.unsplash.com/photo-1551183053-bf91798d74b9?w=600&h=200&fit=crop', '{"_source":{"name":"Pasta"},"en":{"name":"Pasta"},"de":{"name":"Pasta"}}'),
  (8, 2, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&h=200&fit=crop', '{"_source":{"name":"Desserts"},"en":{"name":"Desserts"},"de":{"name":"Desserts"}}'),
  (9, 2, 'Drinks', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop', '{"_source":{"name":"Drinks"},"en":{"name":"Drinks"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Taverna Olympia (Greek)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (10, 3, 'Mezze', 1, 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=200&fit=crop', '{"_source":{"name":"Mezze"},"en":{"name":"Mezze"},"de":{"name":"Mezze"}}'),
  (11, 3, 'Grilled Specialties', 2, 'https://images.unsplash.com/photo-1529516548873-9ce57c8f155e?w=600&h=200&fit=crop', '{"_source":{"name":"Grilled Specialties"},"en":{"name":"Grilled Specialties"},"de":{"name":"Grillspezialitäten"}}'),
  (12, 3, 'Traditional Dishes', 3, 'https://images.unsplash.com/photo-1600803907087-f56d462fd26b?w=600&h=200&fit=crop', '{"_source":{"name":"Traditional Dishes"},"en":{"name":"Traditional Dishes"},"de":{"name":"Traditionelle Gerichte"}}'),
  (13, 3, 'Beverages', 4, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Sushi Heaven (Japanese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (14, 4, 'Nigiri', 1, 'https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=600&h=200&fit=crop', '{"_source":{"name":"Nigiri"},"en":{"name":"Nigiri"},"de":{"name":"Nigiri"}}'),
  (15, 4, 'Maki Rolls', 2, 'https://images.unsplash.com/photo-1617196034776-f26e5ead5356?w=600&h=200&fit=crop', '{"_source":{"name":"Maki Rolls"},"en":{"name":"Maki Rolls"},"de":{"name":"Maki-Rollen"}}'),
  (16, 4, 'Special Rolls', 3, 'https://images.unsplash.com/photo-1606755962773-d324e0a13086?w=600&h=200&fit=crop', '{"_source":{"name":"Special Rolls"},"en":{"name":"Special Rolls"},"de":{"name":"Spezialrollen"}}'),
  (17, 4, 'Sashimi', 4, 'https://images.unsplash.com/photo-1440638852823-f97a7f2ea9b0?w=600&h=200&fit=crop', '{"_source":{"name":"Sashimi"},"en":{"name":"Sashimi"},"de":{"name":"Sashimi"}}'),
  (18, 4, 'Drinks', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Drinks"},"en":{"name":"Drinks"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Curry Palace (Indian)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (19, 5, 'Starters', 1, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d6?w=600&h=200&fit=crop', '{"_source":{"name":"Starters"},"en":{"name":"Starters"},"de":{"name":"Vorspeisen"}}'),
  (20, 5, 'Tandoori', 2, 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&h=200&fit=crop', '{"_source":{"name":"Tandoori"},"en":{"name":"Tandoori"},"de":{"name":"Tandoori"}}'),
  (21, 5, 'Curries', 3, 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=600&h=200&fit=crop', '{"_source":{"name":"Curries"},"en":{"name":"Curries"},"de":{"name":"Currys"}}'),
  (22, 5, 'Biryani & Rice', 4, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&h=200&fit=crop', '{"_source":{"name":"Biryani & Rice"},"en":{"name":"Biryani & Rice"},"de":{"name":"Biryani & Reis"}}'),
  (23, 5, 'Breads', 5, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600&h=200&fit=crop', '{"_source":{"name":"Breads"},"en":{"name":"Breads"},"de":{"name":"Brot"}}'),
  (24, 5, 'Beverages', 6, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Le Bistro Parisien (French)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (25, 6, 'Entrées', 1, 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&h=200&fit=crop', '{"_source":{"name":"Entrées"},"en":{"name":"Starters"},"de":{"name":"Vorspeisen"}}'),
  (26, 6, 'Plats Principaux', 2, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop', '{"_source":{"name":"Plats Principaux"},"en":{"name":"Main Courses"},"de":{"name":"Hauptgänge"}}'),
  (27, 6, 'Fromages', 3, 'https://images.unsplash.com/photo-1452195100486-9cc805987862?w=600&h=200&fit=crop', '{"_source":{"name":"Fromages"},"en":{"name":"Cheeses"},"de":{"name":"Käse"}}'),
  (28, 6, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&h=200&fit=crop', '{"_source":{"name":"Desserts"},"en":{"name":"Desserts"},"de":{"name":"Desserts"}}'),
  (29, 6, 'Vins', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop', '{"_source":{"name":"Vins"},"en":{"name":"Wines"},"de":{"name":"Weine"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Taco Fiesta (Mexican)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (30, 7, 'Antojitos', 1, 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&h=200&fit=crop', '{"_source":{"name":"Antojitos"},"en":{"name":"Snacks"},"de":{"name":"Snacks"}}'),
  (31, 7, 'Tacos', 2, 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=600&h=200&fit=crop', '{"_source":{"name":"Tacos"},"en":{"name":"Tacos"},"de":{"name":"Tacos"}}'),
  (32, 7, 'Burritos & Quesadillas', 3, 'https://images.unsplash.com/photo-1561758033-7e924f619af0?w=600&h=200&fit=crop', '{"_source":{"name":"Burritos & Quesadillas"},"en":{"name":"Burritos & Quesadillas"},"de":{"name":"Burritos & Quesadillas"}}'),
  (33, 7, 'Mains', 4, 'https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?w=600&h=200&fit=crop', '{"_source":{"name":"Mains"},"en":{"name":"Mains"},"de":{"name":"Hauptgerichte"}}'),
  (34, 7, 'Drinks', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Drinks"},"en":{"name":"Drinks"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Saigon Street Kitchen (Vietnamese)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (35, 8, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop', '{"_source":{"name":"Appetizers"},"en":{"name":"Appetizers"},"de":{"name":"Vorspeisen"}}'),
  (36, 8, 'Pho', 2, 'https://images.unsplash.com/photo-1569050467447-ce54b3bbc37d?w=600&h=200&fit=crop', '{"_source":{"name":"Pho"},"en":{"name":"Pho"},"de":{"name":"Pho"}}'),
  (37, 8, 'Banh Mi', 3, 'https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&h=200&fit=crop', '{"_source":{"name":"Banh Mi"},"en":{"name":"Banh Mi"},"de":{"name":"Banh Mi"}}'),
  (38, 8, 'Rice & Noodles', 4, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=600&h=200&fit=crop', '{"_source":{"name":"Rice & Noodles"},"en":{"name":"Rice & Noodles"},"de":{"name":"Reis & Nudeln"}}'),
  (39, 8, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for The American Diner (American)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (40, 9, 'Appetizers', 1, 'https://images.unsplash.com/photo-1541014741259-de529411b96a?w=600&h=200&fit=crop', '{"_source":{"name":"Appetizers"},"en":{"name":"Appetizers"},"de":{"name":"Vorspeisen"}}'),
  (41, 9, 'Burgers', 2, 'https://images.unsplash.com/photo-1550317138-10000687a72b?w=600&h=200&fit=crop', '{"_source":{"name":"Burgers"},"en":{"name":"Burgers"},"de":{"name":"Burger"}}'),
  (42, 9, 'Mains', 3, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop', '{"_source":{"name":"Mains"},"en":{"name":"Mains"},"de":{"name":"Hauptgerichte"}}'),
  (43, 9, 'Desserts', 4, 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=600&h=200&fit=crop', '{"_source":{"name":"Desserts"},"en":{"name":"Desserts"},"de":{"name":"Desserts"}}'),
  (44, 9, 'Shakes & Drinks', 5, 'https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=600&h=200&fit=crop', '{"_source":{"name":"Shakes & Drinks"},"en":{"name":"Shakes & Drinks"},"de":{"name":"Shakes & Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Istanbul Grill (Turkish)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (45, 10, 'Mezze', 1, 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=600&h=200&fit=crop', '{"_source":{"name":"Mezze"},"en":{"name":"Mezze"},"de":{"name":"Mezze"}}'),
  (46, 10, 'Kebabs', 2, 'https://images.unsplash.com/photo-1529006557810-274b9b2fc783?w=600&h=200&fit=crop', '{"_source":{"name":"Kebabs"},"en":{"name":"Kebabs"},"de":{"name":"Kebabs"}}'),
  (47, 10, 'Pide & Lahmacun', 3, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=200&fit=crop', '{"_source":{"name":"Pide & Lahmacun"},"en":{"name":"Pide & Lahmacun"},"de":{"name":"Pide & Lahmacun"}}'),
  (48, 10, 'Mains', 4, 'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=200&fit=crop', '{"_source":{"name":"Mains"},"en":{"name":"Mains"},"de":{"name":"Hauptgerichte"}}'),
  (49, 10, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Thai Orchid (Thai)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (50, 11, 'Appetizers', 1, 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=600&h=200&fit=crop', '{"_source":{"name":"Appetizers"},"en":{"name":"Appetizers"},"de":{"name":"Vorspeisen"}}'),
  (51, 11, 'Soups', 2, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop', '{"_source":{"name":"Soups"},"en":{"name":"Soups"},"de":{"name":"Suppen"}}'),
  (52, 11, 'Curries', 3, 'https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?w=600&h=200&fit=crop', '{"_source":{"name":"Curries"},"en":{"name":"Curries"},"de":{"name":"Currys"}}'),
  (53, 11, 'Stir-Fry', 4, 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&h=200&fit=crop', '{"_source":{"name":"Stir-Fry"},"en":{"name":"Stir-Fry"},"de":{"name":"Pfannengerichte"}}'),
  (54, 11, 'Noodles & Rice', 5, 'https://images.unsplash.com/photo-1555126634-323283e090fa?w=600&h=200&fit=crop', '{"_source":{"name":"Noodles & Rice"},"en":{"name":"Noodles & Rice"},"de":{"name":"Nudeln & Reis"}}'),
  (55, 11, 'Beverages', 6, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Seoul BBQ (Korean)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (56, 12, 'Appetizers', 1, 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&h=200&fit=crop', '{"_source":{"name":"Appetizers"},"en":{"name":"Appetizers"},"de":{"name":"Vorspeisen"}}'),
  (57, 12, 'BBQ Meats', 2, 'https://images.unsplash.com/photo-1558030137-a56c1b004fa6?w=600&h=200&fit=crop', '{"_source":{"name":"BBQ Meats"},"en":{"name":"BBQ Meats"},"de":{"name":"Grillfleiisch"}}'),
  (58, 12, 'Hot Pots', 3, 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=600&h=200&fit=crop', '{"_source":{"name":"Hot Pots"},"en":{"name":"Hot Pots"},"de":{"name":"Eintöpfe"}}'),
  (59, 12, 'Main Dishes', 4, 'https://images.unsplash.com/photo-1590301157890-4810ed352733?w=600&h=200&fit=crop', '{"_source":{"name":"Main Dishes"},"en":{"name":"Main Dishes"},"de":{"name":"Hauptgerichte"}}'),
  (60, 12, 'Beverages', 5, 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=600&h=200&fit=crop', '{"_source":{"name":"Beverages"},"en":{"name":"Beverages"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Categories for Tapas y Vino (Spanish)
INSERT INTO categories (id, restaurant_id, name, display_order, image_url, translations) VALUES
  (61, 13, 'Tapas Frías', 1, 'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=600&h=200&fit=crop', '{"_source":{"name":"Tapas Frías"},"en":{"name":"Cold Tapas"},"de":{"name":"Kalte Tapas"}}'),
  (62, 13, 'Tapas Calientes', 2, 'https://images.unsplash.com/photo-1534080564583-6be75777b70a?w=600&h=200&fit=crop', '{"_source":{"name":"Tapas Calientes"},"en":{"name":"Hot Tapas"},"de":{"name":"Warme Tapas"}}'),
  (63, 13, 'Raciones', 3, 'https://images.unsplash.com/photo-1534330207526-8e81f10ec6fc?w=600&h=200&fit=crop', '{"_source":{"name":"Raciones"},"en":{"name":"Large Plates"},"de":{"name":"Große Gerichte"}}'),
  (64, 13, 'Postres', 4, 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&h=200&fit=crop', '{"_source":{"name":"Postres"},"en":{"name":"Desserts"},"de":{"name":"Desserts"}}'),
  (65, 13, 'Bebidas', 5, 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=600&h=200&fit=crop', '{"_source":{"name":"Bebidas"},"en":{"name":"Drinks"},"de":{"name":"Getränke"}}')
ON CONFLICT (id) DO NOTHING;

-- Items for Golden Dragon (Chinese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Appetizers
  (1, 'Spring Rolls', '1', 4.50, 'Crispy vegetable spring rolls with sweet chili sauce', false, '{"_source":{"name":"Spring Rolls","desc":"Crispy vegetable spring rolls with sweet chili sauce"},"en":{"name":"Spring Rolls","description":"Crispy vegetable spring rolls with sweet chili sauce"},"de":{"name":"Frühlingsrollen","description":"Knusprige Gemüsefrühlingsrollen mit süß-scharfer Soße"}}'),
  (1, 'Dumplings', '2', 5.90, 'Steamed pork dumplings (6 pieces)', false, '{"_source":{"name":"Dumplings","desc":"Steamed pork dumplings (6 pieces)"},"en":{"name":"Dumplings","description":"Steamed pork dumplings (6 pieces)"},"de":{"name":"Dim Sum","description":"Gedämpfte Schweinefleisch-Dim-Sum (6 Stück)"}}'),
  (1, 'Sesame Prawn Toast', '3', 6.50, 'Crispy prawn toast with sesame seeds', false, '{"_source":{"name":"Sesame Prawn Toast","desc":"Crispy prawn toast with sesame seeds"},"en":{"name":"Sesame Prawn Toast","description":"Crispy prawn toast with sesame seeds"},"de":{"name":"Sesam-Garnelen-Toast","description":"Knuspriger Garnelen-Toast mit Sesamsamen"}}'),
  -- Soups
  (2, 'Hot & Sour Soup', '4', 4.20, 'Spicy and tangy soup with tofu and mushrooms', false, '{"_source":{"name":"Hot & Sour Soup","desc":"Spicy and tangy soup with tofu and mushrooms"},"en":{"name":"Hot & Sour Soup","description":"Spicy and tangy soup with tofu and mushrooms"},"de":{"name":"Scharf-Saure Suppe","description":"Würzige und säuerliche Suppe mit Tofu und Pilzen"}}'),
  (2, 'Wonton Soup', '5', 4.80, 'Clear broth with handmade wontons', false, '{"_source":{"name":"Wonton Soup","desc":"Clear broth with handmade wontons"},"en":{"name":"Wonton Soup","description":"Clear broth with handmade wontons"},"de":{"name":"Wonton-Suppe","description":"Klare Brühe mit hausgemachten Wontons"}}'),
  -- Main Dishes
  (3, 'Kung Pao Chicken', '6', 11.90, 'Spicy chicken with peanuts and vegetables', false, '{"_source":{"name":"Kung Pao Chicken","desc":"Spicy chicken with peanuts and vegetables"},"en":{"name":"Kung Pao Chicken","description":"Spicy chicken with peanuts and vegetables"},"de":{"name":"Kung-Pao-Hähnchen","description":"Scharfes Hähnchen mit Erdnüssen und Gemüse"}}'),
  (3, 'Sweet & Sour Pork', '7', 10.50, 'Crispy pork in sweet and sour sauce', false, '{"_source":{"name":"Sweet & Sour Pork","desc":"Crispy pork in sweet and sour sauce"},"en":{"name":"Sweet & Sour Pork","description":"Crispy pork in sweet and sour sauce"},"de":{"name":"Süß-Saures Schweinefleisch","description":"Knuspriges Schweinefleisch in süß-saurer Soße"}}'),
  (3, 'Beef with Broccoli', '8', 12.50, 'Tender beef stir-fried with fresh broccoli', false, '{"_source":{"name":"Beef with Broccoli","desc":"Tender beef stir-fried with fresh broccoli"},"en":{"name":"Beef with Broccoli","description":"Tender beef stir-fried with fresh broccoli"},"de":{"name":"Rindfleisch mit Brokkoli","description":"Zartes Rindfleisch mit frischem Brokkoli"}}'),
  (3, 'Fried Rice with Vegetables', '9', 8.90, 'Classic fried rice with mixed vegetables', false, '{"_source":{"name":"Fried Rice with Vegetables","desc":"Classic fried rice with mixed vegetables"},"en":{"name":"Fried Rice with Vegetables","description":"Classic fried rice with mixed vegetables"},"de":{"name":"Gebratener Reis mit Gemüse","description":"Klassischer gebratener Reis mit gemischtem Gemüse"}}'),
  -- Beverages
  (4, 'Jasmine Tea', '10', 2.50, 'Traditional Chinese jasmine tea', false, '{"_source":{"name":"Jasmine Tea","desc":"Traditional Chinese jasmine tea"},"en":{"name":"Jasmine Tea","description":"Traditional Chinese jasmine tea"},"de":{"name":"Jasmintee","description":"Traditioneller chinesischer Jasmintee"}}'),
  (4, 'Tsingtao Beer', '11', 3.80, 'Chinese lager beer (330ml)', false, '{"_source":{"name":"Tsingtao Beer","desc":"Chinese lager beer (330ml)"},"en":{"name":"Tsingtao Beer","description":"Chinese lager beer (330ml)"},"de":{"name":"Tsingtao-Bier","description":"Chinesisches Lagerbier (330ml)"}}')
ON CONFLICT DO NOTHING;

-- Items for La Bella Vita (Italian)
INSERT INTO items (id, category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Antipasti
  (101, 5, 'Bruschetta', '1', 5.50, 'Toasted bread with fresh tomatoes, garlic, and basil', false, '{"_source":{"name":"Bruschetta","desc":"Toasted bread with fresh tomatoes, garlic, and basil"},"en":{"name":"Bruschetta","description":"Toasted bread with fresh tomatoes, garlic, and basil"},"de":{"name":"Bruschetta","description":"Geröstetes Brot mit frischen Tomaten, Knoblauch und Basilikum"}}'),
  (102, 5, 'Caprese Salad', '2', 7.90, 'Buffalo mozzarella, tomatoes, and fresh basil', false, '{"_source":{"name":"Caprese Salad","desc":"Buffalo mozzarella, tomatoes, and fresh basil"},"en":{"name":"Caprese Salad","description":"Buffalo mozzarella, tomatoes, and fresh basil"},"de":{"name":"Caprese-Salat","description":"Büffelmozzarella, Tomaten und frisches Basilikum"}}'),
  (103, 5, 'Antipasto Misto', '3', 9.50, 'Mixed Italian cold cuts and cheeses', false, '{"_source":{"name":"Antipasto Misto","desc":"Mixed Italian cold cuts and cheeses"},"en":{"name":"Antipasto Misto","description":"Mixed Italian cold cuts and cheeses"},"de":{"name":"Gemischte Antipasti","description":"Gemischte italienische Aufschnitte und Käse"}}'),
  -- Pizza (with size variants)
  (104, 6, 'Margherita', '4', NULL, 'Tomato sauce, mozzarella, and fresh basil', true, '{"_source":{"name":"Margherita","desc":"Tomato sauce, mozzarella, and fresh basil"},"en":{"name":"Margherita","description":"Tomato sauce, mozzarella, and fresh basil"},"de":{"name":"Margherita","description":"Tomatensoße, Mozzarella und frisches Basilikum"}}'),
  (105, 6, 'Quattro Formaggi', '5', NULL, 'Four cheese pizza with gorgonzola, mozzarella, parmesan, and fontina', true, '{"_source":{"name":"Quattro Formaggi","desc":"Four cheese pizza with gorgonzola, mozzarella, parmesan, and fontina"},"en":{"name":"Quattro Formaggi","description":"Four cheese pizza with gorgonzola, mozzarella, parmesan, and fontina"},"de":{"name":"Vier-Käse-Pizza","description":"Pizza mit Gorgonzola, Mozzarella, Parmesan und Fontina"}}'),
  (106, 6, 'Diavola', '6', NULL, 'Spicy salami, tomato sauce, and mozzarella', true, '{"_source":{"name":"Diavola","desc":"Spicy salami, tomato sauce, and mozzarella"},"en":{"name":"Diavola","description":"Spicy salami, tomato sauce, and mozzarella"},"de":{"name":"Diavola","description":"Scharfe Salami, Tomatensoße und Mozzarella"}}'),
  -- Pasta
  (107, 7, 'Spaghetti Carbonara', '7', 9.50, 'Creamy sauce with pancetta and egg yolk', false, '{"_source":{"name":"Spaghetti Carbonara","desc":"Creamy sauce with pancetta and egg yolk"},"en":{"name":"Spaghetti Carbonara","description":"Creamy sauce with pancetta and egg yolk"},"de":{"name":"Spaghetti Carbonara","description":"Cremige Soße mit Pancetta und Eigelb"}}'),
  (108, 7, 'Penne Arrabiata', '8', 8.90, 'Spicy tomato sauce with garlic and chili', false, '{"_source":{"name":"Penne Arrabiata","desc":"Spicy tomato sauce with garlic and chili"},"en":{"name":"Penne Arrabiata","description":"Spicy tomato sauce with garlic and chili"},"de":{"name":"Penne all''Arrabbiata","description":"Scharfe Tomatensoße mit Knoblauch und Chili"}}'),
  (109, 7, 'Lasagna al Forno', '9', 11.50, 'Homemade lasagna with meat sauce and béchamel', false, '{"_source":{"name":"Lasagna al Forno","desc":"Homemade lasagna with meat sauce and béchamel"},"en":{"name":"Lasagna al Forno","description":"Homemade lasagna with meat sauce and béchamel"},"de":{"name":"Lasagna al Forno","description":"Hausgemachte Lasagne mit Fleischsoße und Béchamel"}}'),
  -- Desserts
  (110, 8, 'Tiramisu', '10', 5.90, 'Classic Italian dessert with mascarpone and coffee', false, '{"_source":{"name":"Tiramisu","desc":"Classic Italian dessert with mascarpone and coffee"},"en":{"name":"Tiramisu","description":"Classic Italian dessert with mascarpone and coffee"},"de":{"name":"Tiramisù","description":"Klassisches italienisches Dessert mit Mascarpone und Kaffee"}}'),
  (111, 8, 'Panna Cotta', '11', 5.50, 'Vanilla cream with berry sauce', false, '{"_source":{"name":"Panna Cotta","desc":"Vanilla cream with berry sauce"},"en":{"name":"Panna Cotta","description":"Vanilla cream with berry sauce"},"de":{"name":"Panna Cotta","description":"Vanillecreme mit Beerensoße"}}'),
  -- Drinks
  (112, 9, 'Espresso', '12', 2.20, 'Italian espresso coffee', false, '{"_source":{"name":"Espresso","desc":"Italian espresso coffee"},"en":{"name":"Espresso","description":"Italian espresso coffee"},"de":{"name":"Espresso","description":"Italienischer Espresso"}}'),
  (113, 9, 'House Wine (glass)', '13', 4.50, 'Red or white wine', false, '{"_source":{"name":"House Wine (glass)","desc":"Red or white wine"},"en":{"name":"House Wine (glass)","description":"Red or white wine"},"de":{"name":"Hauswein (Glas)","description":"Rot- oder Weißwein"}}')
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
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Mezze
  (10, 'Tzatziki', '1', 4.50, 'Greek yogurt dip with cucumber and garlic', false, '{"_source":{"name":"Tzatziki","desc":"Greek yogurt dip with cucumber and garlic"},"en":{"name":"Tzatziki","description":"Greek yogurt dip with cucumber and garlic"},"de":{"name":"Tzatziki","description":"Griechischer Joghurt-Dip mit Gurke und Knoblauch"}}'),
  (10, 'Taramosalata', '2', 5.20, 'Fish roe dip with lemon and olive oil', false, '{"_source":{"name":"Taramosalata","desc":"Fish roe dip with lemon and olive oil"},"en":{"name":"Taramosalata","description":"Fish roe dip with lemon and olive oil"},"de":{"name":"Taramosalata","description":"Fischrogen-Dip mit Zitrone und Olivenöl"}}'),
  (10, 'Dolmades', '3', 5.90, 'Stuffed grape leaves with rice and herbs', false, '{"_source":{"name":"Dolmades","desc":"Stuffed grape leaves with rice and herbs"},"en":{"name":"Dolmades","description":"Stuffed grape leaves with rice and herbs"},"de":{"name":"Dolmades","description":"Gefüllte Weinblätter mit Reis und Kräutern"}}'),
  (10, 'Greek Salad', '4', 6.50, 'Tomatoes, cucumber, feta cheese, olives, and onions', false, '{"_source":{"name":"Greek Salad","desc":"Tomatoes, cucumber, feta cheese, olives, and onions"},"en":{"name":"Greek Salad","description":"Tomatoes, cucumber, feta cheese, olives, and onions"},"de":{"name":"Griechischer Salat","description":"Tomaten, Gurke, Feta, Oliven und Zwiebeln"}}'),
  -- Grilled Specialties
  (11, 'Souvlaki', '5', 11.90, 'Grilled pork skewers with pita bread and tzatziki', false, '{"_source":{"name":"Souvlaki","desc":"Grilled pork skewers with pita bread and tzatziki"},"en":{"name":"Souvlaki","description":"Grilled pork skewers with pita bread and tzatziki"},"de":{"name":"Souvlaki","description":"Gegrillte Schweinefleischschpieße mit Pita und Tzatziki"}}'),
  (11, 'Gyros Plate', '6', 10.50, 'Traditional gyros with fries, salad, and tzatziki', false, '{"_source":{"name":"Gyros Plate","desc":"Traditional gyros with fries, salad, and tzatziki"},"en":{"name":"Gyros Plate","description":"Traditional gyros with fries, salad, and tzatziki"},"de":{"name":"Gyrosteller","description":"Traditioneller Gyros mit Pommes, Salat und Tzatziki"}}'),
  (11, 'Lamb Chops', '7', 16.90, 'Grilled lamb chops with lemon potatoes', false, '{"_source":{"name":"Lamb Chops","desc":"Grilled lamb chops with lemon potatoes"},"en":{"name":"Lamb Chops","description":"Grilled lamb chops with lemon potatoes"},"de":{"name":"Lammkoteletts","description":"Gegrillte Lammkoteletts mit Zitronenkartoffeln"}}'),
  -- Traditional Dishes
  (12, 'Moussaka', '8', 12.50, 'Baked eggplant with minced meat and béchamel sauce', false, '{"_source":{"name":"Moussaka","desc":"Baked eggplant with minced meat and béchamel sauce"},"en":{"name":"Moussaka","description":"Baked eggplant with minced meat and béchamel sauce"},"de":{"name":"Moussaka","description":"Überbackene Aubergine mit Hackfleisch und Béchamelsoße"}}'),
  (12, 'Pastitsio', '9', 11.90, 'Greek pasta bake with meat sauce and cheese', false, '{"_source":{"name":"Pastitsio","desc":"Greek pasta bake with meat sauce and cheese"},"en":{"name":"Pastitsio","description":"Greek pasta bake with meat sauce and cheese"},"de":{"name":"Pastitsio","description":"Griechischer Nudelauflauf mit Fleischsoße und Käse"}}'),
  (12, 'Spanakopita', '10', 9.50, 'Spinach and feta cheese pie in phyllo pastry', false, '{"_source":{"name":"Spanakopita","desc":"Spinach and feta cheese pie in phyllo pastry"},"en":{"name":"Spanakopita","description":"Spinach and feta cheese pie in phyllo pastry"},"de":{"name":"Spanakopita","description":"Spinat-Feta-Torte im Filoteig"}}'),
  -- Beverages
  (13, 'Greek Coffee', '11', 2.80, 'Traditional Greek coffee', false, '{"_source":{"name":"Greek Coffee","desc":"Traditional Greek coffee"},"en":{"name":"Greek Coffee","description":"Traditional Greek coffee"},"de":{"name":"Griechischer Kaffee","description":"Traditioneller griechischer Kaffee"}}'),
  (13, 'Ouzo', '12', 3.50, 'Greek anise-flavored aperitif', false, '{"_source":{"name":"Ouzo","desc":"Greek anise-flavored aperitif"},"en":{"name":"Ouzo","description":"Greek anise-flavored aperitif"},"de":{"name":"Ouzo","description":"Griechischer Anisaperitivschnaps"}}'),
  (13, 'Mythos Beer', '13', 3.80, 'Greek lager beer (330ml)', false, '{"_source":{"name":"Mythos Beer","desc":"Greek lager beer (330ml)"},"en":{"name":"Mythos Beer","description":"Greek lager beer (330ml)"},"de":{"name":"Mythos-Bier","description":"Griechisches Lagerbier (330ml)"}}')
ON CONFLICT DO NOTHING;

-- Items for Sushi Heaven (Japanese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Nigiri
  (14, 'Salmon Nigiri', '1a', 4.50, 'Fresh salmon on seasoned rice (2 pieces)', false, '{"_source":{"name":"Salmon Nigiri","desc":"Fresh salmon on seasoned rice (2 pieces)"},"en":{"name":"Salmon Nigiri","description":"Fresh salmon on seasoned rice (2 pieces)"},"de":{"name":"Lachs-Nigiri","description":"Frischer Lachs auf gewürztem Reis (2 Stück)"}}'),
  (14, 'Tuna Nigiri', '1b', 5.20, 'Premium tuna on seasoned rice (2 pieces)', false, '{"_source":{"name":"Tuna Nigiri","desc":"Premium tuna on seasoned rice (2 pieces)"},"en":{"name":"Tuna Nigiri","description":"Premium tuna on seasoned rice (2 pieces)"},"de":{"name":"Thunfisch-Nigiri","description":"Premium-Thunfisch auf gewürztem Reis (2 Stück)"}}'),
  (14, 'Eel Nigiri', '1c', 5.50, 'Grilled eel with sweet sauce (2 pieces)', false, '{"_source":{"name":"Eel Nigiri","desc":"Grilled eel with sweet sauce (2 pieces)"},"en":{"name":"Eel Nigiri","description":"Grilled eel with sweet sauce (2 pieces)"},"de":{"name":"Aal-Nigiri","description":"Gegrillter Aal mit süßer Soße (2 Stück)"}}'),
  -- Maki Rolls
  (15, 'California Roll', '2a', 6.90, 'Crab, avocado, and cucumber', false, '{"_source":{"name":"California Roll","desc":"Crab, avocado, and cucumber"},"en":{"name":"California Roll","description":"Crab, avocado, and cucumber"},"de":{"name":"California Roll","description":"Krebsfleisch, Avocado und Gurke"}}'),
  (15, 'Spicy Tuna Roll', '2b', 7.50, 'Tuna with spicy mayo and sesame', false, '{"_source":{"name":"Spicy Tuna Roll","desc":"Tuna with spicy mayo and sesame"},"en":{"name":"Spicy Tuna Roll","description":"Tuna with spicy mayo and sesame"},"de":{"name":"Würzige Thunfisch-Rolle","description":"Thunfisch mit scharfer Mayo und Sesam"}}'),
  (15, 'Salmon Avocado Roll', '2c', 7.20, 'Fresh salmon and avocado', false, '{"_source":{"name":"Salmon Avocado Roll","desc":"Fresh salmon and avocado"},"en":{"name":"Salmon Avocado Roll","description":"Fresh salmon and avocado"},"de":{"name":"Lachs-Avocado-Rolle","description":"Frischer Lachs und Avocado"}}'),
  -- Special Rolls
  (16, 'Dragon Roll', '3a', 12.90, 'Eel, cucumber, topped with avocado', false, '{"_source":{"name":"Dragon Roll","desc":"Eel, cucumber, topped with avocado"},"en":{"name":"Dragon Roll","description":"Eel, cucumber, topped with avocado"},"de":{"name":"Drachen-Rolle","description":"Aal, Gurke, mit Avocado belegt"}}'),
  (16, 'Rainbow Roll', '3b', 13.50, 'California roll topped with assorted fish', false, '{"_source":{"name":"Rainbow Roll","desc":"California roll topped with assorted fish"},"en":{"name":"Rainbow Roll","description":"California roll topped with assorted fish"},"de":{"name":"Regenbogen-Rolle","description":"California Roll mit verschiedenen Fischsorten belegt"}}'),
  -- Sashimi
  (17, 'Salmon Sashimi', '4', 11.50, 'Fresh salmon slices (8 pieces)', false, '{"_source":{"name":"Salmon Sashimi","desc":"Fresh salmon slices (8 pieces)"},"en":{"name":"Salmon Sashimi","description":"Fresh salmon slices (8 pieces)"},"de":{"name":"Lachs-Sashimi","description":"Frische Lachsscheiben (8 Stück)"}}'),
  (17, 'Mixed Sashimi', '5', 15.90, 'Assorted fresh fish (12 pieces)', false, '{"_source":{"name":"Mixed Sashimi","desc":"Assorted fresh fish (12 pieces)"},"en":{"name":"Mixed Sashimi","description":"Assorted fresh fish (12 pieces)"},"de":{"name":"Gemischtes Sashimi","description":"Verschiedene frische Fischsorten (12 Stück)"}}'),
  -- Drinks
  (18, 'Green Tea', '6', 2.50, 'Hot Japanese green tea', false, '{"_source":{"name":"Green Tea","desc":"Hot Japanese green tea"},"en":{"name":"Green Tea","description":"Hot Japanese green tea"},"de":{"name":"Grüner Tee","description":"Heißer japanischer grüner Tee"}}'),
  (18, 'Sake', '7', 5.50, 'Japanese rice wine (100ml)', false, '{"_source":{"name":"Sake","desc":"Japanese rice wine (100ml)"},"en":{"name":"Sake","description":"Japanese rice wine (100ml)"},"de":{"name":"Sake","description":"Japanischer Reiswein (100ml)"}}')
ON CONFLICT DO NOTHING;

-- Items for Curry Palace (Indian)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Starters
  (19, 'Samosas', '1', 4.50, 'Crispy pastries filled with spiced potatoes (2 pieces)', false, '{"_source":{"name":"Samosas","desc":"Crispy pastries filled with spiced potatoes (2 pieces)"},"en":{"name":"Samosas","description":"Crispy pastries filled with spiced potatoes (2 pieces)"},"de":{"name":"Samosas","description":"Knusprige Teigtaschen mit gewürzten Kartoffeln (2 Stück)"}}'),
  (19, 'Pakoras', '2', 5.20, 'Mixed vegetable fritters', false, '{"_source":{"name":"Pakoras","desc":"Mixed vegetable fritters"},"en":{"name":"Pakoras","description":"Mixed vegetable fritters"},"de":{"name":"Pakoras","description":"Gemischte Gemüseküchle"}}'),
  (19, 'Chicken Tikka', '3', 6.90, 'Marinated chicken pieces from tandoor', false, '{"_source":{"name":"Chicken Tikka","desc":"Marinated chicken pieces from tandoor"},"en":{"name":"Chicken Tikka","description":"Marinated chicken pieces from tandoor"},"de":{"name":"Chicken Tikka","description":"Marinierte Hühnchenstücke aus dem Tandoor"}}'),
  -- Tandoori
  (20, 'Tandoori Chicken', '4', 11.90, 'Half chicken marinated in yogurt and spices', false, '{"_source":{"name":"Tandoori Chicken","desc":"Half chicken marinated in yogurt and spices"},"en":{"name":"Tandoori Chicken","description":"Half chicken marinated in yogurt and spices"},"de":{"name":"Tandoori-Hähnchen","description":"Halbes Hähnchen in Joghurt und Gewürzen mariniert"}}'),
  (20, 'Lamb Seekh Kebab', '5', 12.50, 'Minced lamb kebabs with Indian spices', false, '{"_source":{"name":"Lamb Seekh Kebab","desc":"Minced lamb kebabs with Indian spices"},"en":{"name":"Lamb Seekh Kebab","description":"Minced lamb kebabs with Indian spices"},"de":{"name":"Lammhackfleisch-Kebab","description":"Hackfleischspieße vom Lamm mit indischen Gewürzen"}}'),
  (20, 'Paneer Tikka', '6', 10.50, 'Grilled cottage cheese with peppers', false, '{"_source":{"name":"Paneer Tikka","desc":"Grilled cottage cheese with peppers"},"en":{"name":"Paneer Tikka","description":"Grilled cottage cheese with peppers"},"de":{"name":"Paneer Tikka","description":"Gegrillter Hüttenkäse mit Paprika"}}'),
  -- Curries
  (21, 'Butter Chicken', '7', 12.90, 'Creamy tomato curry with tender chicken', false, '{"_source":{"name":"Butter Chicken","desc":"Creamy tomato curry with tender chicken"},"en":{"name":"Butter Chicken","description":"Creamy tomato curry with tender chicken"},"de":{"name":"Butter Chicken","description":"Cremiges Tomatencurry mit zartem Hähnchen"}}'),
  (21, 'Lamb Rogan Josh', '8', 13.50, 'Aromatic lamb curry with Kashmiri spices', false, '{"_source":{"name":"Lamb Rogan Josh","desc":"Aromatic lamb curry with Kashmiri spices"},"en":{"name":"Lamb Rogan Josh","description":"Aromatic lamb curry with Kashmiri spices"},"de":{"name":"Lammfleisch Rogan Josh","description":"Würziges Lammcurry mit Kaschmir-Gewürzen"}}'),
  (21, 'Palak Paneer', '9', 10.90, 'Spinach curry with cottage cheese', false, '{"_source":{"name":"Palak Paneer","desc":"Spinach curry with cottage cheese"},"en":{"name":"Palak Paneer","description":"Spinach curry with cottage cheese"},"de":{"name":"Palak Paneer","description":"Spinatcurry mit Hüttenkäse"}}'),
  (21, 'Chicken Vindaloo', '10', 12.50, 'Spicy and tangy Goan curry', false, '{"_source":{"name":"Chicken Vindaloo","desc":"Spicy and tangy Goan curry"},"en":{"name":"Chicken Vindaloo","description":"Spicy and tangy Goan curry"},"de":{"name":"Hähnchen Vindaloo","description":"Scharfes und würziges Goa-Curry"}}'),
  -- Biryani & Rice
  (22, 'Chicken Biryani', '11', 11.90, 'Fragrant rice with spiced chicken', false, '{"_source":{"name":"Chicken Biryani","desc":"Fragrant rice with spiced chicken"},"en":{"name":"Chicken Biryani","description":"Fragrant rice with spiced chicken"},"de":{"name":"Hähnchen-Biryani","description":"Aromatischer Reis mit gewürztem Hähnchen"}}'),
  (22, 'Lamb Biryani', '12', 13.50, 'Basmati rice with tender lamb', false, '{"_source":{"name":"Lamb Biryani","desc":"Basmati rice with tender lamb"},"en":{"name":"Lamb Biryani","description":"Basmati rice with tender lamb"},"de":{"name":"Lamm-Biryani","description":"Basmatireis mit zartem Lammfleisch"}}'),
  (22, 'Vegetable Biryani', '13', 9.90, 'Rice with mixed vegetables and spices', false, '{"_source":{"name":"Vegetable Biryani","desc":"Rice with mixed vegetables and spices"},"en":{"name":"Vegetable Biryani","description":"Rice with mixed vegetables and spices"},"de":{"name":"Gemüse-Biryani","description":"Reis mit gemischtem Gemüse und Gewürzen"}}'),
  -- Breads
  (23, 'Naan', '14', 2.50, 'Traditional Indian bread', false, '{"_source":{"name":"Naan","desc":"Traditional Indian bread"},"en":{"name":"Naan","description":"Traditional Indian bread"},"de":{"name":"Naan","description":"Traditionelles indisches Fladenbrot"}}'),
  (23, 'Garlic Naan', '15', 3.20, 'Naan with garlic and butter', false, '{"_source":{"name":"Garlic Naan","desc":"Naan with garlic and butter"},"en":{"name":"Garlic Naan","description":"Naan with garlic and butter"},"de":{"name":"Knoblauch-Naan","description":"Naan mit Knoblauch und Butter"}}'),
  (23, 'Paratha', '16', 3.50, 'Layered flatbread', false, '{"_source":{"name":"Paratha","desc":"Layered flatbread"},"en":{"name":"Paratha","description":"Layered flatbread"},"de":{"name":"Paratha","description":"Geschichtetes Fladenbrot"}}'),
  -- Beverages
  (24, 'Mango Lassi', '17', 3.80, 'Sweet yogurt drink with mango', false, '{"_source":{"name":"Mango Lassi","desc":"Sweet yogurt drink with mango"},"en":{"name":"Mango Lassi","description":"Sweet yogurt drink with mango"},"de":{"name":"Mango-Lassi","description":"Süßes Joghurtgetränk mit Mango"}}'),
  (24, 'Masala Chai', '18', 2.50, 'Spiced Indian tea', false, '{"_source":{"name":"Masala Chai","desc":"Spiced Indian tea"},"en":{"name":"Masala Chai","description":"Spiced Indian tea"},"de":{"name":"Masala-Chai","description":"Gewürzter indischer Tee"}}')
ON CONFLICT DO NOTHING;

-- Items for Le Bistro Parisien (French)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Entrées
  (25, 'French Onion Soup', '1', 7.50, 'Classic soup with caramelized onions and gruyère', false, '{"_source":{"name":"French Onion Soup","desc":"Classic soup with caramelized onions and gruyère"},"en":{"name":"French Onion Soup","description":"Classic soup with caramelized onions and gruyère"},"de":{"name":"Französische Zwiebelsuppe","description":"Klassische Suppe mit karamellisierten Zwiebeln und Gruyère"}}'),
  (25, 'Escargots de Bourgogne', '2', 9.90, 'Burgundy snails with garlic butter (6 pieces)', false, '{"_source":{"name":"Escargots de Bourgogne","desc":"Burgundy snails with garlic butter (6 pieces)"},"en":{"name":"Escargots de Bourgogne","description":"Burgundy snails with garlic butter (6 pieces)"},"de":{"name":"Weinbergschnecken Burgunder Art","description":"Burgunder Schnecken mit Knoblauchbutter (6 Stück)"}}'),
  (25, 'Pâté de Campagne', '3', 8.50, 'Country-style pâté with cornichons', false, '{"_source":{"name":"Pâté de Campagne","desc":"Country-style pâté with cornichons"},"en":{"name":"Pâté de Campagne","description":"Country-style pâté with cornichons"},"de":{"name":"Landpastete","description":"Pastete nach Landart mit Cornichons"}}'),
  -- Plats Principaux
  (26, 'Coq au Vin', '4', 18.90, 'Chicken braised in red wine with mushrooms', false, '{"_source":{"name":"Coq au Vin","desc":"Chicken braised in red wine with mushrooms"},"en":{"name":"Coq au Vin","description":"Chicken braised in red wine with mushrooms"},"de":{"name":"Coq au Vin","description":"Hähnchen geschmort in Rotwein mit Pilzen"}}'),
  (26, 'Boeuf Bourguignon', '5', 21.50, 'Beef stew with burgundy wine and vegetables', false, '{"_source":{"name":"Boeuf Bourguignon","desc":"Beef stew with burgundy wine and vegetables"},"en":{"name":"Boeuf Bourguignon","description":"Beef stew with burgundy wine and vegetables"},"de":{"name":"Boeuf Bourguignon","description":"Rindfleischeintopf mit Burgunderweein und Gemüse"}}'),
  (26, 'Sole Meunière', '6', 19.90, 'Pan-fried sole with lemon butter sauce', false, '{"_source":{"name":"Sole Meunière","desc":"Pan-fried sole with lemon butter sauce"},"en":{"name":"Sole Meunière","description":"Pan-fried sole with lemon butter sauce"},"de":{"name":"Seezunge Meunière","description":"Gebratene Seezunge mit Zitronenbutter"}}'),
  (26, 'Steak Frites', '7', 22.50, 'Ribeye steak with french fries', false, '{"_source":{"name":"Steak Frites","desc":"Ribeye steak with french fries"},"en":{"name":"Steak Frites","description":"Ribeye steak with french fries"},"de":{"name":"Steak mit Pommes frites","description":"Ribeye-Steak mit Pommes frites"}}'),
  -- Fromages
  (27, 'Cheese Plate', '8', 12.50, 'Selection of French cheeses', false, '{"_source":{"name":"Cheese Plate","desc":"Selection of French cheeses"},"en":{"name":"Cheese Plate","description":"Selection of French cheeses"},"de":{"name":"Käseplatte","description":"Auswahl französischer Käsesorten"}}'),
  -- Desserts
  (28, 'Crème Brûlée', '9', 7.50, 'Vanilla custard with caramelized sugar', false, '{"_source":{"name":"Crème Brûlée","desc":"Vanilla custard with caramelized sugar"},"en":{"name":"Crème Brûlée","description":"Vanilla custard with caramelized sugar"},"de":{"name":"Crème Brûlée","description":"Vanillepudding mit karamellisiertem Zucker"}}'),
  (28, 'Tarte Tatin', '10', 8.20, 'Upside-down caramelized apple tart', false, '{"_source":{"name":"Tarte Tatin","desc":"Upside-down caramelized apple tart"},"en":{"name":"Tarte Tatin","description":"Upside-down caramelized apple tart"},"de":{"name":"Tarte Tatin","description":"Gestürzte karamellisierte Apfeltarte"}}'),
  (28, 'Mousse au Chocolat', '11', 7.90, 'Rich chocolate mousse', false, '{"_source":{"name":"Mousse au Chocolat","desc":"Rich chocolate mousse"},"en":{"name":"Mousse au Chocolat","description":"Rich chocolate mousse"},"de":{"name":"Mousse au Chocolat","description":"Schokoladenmousse"}}'),
  -- Vins
  (29, 'Bordeaux (glass)', '12', 6.50, 'Red wine from Bordeaux', false, '{"_source":{"name":"Bordeaux (glass)","desc":"Red wine from Bordeaux"},"en":{"name":"Bordeaux (glass)","description":"Red wine from Bordeaux"},"de":{"name":"Bordeaux (Glas)","description":"Rotwein aus Bordeaux"}}'),
  (29, 'Champagne (glass)', '13', 9.90, 'French sparkling wine', false, '{"_source":{"name":"Champagne (glass)","desc":"French sparkling wine"},"en":{"name":"Champagne (glass)","description":"French sparkling wine"},"de":{"name":"Champagner (Glas)","description":"Französischer Sekt"}}')
ON CONFLICT DO NOTHING;

-- Items for Taco Fiesta (Mexican)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Antojitos
  (30, 'Nachos Supreme', '1', 7.90, 'Tortilla chips with cheese, jalapeños, and salsa', false, '{"_source":{"name":"Nachos Supreme","desc":"Tortilla chips with cheese, jalapeños, and salsa"},"en":{"name":"Nachos Supreme","description":"Tortilla chips with cheese, jalapeños, and salsa"},"de":{"name":"Nachos Supreme","description":"Tortilla-Chips mit Käse, Jalapeños und Salsa"}}'),
  (30, 'Guacamole & Chips', '2', 6.50, 'Fresh avocado dip with tortilla chips', false, '{"_source":{"name":"Guacamole & Chips","desc":"Fresh avocado dip with tortilla chips"},"en":{"name":"Guacamole & Chips","description":"Fresh avocado dip with tortilla chips"},"de":{"name":"Guacamole & Chips","description":"Frischer Avocado-Dip mit Tortilla-Chips"}}'),
  (30, 'Quesito Fundido', '3', 5.90, 'Melted cheese with chorizo', false, '{"_source":{"name":"Quesito Fundido","desc":"Melted cheese with chorizo"},"en":{"name":"Quesito Fundido","description":"Melted cheese with chorizo"},"de":{"name":"Geschmolzener Käse mit Chorizo","description":"Geschmolzener Käse mit Chorizo"}}'),
  -- Tacos
  (31, 'Carne Asada Taco', '4', 3.90, 'Grilled beef with onions and cilantro', false, '{"_source":{"name":"Carne Asada Taco","desc":"Grilled beef with onions and cilantro"},"en":{"name":"Carne Asada Taco","description":"Grilled beef with onions and cilantro"},"de":{"name":"Carne-Asada-Taco","description":"Gegrilltes Rindfleisch mit Zwiebeln und Koriander"}}'),
  (31, 'Al Pastor Taco', '5', 3.70, 'Marinated pork with pineapple', false, '{"_source":{"name":"Al Pastor Taco","desc":"Marinated pork with pineapple"},"en":{"name":"Al Pastor Taco","description":"Marinated pork with pineapple"},"de":{"name":"Al-Pastor-Taco","description":"Mariniertes Schweinefleisch mit Ananas"}}'),
  (31, 'Fish Taco', '6', 4.20, 'Battered fish with cabbage slaw', false, '{"_source":{"name":"Fish Taco","desc":"Battered fish with cabbage slaw"},"en":{"name":"Fish Taco","description":"Battered fish with cabbage slaw"},"de":{"name":"Fisch-Taco","description":"Frittierter Fisch mit Kohlsalat"}}'),
  (31, 'Veggie Taco', '7', 3.50, 'Grilled vegetables with black beans', false, '{"_source":{"name":"Veggie Taco","desc":"Grilled vegetables with black beans"},"en":{"name":"Veggie Taco","description":"Grilled vegetables with black beans"},"de":{"name":"Veggie-Taco","description":"Gegrilltes Gemüse mit schwarzen Bohnen"}}'),
  -- Burritos & Quesadillas
  (32, 'Beef Burrito', '8', 9.90, 'Large tortilla with beef, rice, beans, and cheese', false, '{"_source":{"name":"Beef Burrito","desc":"Large tortilla with beef, rice, beans, and cheese"},"en":{"name":"Beef Burrito","description":"Large tortilla with beef, rice, beans, and cheese"},"de":{"name":"Rindfleisch-Burrito","description":"Große Tortilla mit Rindfleisch, Reis, Bohnen und Käse"}}'),
  (32, 'Chicken Quesadilla', '9', 8.50, 'Grilled tortilla with chicken and cheese', false, '{"_source":{"name":"Chicken Quesadilla","desc":"Grilled tortilla with chicken and cheese"},"en":{"name":"Chicken Quesadilla","description":"Grilled tortilla with chicken and cheese"},"de":{"name":"Hähnchen-Quesadilla","description":"Gegrillte Tortilla mit Hähnchen und Käse"}}'),
  (32, 'Veggie Burrito', '10', 8.90, 'Rice, beans, vegetables, and guacamole', false, '{"_source":{"name":"Veggie Burrito","desc":"Rice, beans, vegetables, and guacamole"},"en":{"name":"Veggie Burrito","description":"Rice, beans, vegetables, and guacamole"},"de":{"name":"Veggie-Burrito","description":"Reis, Bohnen, Gemüse und Guacamole"}}'),
  -- Mains
  (33, 'Enchiladas', '11', 11.50, 'Rolled tortillas with chicken and cheese sauce', false, '{"_source":{"name":"Enchiladas","desc":"Rolled tortillas with chicken and cheese sauce"},"en":{"name":"Enchiladas","description":"Rolled tortillas with chicken and cheese sauce"},"de":{"name":"Enchiladas","description":"Gerollte Tortillas mit Hähnchen und Käsesoße"}}'),
  (33, 'Fajitas', '12', 13.90, 'Sizzling beef or chicken with peppers and onions', false, '{"_source":{"name":"Fajitas","desc":"Sizzling beef or chicken with peppers and onions"},"en":{"name":"Fajitas","description":"Sizzling beef or chicken with peppers and onions"},"de":{"name":"Fajitas","description":"Rindfleisch oder Hähnchen mit Paprika und Zwiebeln"}}'),
  -- Drinks
  (34, 'Margarita', '13', 7.50, 'Classic tequila cocktail', false, '{"_source":{"name":"Margarita","desc":"Classic tequila cocktail"},"en":{"name":"Margarita","description":"Classic tequila cocktail"},"de":{"name":"Margarita","description":"Klassischer Tequila-Cocktail"}}'),
  (34, 'Cerveza', '14', 3.80, 'Mexican beer', false, '{"_source":{"name":"Cerveza","desc":"Mexican beer"},"en":{"name":"Cerveza","description":"Mexican beer"},"de":{"name":"Mexikanisches Bier","description":"Mexikanisches Bier"}}')
ON CONFLICT DO NOTHING;

-- Items for Saigon Street Kitchen (Vietnamese)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Appetizers
  (35, 'Summer Rolls', '1', 5.50, 'Fresh rice paper rolls with shrimp and herbs (2 pieces)', false, '{"_source":{"name":"Summer Rolls","desc":"Fresh rice paper rolls with shrimp and herbs (2 pieces)"},"en":{"name":"Summer Rolls","description":"Fresh rice paper rolls with shrimp and herbs (2 pieces)"},"de":{"name":"Sommerrollen","description":"Frische Reispapierrollen mit Garnelen und Kräutern (2 Stück)"}}'),
  (35, 'Fried Spring Rolls', '2', 4.90, 'Crispy rolls with pork and vegetables (3 pieces)', false, '{"_source":{"name":"Fried Spring Rolls","desc":"Crispy rolls with pork and vegetables (3 pieces)"},"en":{"name":"Fried Spring Rolls","description":"Crispy rolls with pork and vegetables (3 pieces)"},"de":{"name":"Gebratene Frühlingsrollen","description":"Knusprige Rollen mit Schweinefleisch und Gemüse (3 Stück)"}}'),
  (35, 'Vietnamese Dumplings', '3', 5.20, 'Steamed dumplings with pork filling', false, '{"_source":{"name":"Vietnamese Dumplings","desc":"Steamed dumplings with pork filling"},"en":{"name":"Vietnamese Dumplings","description":"Steamed dumplings with pork filling"},"de":{"name":"Vietnamesische Teigtaschen","description":"Gedämpfte Teigtaschen mit Schweinefleischfüllung"}}'),
  -- Pho
  (36, 'Pho Bo', '4', 9.50, 'Beef noodle soup with rice noodles', false, '{"_source":{"name":"Pho Bo","desc":"Beef noodle soup with rice noodles"},"en":{"name":"Pho Bo","description":"Beef noodle soup with rice noodles"},"de":{"name":"Pho Bo","description":"Rindfleischnudelsuppe mit Reisnudeln"}}'),
  (36, 'Pho Ga', '5', 8.90, 'Chicken noodle soup with herbs', false, '{"_source":{"name":"Pho Ga","desc":"Chicken noodle soup with herbs"},"en":{"name":"Pho Ga","description":"Chicken noodle soup with herbs"},"de":{"name":"Pho Ga","description":"Hühnernudelsuppe mit Kräutern"}}'),
  (36, 'Pho Chay', '6', 8.50, 'Vegetarian pho with tofu', false, '{"_source":{"name":"Pho Chay","desc":"Vegetarian pho with tofu"},"en":{"name":"Pho Chay","description":"Vegetarian pho with tofu"},"de":{"name":"Pho Chay","description":"Vegetarische Pho mit Tofu"}}'),
  -- Banh Mi
  (37, 'Banh Mi Thit', '7', 6.50, 'Vietnamese sandwich with grilled pork', false, '{"_source":{"name":"Banh Mi Thit","desc":"Vietnamese sandwich with grilled pork"},"en":{"name":"Banh Mi Thit","description":"Vietnamese sandwich with grilled pork"},"de":{"name":"Bánh Mì Thịt","description":"Vietnamesisches Sandwich mit gegrilltem Schweinefleisch"}}'),
  (37, 'Banh Mi Ga', '8', 6.20, 'Sandwich with lemongrass chicken', false, '{"_source":{"name":"Banh Mi Ga","desc":"Sandwich with lemongrass chicken"},"en":{"name":"Banh Mi Ga","description":"Sandwich with lemongrass chicken"},"de":{"name":"Bánh Mì Gà","description":"Sandwich mit Zitronengras-Hähnchen"}}'),
  (37, 'Banh Mi Chay', '9', 5.90, 'Vegetarian sandwich with tofu', false, '{"_source":{"name":"Banh Mi Chay","desc":"Vegetarian sandwich with tofu"},"en":{"name":"Banh Mi Chay","description":"Vegetarian sandwich with tofu"},"de":{"name":"Bánh Mì Chay","description":"Vegetarisches Sandwich mit Tofu"}}'),
  -- Rice & Noodles
  (38, 'Bun Cha', '10', 10.90, 'Grilled pork with vermicelli and herbs', false, '{"_source":{"name":"Bun Cha","desc":"Grilled pork with vermicelli and herbs"},"en":{"name":"Bun Cha","description":"Grilled pork with vermicelli and herbs"},"de":{"name":"Bún Chả","description":"Gegrilltes Schweinefleisch mit Vermicelli und Kräutern"}}'),
  (38, 'Com Tam', '11', 9.50, 'Broken rice with grilled pork chop', false, '{"_source":{"name":"Com Tam","desc":"Broken rice with grilled pork chop"},"en":{"name":"Com Tam","description":"Broken rice with grilled pork chop"},"de":{"name":"Cơm Tấm","description":"Bruchreis mit gegrilltem Schweinskotelett"}}'),
  (38, 'Pad Thai', '12', 9.90, 'Stir-fried rice noodles', false, '{"_source":{"name":"Pad Thai","desc":"Stir-fried rice noodles"},"en":{"name":"Pad Thai","description":"Stir-fried rice noodles"},"de":{"name":"Pad Thai","description":"Gebratene Reisnudeln"}}'),
  -- Beverages
  (39, 'Vietnamese Coffee', '13', 3.50, 'Strong coffee with condensed milk', false, '{"_source":{"name":"Vietnamese Coffee","desc":"Strong coffee with condensed milk"},"en":{"name":"Vietnamese Coffee","description":"Strong coffee with condensed milk"},"de":{"name":"Vietnamesischer Kaffee","description":"Starker Kaffee mit Kondensmilch"}}'),
  (39, 'Fresh Coconut', '14', 3.80, 'Young coconut water', false, '{"_source":{"name":"Fresh Coconut","desc":"Young coconut water"},"en":{"name":"Fresh Coconut","description":"Young coconut water"},"de":{"name":"Frische Kokosnuss","description":"Junges Kokosnusswasser"}}')
ON CONFLICT DO NOTHING;

-- Items for The American Diner (American)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Appetizers
  (40, 'Buffalo Wings', '1', 7.90, 'Spicy chicken wings with blue cheese dip (8 pieces)', false, '{"_source":{"name":"Buffalo Wings","desc":"Spicy chicken wings with blue cheese dip (8 pieces)"},"en":{"name":"Buffalo Wings","description":"Spicy chicken wings with blue cheese dip (8 pieces)"},"de":{"name":"Buffalo Wings","description":"Scharfe Hähnchenflügel mit Blauschimmelkäse-Dip (8 Stück)"}}'),
  (40, 'Mozzarella Sticks', '2', 6.50, 'Breaded mozzarella with marinara sauce', false, '{"_source":{"name":"Mozzarella Sticks","desc":"Breaded mozzarella with marinara sauce"},"en":{"name":"Mozzarella Sticks","description":"Breaded mozzarella with marinara sauce"},"de":{"name":"Mozzarella-Sticks","description":"Panierter Mozzarella mit Marinara-Soße"}}'),
  (40, 'Onion Rings', '3', 5.50, 'Crispy beer-battered onion rings', false, '{"_source":{"name":"Onion Rings","desc":"Crispy beer-battered onion rings"},"en":{"name":"Onion Rings","description":"Crispy beer-battered onion rings"},"de":{"name":"Zwiebelringe","description":"Knusprige Zwiebelringe im Bierteig"}}'),
  -- Burgers
  (41, 'Classic Cheeseburger', '4', 10.90, 'Beef patty with cheese, lettuce, tomato', false, '{"_source":{"name":"Classic Cheeseburger","desc":"Beef patty with cheese, lettuce, tomato"},"en":{"name":"Classic Cheeseburger","description":"Beef patty with cheese, lettuce, tomato"},"de":{"name":"Klassischer Cheeseburger","description":"Rindfleischpatty mit Käse, Salat und Tomate"}}'),
  (41, 'Bacon BBQ Burger', '5', 12.50, 'Double patty with bacon and BBQ sauce', false, '{"_source":{"name":"Bacon BBQ Burger","desc":"Double patty with bacon and BBQ sauce"},"en":{"name":"Bacon BBQ Burger","description":"Double patty with bacon and BBQ sauce"},"de":{"name":"Bacon-BBQ-Burger","description":"Doppeltes Patty mit Speck und BBQ-Soße"}}'),
  (41, 'Veggie Burger', '6', 9.90, 'Plant-based patty with avocado', false, '{"_source":{"name":"Veggie Burger","desc":"Plant-based patty with avocado"},"en":{"name":"Veggie Burger","description":"Plant-based patty with avocado"},"de":{"name":"Veggie-Burger","description":"Pflanzliches Patty mit Avocado"}}'),
  -- Mains
  (42, 'NY Strip Steak', '7', 19.90, 'Grilled steak with mashed potatoes', false, '{"_source":{"name":"NY Strip Steak","desc":"Grilled steak with mashed potatoes"},"en":{"name":"NY Strip Steak","description":"Grilled steak with mashed potatoes"},"de":{"name":"NY-Strip-Steak","description":"Gegrilltes Steak mit Kartoffelpüree"}}'),
  (42, 'BBQ Ribs', '8', 16.50, 'Half rack of baby back ribs', false, '{"_source":{"name":"BBQ Ribs","desc":"Half rack of baby back ribs"},"en":{"name":"BBQ Ribs","description":"Half rack of baby back ribs"},"de":{"name":"BBQ-Spareribs","description":"Halbes Rippchen-Rack"}}'),
  (42, 'Mac & Cheese', '9', 8.90, 'Creamy macaroni and cheese', false, '{"_source":{"name":"Mac & Cheese","desc":"Creamy macaroni and cheese"},"en":{"name":"Mac & Cheese","description":"Creamy macaroni and cheese"},"de":{"name":"Mac & Cheese","description":"Cremige Makkaroni mit Käse"}}'),
  (42, 'Fish & Chips', '10', 11.50, 'Battered cod with fries', false, '{"_source":{"name":"Fish & Chips","desc":"Battered cod with fries"},"en":{"name":"Fish & Chips","description":"Battered cod with fries"},"de":{"name":"Fish & Chips","description":"Frittierter Kabeljau mit Pommes"}}'),
  -- Desserts
  (43, 'Brownie Sundae', '11', 6.90, 'Warm brownie with ice cream', false, '{"_source":{"name":"Brownie Sundae","desc":"Warm brownie with ice cream"},"en":{"name":"Brownie Sundae","description":"Warm brownie with ice cream"},"de":{"name":"Brownie-Sundae","description":"Warmer Brownie mit Eiscreme"}}'),
  (43, 'Apple Pie', '12', 5.50, 'Classic American apple pie', false, '{"_source":{"name":"Apple Pie","desc":"Classic American apple pie"},"en":{"name":"Apple Pie","description":"Classic American apple pie"},"de":{"name":"Apfelkuchen","description":"Klassischer amerikanischer Apfelkuchen"}}'),
  (43, 'Cheesecake', '13', 6.50, 'New York style cheesecake', false, '{"_source":{"name":"Cheesecake","desc":"New York style cheesecake"},"en":{"name":"Cheesecake","description":"New York style cheesecake"},"de":{"name":"Käsekuchen","description":"New-York-Style-Käsekuchen"}}'),
  -- Shakes & Drinks
  (44, 'Chocolate Shake', '14', 5.50, 'Thick chocolate milkshake', false, '{"_source":{"name":"Chocolate Shake","desc":"Thick chocolate milkshake"},"en":{"name":"Chocolate Shake","description":"Thick chocolate milkshake"},"de":{"name":"Schokoladen-Shake","description":"Dicker Schokoladenmilchshake"}}'),
  (44, 'Strawberry Shake', '15', 5.50, 'Fresh strawberry milkshake', false, '{"_source":{"name":"Strawberry Shake","desc":"Fresh strawberry milkshake"},"en":{"name":"Strawberry Shake","description":"Fresh strawberry milkshake"},"de":{"name":"Erdbeer-Shake","description":"Frischer Erdbeermilchshake"}}'),
  (44, 'Coca-Cola', '16', 2.50, 'Classic soft drink', false, '{"_source":{"name":"Coca-Cola","desc":"Classic soft drink"},"en":{"name":"Coca-Cola","description":"Classic soft drink"},"de":{"name":"Coca-Cola","description":"Klassisches Erfrischungsgetränk"}}')
ON CONFLICT DO NOTHING;

-- Items for Istanbul Grill (Turkish)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Mezze
  (45, 'Hummus', '1', 4.50, 'Chickpea dip with olive oil', false, '{"_source":{"name":"Hummus","desc":"Chickpea dip with olive oil"},"en":{"name":"Hummus","description":"Chickpea dip with olive oil"},"de":{"name":"Hummus","description":"Kichererbsen-Dip mit Olivenöl"}}'),
  (45, 'Baba Ghanoush', '2', 4.90, 'Smoked eggplant dip', false, '{"_source":{"name":"Baba Ghanoush","desc":"Smoked eggplant dip"},"en":{"name":"Baba Ghanoush","description":"Smoked eggplant dip"},"de":{"name":"Baba Ghanoush","description":"Geräucherter Auberginen-Dip"}}'),
  (45, 'Mixed Mezze Platter', '3', 9.90, 'Selection of Turkish dips and salads', false, '{"_source":{"name":"Mixed Mezze Platter","desc":"Selection of Turkish dips and salads"},"en":{"name":"Mixed Mezze Platter","description":"Selection of Turkish dips and salads"},"de":{"name":"Gemischte Mezze-Platte","description":"Auswahl türkischer Dips und Salate"}}'),
  -- Kebabs
  (46, 'Adana Kebab', '4', 11.90, 'Spicy minced meat kebab', false, '{"_source":{"name":"Adana Kebab","desc":"Spicy minced meat kebab"},"en":{"name":"Adana Kebab","description":"Spicy minced meat kebab"},"de":{"name":"Adana-Kebab","description":"Scharfer Hackfleisch-Kebab"}}'),
  (46, 'Shish Kebab', '5', 12.50, 'Marinated lamb cubes on skewer', false, '{"_source":{"name":"Shish Kebab","desc":"Marinated lamb cubes on skewer"},"en":{"name":"Shish Kebab","description":"Marinated lamb cubes on skewer"},"de":{"name":"Shish-Kebab","description":"Marinierte Lammfleischwürfel am Spieß"}}'),
  (46, 'Chicken Shish', '6', 10.90, 'Grilled chicken breast pieces', false, '{"_source":{"name":"Chicken Shish","desc":"Grilled chicken breast pieces"},"en":{"name":"Chicken Shish","description":"Grilled chicken breast pieces"},"de":{"name":"Hähnchen-Shish","description":"Gegrillte Hähnchenbrust-Stücke"}}'),
  (46, 'Mixed Grill', '7', 15.90, 'Combination of all kebabs', false, '{"_source":{"name":"Mixed Grill","desc":"Combination of all kebabs"},"en":{"name":"Mixed Grill","description":"Combination of all kebabs"},"de":{"name":"Gemischter Grill","description":"Kombination aller Kebab-Sorten"}}'),
  -- Pide & Lahmacun
  (47, 'Cheese Pide', '8', 8.50, 'Turkish flatbread with cheese', false, '{"_source":{"name":"Cheese Pide","desc":"Turkish flatbread with cheese"},"en":{"name":"Cheese Pide","description":"Turkish flatbread with cheese"},"de":{"name":"Käse-Pide","description":"Türkisches Fladenbrot mit Käse"}}'),
  (47, 'Meat Pide', '9', 9.90, 'Boat-shaped pizza with minced meat', false, '{"_source":{"name":"Meat Pide","desc":"Boat-shaped pizza with minced meat"},"en":{"name":"Meat Pide","description":"Boat-shaped pizza with minced meat"},"de":{"name":"Fleisch-Pide","description":"Bootsförmige Pizza mit Hackfleisch"}}'),
  (47, 'Lahmacun', '10', 6.50, 'Thin flatbread with spiced meat', false, '{"_source":{"name":"Lahmacun","desc":"Thin flatbread with spiced meat"},"en":{"name":"Lahmacun","description":"Thin flatbread with spiced meat"},"de":{"name":"Lahmacun","description":"Dünnes Fladenbrot mit gewürztem Fleisch"}}'),
  -- Mains
  (48, 'Iskender Kebab', '11', 13.50, 'Sliced döner with tomato sauce and yogurt', false, '{"_source":{"name":"Iskender Kebab","desc":"Sliced döner with tomato sauce and yogurt"},"en":{"name":"Iskender Kebab","description":"Sliced döner with tomato sauce and yogurt"},"de":{"name":"Iskender-Kebab","description":"Geschnittener Döner mit Tomatensoße und Joghurt"}}'),
  (48, 'Manti', '12', 10.90, 'Turkish dumplings with yogurt sauce', false, '{"_source":{"name":"Manti","desc":"Turkish dumplings with yogurt sauce"},"en":{"name":"Manti","description":"Turkish dumplings with yogurt sauce"},"de":{"name":"Manti","description":"Türkische Teigtaschen mit Joghurtsoße"}}'),
  -- Beverages
  (49, 'Turkish Tea', '13', 2.00, 'Traditional black tea', false, '{"_source":{"name":"Turkish Tea","desc":"Traditional black tea"},"en":{"name":"Turkish Tea","description":"Traditional black tea"},"de":{"name":"Türkischer Tee","description":"Traditioneller Schwarztee"}}'),
  (49, 'Ayran', '14', 2.50, 'Salted yogurt drink', false, '{"_source":{"name":"Ayran","desc":"Salted yogurt drink"},"en":{"name":"Ayran","description":"Salted yogurt drink"},"de":{"name":"Ayran","description":"Gesalzenes Joghurtgetränk"}}')
ON CONFLICT DO NOTHING;

-- Items for Thai Orchid (Thai)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Appetizers
  (50, 'Thai Spring Rolls', '1', 5.50, 'Vegetable spring rolls with sweet chili sauce', false, '{"_source":{"name":"Thai Spring Rolls","desc":"Vegetable spring rolls with sweet chili sauce"},"en":{"name":"Thai Spring Rolls","description":"Vegetable spring rolls with sweet chili sauce"},"de":{"name":"Thai-Frühlingsrollen","description":"Gemüsefrühlingsrollen mit süß-scharfer Soße"}}'),
  (50, 'Satay Chicken', '2', 6.90, 'Grilled chicken skewers with peanut sauce', false, '{"_source":{"name":"Satay Chicken","desc":"Grilled chicken skewers with peanut sauce"},"en":{"name":"Satay Chicken","description":"Grilled chicken skewers with peanut sauce"},"de":{"name":"Hähnchen-Satay","description":"Gegrillte Hähnchenspieße mit Erdnusssoße"}}'),
  (50, 'Tom Yum Goong', '3', 7.50, 'Spicy and sour shrimp soup', false, '{"_source":{"name":"Tom Yum Goong","desc":"Spicy and sour shrimp soup"},"en":{"name":"Tom Yum Goong","description":"Spicy and sour shrimp soup"},"de":{"name":"Tom Yum Goong","description":"Scharfe und saure Garnelen-Suppe"}}'),
  -- Soups
  (51, 'Tom Kha Gai', '4', 6.90, 'Coconut milk soup with chicken', false, '{"_source":{"name":"Tom Kha Gai","desc":"Coconut milk soup with chicken"},"en":{"name":"Tom Kha Gai","description":"Coconut milk soup with chicken"},"de":{"name":"Tom Kha Gai","description":"Kokosmilchsuppe mit Hähnchen"}}'),
  (51, 'Tom Yum', '5', 6.50, 'Hot and sour soup with mushrooms', false, '{"_source":{"name":"Tom Yum","desc":"Hot and sour soup with mushrooms"},"en":{"name":"Tom Yum","description":"Hot and sour soup with mushrooms"},"de":{"name":"Tom Yum","description":"Heiß-saure Suppe mit Pilzen"}}'),
  -- Curries
  (52, 'Green Curry', '6', 11.50, 'Spicy green curry with chicken or beef', false, '{"_source":{"name":"Green Curry","desc":"Spicy green curry with chicken or beef"},"en":{"name":"Green Curry","description":"Spicy green curry with chicken or beef"},"de":{"name":"Grünes Curry","description":"Scharfes grünes Curry mit Hähnchen oder Rindfleisch"}}'),
  (52, 'Red Curry', '7', 11.50, 'Thai red curry with vegetables', false, '{"_source":{"name":"Red Curry","desc":"Thai red curry with vegetables"},"en":{"name":"Red Curry","description":"Thai red curry with vegetables"},"de":{"name":"Rotes Curry","description":"Rotes Thai-Curry mit Gemüse"}}'),
  (52, 'Massaman Curry', '8', 12.50, 'Mild curry with potatoes and peanuts', false, '{"_source":{"name":"Massaman Curry","desc":"Mild curry with potatoes and peanuts"},"en":{"name":"Massaman Curry","description":"Mild curry with potatoes and peanuts"},"de":{"name":"Massaman-Curry","description":"Mildes Curry mit Kartoffeln und Erdnüssen"}}'),
  (52, 'Panang Curry', '9', 11.90, 'Rich and creamy peanut curry', false, '{"_source":{"name":"Panang Curry","desc":"Rich and creamy peanut curry"},"en":{"name":"Panang Curry","description":"Rich and creamy peanut curry"},"de":{"name":"Panang-Curry","description":"Reichhaltiges cremiges Erdnuss-Curry"}}'),
  -- Stir-Fry
  (53, 'Pad Krapow', '10', 10.90, 'Stir-fried basil with minced meat', false, '{"_source":{"name":"Pad Krapow","desc":"Stir-fried basil with minced meat"},"en":{"name":"Pad Krapow","description":"Stir-fried basil with minced meat"},"de":{"name":"Pad Krapow","description":"Gebratenes Basilikum mit Hackfleisch"}}'),
  (53, 'Cashew Chicken', '11', 11.50, 'Chicken with cashews and vegetables', false, '{"_source":{"name":"Cashew Chicken","desc":"Chicken with cashews and vegetables"},"en":{"name":"Cashew Chicken","description":"Chicken with cashews and vegetables"},"de":{"name":"Cashew-Hähnchen","description":"Hähnchen mit Cashews und Gemüse"}}'),
  -- Noodles & Rice
  (54, 'Pad Thai', '12', 9.90, 'Stir-fried rice noodles with shrimp', false, '{"_source":{"name":"Pad Thai","desc":"Stir-fried rice noodles with shrimp"},"en":{"name":"Pad Thai","description":"Stir-fried rice noodles with shrimp"},"de":{"name":"Pad Thai","description":"Gebratene Reisnudeln mit Garnelen"}}'),
  (54, 'Pad See Ew', '13', 9.50, 'Flat noodles with soy sauce', false, '{"_source":{"name":"Pad See Ew","desc":"Flat noodles with soy sauce"},"en":{"name":"Pad See Ew","description":"Flat noodles with soy sauce"},"de":{"name":"Pad See Ew","description":"Flache Nudeln mit Sojasoße"}}'),
  (54, 'Thai Fried Rice', '14', 8.90, 'Jasmine rice with egg and vegetables', false, '{"_source":{"name":"Thai Fried Rice","desc":"Jasmine rice with egg and vegetables"},"en":{"name":"Thai Fried Rice","description":"Jasmine rice with egg and vegetables"},"de":{"name":"Gebratener Thai-Reis","description":"Jasminreis mit Ei und Gemüse"}}'),
  -- Beverages
  (55, 'Thai Iced Tea', '15', 3.50, 'Sweet milk tea with ice', false, '{"_source":{"name":"Thai Iced Tea","desc":"Sweet milk tea with ice"},"en":{"name":"Thai Iced Tea","description":"Sweet milk tea with ice"},"de":{"name":"Thailändischer Eistee","description":"Süßer Milchtee mit Eis"}}'),
  (55, 'Singha Beer', '16', 3.80, 'Thai lager beer', false, '{"_source":{"name":"Singha Beer","desc":"Thai lager beer"},"en":{"name":"Singha Beer","description":"Thai lager beer"},"de":{"name":"Singha-Bier","description":"Thailändisches Lagerbier"}}')
ON CONFLICT DO NOTHING;

-- Items for Seoul BBQ (Korean)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Appetizers
  (56, 'Kimchi', '1', 4.50, 'Fermented spicy cabbage', false, '{"_source":{"name":"Kimchi","desc":"Fermented spicy cabbage"},"en":{"name":"Kimchi","description":"Fermented spicy cabbage"},"de":{"name":"Kimchi","description":"Fermentierter scharfer Kohl"}}'),
  (56, 'Mandu', '2', 6.50, 'Korean dumplings (steamed or fried)', false, '{"_source":{"name":"Mandu","desc":"Korean dumplings (steamed or fried)"},"en":{"name":"Mandu","description":"Korean dumplings (steamed or fried)"},"de":{"name":"Mandu","description":"Koreanische Teigtaschen (gedämpft oder frittiert)"}}'),
  (56, 'Japchae', '3', 7.90, 'Stir-fried glass noodles with vegetables', false, '{"_source":{"name":"Japchae","desc":"Stir-fried glass noodles with vegetables"},"en":{"name":"Japchae","description":"Stir-fried glass noodles with vegetables"},"de":{"name":"Japchae","description":"Gebratene Glasnudeln mit Gemüse"}}'),
  -- BBQ Meats
  (57, 'Bulgogi', '4', 14.90, 'Marinated beef for table grill', false, '{"_source":{"name":"Bulgogi","desc":"Marinated beef for table grill"},"en":{"name":"Bulgogi","description":"Marinated beef for table grill"},"de":{"name":"Bulgogi","description":"Mariniertes Rindfleisch für Tischgrill"}}'),
  (57, 'Galbi', '5', 16.90, 'Marinated beef short ribs', false, '{"_source":{"name":"Galbi","desc":"Marinated beef short ribs"},"en":{"name":"Galbi","description":"Marinated beef short ribs"},"de":{"name":"Galbi","description":"Marinierte Rinder-Shortribs"}}'),
  (57, 'Samgyeopsal', '6', 13.50, 'Pork belly slices for grilling', false, '{"_source":{"name":"Samgyeopsal","desc":"Pork belly slices for grilling"},"en":{"name":"Samgyeopsal","description":"Pork belly slices for grilling"},"de":{"name":"Samgyeopsal","description":"Schweinebauchscheiben zum Grillen"}}'),
  (57, 'BBQ Combo', '7', 24.90, 'Mixed meats platter for 2 persons', false, '{"_source":{"name":"BBQ Combo","desc":"Mixed meats platter for 2 persons"},"en":{"name":"BBQ Combo","description":"Mixed meats platter for 2 persons"},"de":{"name":"BBQ-Kombi","description":"Gemischte Fleischplatte für 2 Personen"}}'),
  -- Hot Pots
  (58, 'Kimchi Jjigae', '8', 10.90, 'Spicy kimchi stew with pork', false, '{"_source":{"name":"Kimchi Jjigae","desc":"Spicy kimchi stew with pork"},"en":{"name":"Kimchi Jjigae","description":"Spicy kimchi stew with pork"},"de":{"name":"Kimchi-Jjigae","description":"Scharfer Kimchi-Eintopf mit Schweinefleisch"}}'),
  (58, 'Sundubu Jjigae', '9', 11.50, 'Soft tofu stew with seafood', false, '{"_source":{"name":"Sundubu Jjigae","desc":"Soft tofu stew with seafood"},"en":{"name":"Sundubu Jjigae","description":"Soft tofu stew with seafood"},"de":{"name":"Sundubu-Jjigae","description":"Weicher Tofu-Eintopf mit Meeresfrüchten"}}'),
  -- Main Dishes
  (59, 'Bibimbap', '10', 10.50, 'Mixed rice with vegetables and egg', false, '{"_source":{"name":"Bibimbap","desc":"Mixed rice with vegetables and egg"},"en":{"name":"Bibimbap","description":"Mixed rice with vegetables and egg"},"de":{"name":"Bibimbap","description":"Gemischter Reis mit Gemüse und Ei"}}'),
  (59, 'Dolsot Bibimbap', '11', 11.90, 'Bibimbap in hot stone pot', false, '{"_source":{"name":"Dolsot Bibimbap","desc":"Bibimbap in hot stone pot"},"en":{"name":"Dolsot Bibimbap","description":"Bibimbap in hot stone pot"},"de":{"name":"Dolsot-Bibimbap","description":"Bibimbap im heißen Steintopf"}}'),
  (59, 'Korean Fried Chicken', '12', 12.50, 'Crispy fried chicken with sweet-spicy sauce', false, '{"_source":{"name":"Korean Fried Chicken","desc":"Crispy fried chicken with sweet-spicy sauce"},"en":{"name":"Korean Fried Chicken","description":"Crispy fried chicken with sweet-spicy sauce"},"de":{"name":"Koreanisches Fried Chicken","description":"Knuspriges frittiertes Hähnchen mit süß-scharfer Soße"}}'),
  -- Beverages
  (60, 'Soju', '13', 5.50, 'Korean distilled spirit', false, '{"_source":{"name":"Soju","desc":"Korean distilled spirit"},"en":{"name":"Soju","description":"Korean distilled spirit"},"de":{"name":"Soju","description":"Koreanischer Schnaps"}}'),
  (60, 'Makgeolli', '14', 6.50, 'Traditional rice wine', false, '{"_source":{"name":"Makgeolli","desc":"Traditional rice wine"},"en":{"name":"Makgeolli","description":"Traditional rice wine"},"de":{"name":"Makgeolli","description":"Traditioneller Reiswein"}}')
ON CONFLICT DO NOTHING;

-- Items for Tapas y Vino (Spanish)
INSERT INTO items (category_id, name, item_number, price, description, has_variants, translations) VALUES
  -- Tapas Frías
  (61, 'Jamón Ibérico', '1', 9.90, 'Iberian ham with bread', false, '{"_source":{"name":"Jamón Ibérico","desc":"Iberian ham with bread"},"en":{"name":"Jamón Ibérico","description":"Iberian ham with bread"},"de":{"name":"Jamón Ibérico","description":"Iberischer Schinken mit Brot"}}'),
  (61, 'Manchego', '2', 7.50, 'Spanish sheep cheese with quince', false, '{"_source":{"name":"Manchego","desc":"Spanish sheep cheese with quince"},"en":{"name":"Manchego","description":"Spanish sheep cheese with quince"},"de":{"name":"Manchego","description":"Spanischer Schafskäse mit Quitte"}}'),
  (61, 'Aceitunas', '3', 4.50, 'Marinated olives with herbs', false, '{"_source":{"name":"Aceitunas","desc":"Marinated olives with herbs"},"en":{"name":"Aceitunas","description":"Marinated olives with herbs"},"de":{"name":"Oliven","description":"Marinierte Oliven mit Kräutern"}}'),
  (61, 'Pan con Tomate', '4', 5.50, 'Toasted bread with tomato and olive oil', false, '{"_source":{"name":"Pan con Tomate","desc":"Toasted bread with tomato and olive oil"},"en":{"name":"Pan con Tomate","description":"Toasted bread with tomato and olive oil"},"de":{"name":"Pan con Tomate","description":"Geröstetes Brot mit Tomate und Olivenöl"}}'),
  -- Tapas Calientes
  (62, 'Patatas Bravas', '5', 6.50, 'Fried potatoes with spicy sauce', false, '{"_source":{"name":"Patatas Bravas","desc":"Fried potatoes with spicy sauce"},"en":{"name":"Patatas Bravas","description":"Fried potatoes with spicy sauce"},"de":{"name":"Patatas Bravas","description":"Gebratene Kartoffeln mit scharfer Soße"}}'),
  (62, 'Gambas al Ajillo', '6', 9.90, 'Garlic shrimp in olive oil', false, '{"_source":{"name":"Gambas al Ajillo","desc":"Garlic shrimp in olive oil"},"en":{"name":"Gambas al Ajillo","description":"Garlic shrimp in olive oil"},"de":{"name":"Gambas al Ajillo","description":"Knoblauchgarnelen in Olivenöl"}}'),
  (62, 'Croquetas', '7', 7.50, 'Creamy ham croquettes (4 pieces)', false, '{"_source":{"name":"Croquetas","desc":"Creamy ham croquettes (4 pieces)"},"en":{"name":"Croquetas","description":"Creamy ham croquettes (4 pieces)"},"de":{"name":"Croquetas","description":"Cremige Schinkenkroketten (4 Stück)"}}'),
  (62, 'Chorizo al Vino', '8', 8.50, 'Spanish sausage in red wine', false, '{"_source":{"name":"Chorizo al Vino","desc":"Spanish sausage in red wine"},"en":{"name":"Chorizo al Vino","description":"Spanish sausage in red wine"},"de":{"name":"Chorizo al Vino","description":"Spanische Wurst in Rotwein"}}'),
  (62, 'Pimientos de Padrón', '9', 6.90, 'Fried green peppers with sea salt', false, '{"_source":{"name":"Pimientos de Padrón","desc":"Fried green peppers with sea salt"},"en":{"name":"Pimientos de Padrón","description":"Fried green peppers with sea salt"},"de":{"name":"Pimientos de Padrón","description":"Gebratene grüne Paprika mit Meersalz"}}'),
  -- Raciones
  (63, 'Paella Valenciana', '10', 16.90, 'Traditional rice with chicken and seafood', false, '{"_source":{"name":"Paella Valenciana","desc":"Traditional rice with chicken and seafood"},"en":{"name":"Paella Valenciana","description":"Traditional rice with chicken and seafood"},"de":{"name":"Paella Valenciana","description":"Traditioneller Reis mit Hähnchen und Meeresfrüchten"}}'),
  (63, 'Pulpo a la Gallega', '11', 14.50, 'Galician-style octopus with paprika', false, '{"_source":{"name":"Pulpo a la Gallega","desc":"Galician-style octopus with paprika"},"en":{"name":"Pulpo a la Gallega","description":"Galician-style octopus with paprika"},"de":{"name":"Pulpo a la Gallega","description":"Oktopus auf galicische Art mit Paprika"}}'),
  (63, 'Tortilla Española', '12', 8.90, 'Spanish potato omelette', false, '{"_source":{"name":"Tortilla Española","desc":"Spanish potato omelette"},"en":{"name":"Tortilla Española","description":"Spanish potato omelette"},"de":{"name":"Tortilla Española","description":"Spanisches Kartoffelomelette"}}'),
  -- Postres
  (64, 'Crema Catalana', '13', 5.90, 'Catalan custard with caramelized sugar', false, '{"_source":{"name":"Crema Catalana","desc":"Catalan custard with caramelized sugar"},"en":{"name":"Crema Catalana","description":"Catalan custard with caramelized sugar"},"de":{"name":"Crema Catalana","description":"Katalanischer Pudding mit karamellisiertem Zucker"}}'),
  (64, 'Churros con Chocolate', '14', 6.50, 'Fried dough with hot chocolate', false, '{"_source":{"name":"Churros con Chocolate","desc":"Fried dough with hot chocolate"},"en":{"name":"Churros con Chocolate","description":"Fried dough with hot chocolate"},"de":{"name":"Churros con Chocolate","description":"Frittierter Teig mit heißer Schokolade"}}'),
  -- Bebidas
  (65, 'Sangria', '15', 5.50, 'Spanish red wine punch', false, '{"_source":{"name":"Sangria","desc":"Spanish red wine punch"},"en":{"name":"Sangria","description":"Spanish red wine punch"},"de":{"name":"Sangria","description":"Spanischer Rotweinpunsch"}}'),
  (65, 'Rioja (glass)', '16', 6.50, 'Spanish red wine', false, '{"_source":{"name":"Rioja (glass)","desc":"Spanish red wine"},"en":{"name":"Rioja (glass)","description":"Spanish red wine"},"de":{"name":"Rioja (Glas)","description":"Spanischer Rotwein"}}')
ON CONFLICT DO NOTHING;

-- Reset sequences to the current max id
SELECT setval(pg_get_serial_sequence('restaurants','id'), COALESCE((SELECT MAX(id) FROM restaurants), 1));
SELECT setval(pg_get_serial_sequence('categories','id'), COALESCE((SELECT MAX(id) FROM categories), 1));
SELECT setval(pg_get_serial_sequence('items','id'), COALESCE((SELECT MAX(id) FROM items), 1));
SELECT setval(pg_get_serial_sequence('item_variants','id'), COALESCE((SELECT MAX(id) FROM item_variants), 1));

-- Enable Row Level Security on restaurants table
ALTER TABLE restaurants ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Allow public read access to restaurants" ON restaurants;
DROP POLICY IF EXISTS "Allow authenticated users to insert restaurants" ON restaurants;
DROP POLICY IF EXISTS "Allow owners to update their restaurants" ON restaurants;
DROP POLICY IF EXISTS "Allow owners to delete their restaurants" ON restaurants;

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

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Allow public read access to categories" ON categories;
DROP POLICY IF EXISTS "Allow public read access to items" ON items;
DROP POLICY IF EXISTS "Allow public read access to item_variants" ON item_variants;
DROP POLICY IF EXISTS "Allow owners to manage categories" ON categories;
DROP POLICY IF EXISTS "Allow owners to manage items" ON items;
DROP POLICY IF EXISTS "Allow owners to manage item_variants" ON item_variants;

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

-- ============================================================
-- USER PROFILES & ROLES
-- Run this block (or paste into the Supabase SQL editor) to
-- enable the three-tier role system:
--   anonymous  – no account, browse only (default)
--   customer   – free account, save favourites etc.
--   restaurant_owner – paid €4.99/mo, can create/edit restaurants
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id                              uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  role                            text NOT NULL DEFAULT 'customer'
                                    CHECK (role IN ('customer', 'restaurant_owner')),
  subscription_status             text
                                    CHECK (subscription_status IN ('active', 'trialing', 'canceled', 'past_due')),
  subscription_id                 text,          -- Stripe subscription ID
  subscription_current_period_end timestamptz,   -- when the current billing period ends
  stripe_customer_id              text,          -- Stripe customer ID
  created_at                      timestamptz DEFAULT now(),
  updated_at                      timestamptz DEFAULT now()
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles: own row select" ON profiles;
DROP POLICY IF EXISTS "profiles: own row insert" ON profiles;
DROP POLICY IF EXISTS "profiles: own row update" ON profiles;

CREATE POLICY "profiles: own row select"
  ON profiles FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles: own row insert"
  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles: own row update"
  ON profiles FOR UPDATE USING (auth.uid() = id);

-- Automatically create a 'customer' profile whenever a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, role)
  VALUES (new.id, 'customer')
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================
-- STORAGE: menu-designs bucket
-- Stores AI-generated HTML menu layouts uploaded by restaurant owners
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('menu-designs', 'menu-designs', true)
ON CONFLICT (id) DO NOTHING;

-- Drop existing storage policies if re-running
DROP POLICY IF EXISTS "Public read menu-designs" ON storage.objects;
DROP POLICY IF EXISTS "Owners can upload menu-designs" ON storage.objects;
DROP POLICY IF EXISTS "Owners can update menu-designs" ON storage.objects;

CREATE POLICY "Public read menu-designs"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'menu-designs');

CREATE POLICY "Owners can upload menu-designs"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'menu-designs' AND auth.role() = 'authenticated');

CREATE POLICY "Owners can update menu-designs"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'menu-designs' AND auth.role() = 'authenticated');

-- ============================================================
-- DEALS / PROMOTIONS
-- ============================================================

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
  day_of_week int[],
  valid_from date,
  valid_until date,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS deal_categories (
  deal_id bigint NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  category_id bigint NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (deal_id, category_id)
);

CREATE TABLE IF NOT EXISTS deal_items (
  deal_id bigint NOT NULL REFERENCES deals(id) ON DELETE CASCADE,
  item_id bigint NOT NULL REFERENCES items(id) ON DELETE CASCADE,
  PRIMARY KEY (deal_id, item_id)
);

DROP TRIGGER IF EXISTS trg_deals_updated_at ON deals;
CREATE TRIGGER trg_deals_updated_at
  BEFORE UPDATE ON deals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE deals           ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_items      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read deals"            ON deals;
DROP POLICY IF EXISTS "Public read deal_categories"  ON deal_categories;
DROP POLICY IF EXISTS "Public read deal_items"       ON deal_items;
DROP POLICY IF EXISTS "Owner manage deals"           ON deals;
DROP POLICY IF EXISTS "Owner manage deal_categories" ON deal_categories;
DROP POLICY IF EXISTS "Owner manage deal_items"      ON deal_items;

CREATE POLICY "Public read deals"           ON deals FOR SELECT USING (true);
CREATE POLICY "Public read deal_categories" ON deal_categories FOR SELECT USING (true);
CREATE POLICY "Public read deal_items"      ON deal_items FOR SELECT USING (true);

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

COMMIT;

