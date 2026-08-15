CREATE OR REPLACE FUNCTION public.save_profile(
  p_username text,
  p_display_name text,
  p_avatar_url text,
  p_bio text,
  p_website_url text,
  p_location text,
  p_settings jsonb DEFAULT '{}'::jsonb,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_role text DEFAULT 'user'
) RETURNS SETOF public.profiles AS $$
BEGIN
  RETURN QUERY
  INSERT INTO public.profiles (id, username, display_name, avatar_url, bio, website_url, location, settings, metadata, role)
  VALUES (auth.uid()::uuid, p_username, p_display_name, p_avatar_url, p_bio, p_website_url, p_location, p_settings, p_metadata, p_role)
  ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    display_name = EXCLUDED.display_name,
    avatar_url = EXCLUDED.avatar_url,
    bio = EXCLUDED.bio,
    website_url = EXCLUDED.website_url,
    location = EXCLUDED.location,
    settings = EXCLUDED.settings,
    metadata = EXCLUDED.metadata,
    role = EXCLUDED.role,
    updated_at = now()
  RETURNING *;
END;
$$ LANGUAGE plpgsql;
