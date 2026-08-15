BEGIN;

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username text,
  display_name text,
  avatar_url text,
  bio text,
  website_url text,
  location text,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  last_active_at timestamptz,
  verified boolean DEFAULT false NOT NULL,
  is_private boolean DEFAULT false NOT NULL,
  settings jsonb DEFAULT '{}'::jsonb NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  role text DEFAULT 'user' NOT NULL,
  followers_count integer DEFAULT 0 NOT NULL,
  following_count integer DEFAULT 0 NOT NULL,
  search_text text
);

CREATE UNIQUE INDEX IF NOT EXISTS profiles_username_lower_idx ON public.profiles ((lower(username)));
CREATE INDEX IF NOT EXISTS profiles_created_at_idx ON public.profiles (created_at DESC);

CREATE OR REPLACE FUNCTION public.profiles_update_timestamp_and_search_text() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  NEW.search_text := coalesce(NEW.username, '') || ' ' || coalesce(NEW.display_name, '') || ' ' || coalesce(NEW.bio, '');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_update_text ON public.profiles;
CREATE TRIGGER trg_profiles_update_text
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.profiles_update_timestamp_and_search_text();

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS public_read_profiles ON public.profiles;
CREATE POLICY public_read_profiles ON public.profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS insert_own_profile ON public.profiles;
CREATE POLICY insert_own_profile ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS update_own_profile ON public.profiles;
CREATE POLICY update_own_profile ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS delete_own_profile ON public.profiles;
CREATE POLICY delete_own_profile ON public.profiles FOR DELETE USING (auth.uid() = id);

COMMIT;
