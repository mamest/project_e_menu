-- Migration: add user favorites for restaurants

CREATE TABLE IF NOT EXISTS user_favorites (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id bigint NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, restaurant_id)
);

-- RLS
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own favorites" ON user_favorites;
DROP POLICY IF EXISTS "Users can manage their own favorites" ON user_favorites;

CREATE POLICY "Users can read their own favorites"
  ON user_favorites FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage their own favorites"
  ON user_favorites FOR ALL
  USING (auth.uid() = user_id);
