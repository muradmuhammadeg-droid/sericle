BEGIN;

CREATE TABLE IF NOT EXISTS public.bookmarks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  post_id uuid NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS bookmarks_user_post_unique ON public.bookmarks (user_id, post_id);
CREATE INDEX IF NOT EXISTS bookmarks_user_idx ON public.bookmarks (user_id, created_at DESC);

ALTER TABLE public.bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS bookmarks_select ON public.bookmarks;
CREATE POLICY bookmarks_select ON public.bookmarks FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS bookmarks_insert ON public.bookmarks;
CREATE POLICY bookmarks_insert ON public.bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS bookmarks_delete ON public.bookmarks;
CREATE POLICY bookmarks_delete ON public.bookmarks FOR DELETE USING (auth.uid() = user_id);

COMMIT;

CREATE OR REPLACE FUNCTION public.toggle_bookmark(
  p_post_id uuid,
  p_user_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE v_exists boolean;
DECLARE v_user uuid;
BEGIN
  IF p_user_id IS NULL THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'unauthenticated';
    END IF;
    v_user := auth.uid()::uuid;
  ELSE
    v_user := p_user_id;
  END IF;
  SELECT EXISTS (SELECT 1 FROM public.bookmarks WHERE user_id = v_user AND post_id = p_post_id) INTO v_exists;
  IF v_exists THEN
    DELETE FROM public.bookmarks WHERE user_id = v_user AND post_id = p_post_id;
  ELSE
    INSERT INTO public.bookmarks (user_id, post_id) VALUES (v_user, p_post_id);
  END IF;
END;
$$ LANGUAGE plpgsql;
