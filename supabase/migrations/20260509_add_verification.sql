-- Add verification fields to restaurants table
ALTER TABLE restaurants
  ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS verification_method text,         -- 'phone_pin' | 'google' | 'manual'
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

-- Verification PIN requests table
-- When an owner requests verification by phone, a PIN is generated and stored here.
-- A Supabase Edge Function sends the PIN via SMS (or stores it for manual lookup by admin).
CREATE TABLE IF NOT EXISTS verification_requests (
  id              bigserial PRIMARY KEY,
  restaurant_id   integer NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
  owner_uuid      uuid    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  phone           text    NOT NULL,
  pin             text    NOT NULL,           -- 6-digit PIN (hashed in production)
  method          text    NOT NULL DEFAULT 'phone_pin',
  created_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL DEFAULT (now() + interval '15 minutes'),
  used            boolean NOT NULL DEFAULT false
);

-- Only the restaurant owner can read/insert their own requests
ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "owner_select" ON verification_requests
  FOR SELECT USING (owner_uuid = auth.uid());

CREATE POLICY "owner_insert" ON verification_requests
  FOR INSERT WITH CHECK (owner_uuid = auth.uid());

CREATE POLICY "owner_update" ON verification_requests
  FOR UPDATE USING (owner_uuid = auth.uid());
