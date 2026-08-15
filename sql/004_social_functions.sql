CREATE OR REPLACE FUNCTION public.save_post(
  p_id uuid DEFAULT NULL,
  p_content text,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_is_published boolean DEFAULT true
) RETURNS SETOF public.posts AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.posts (author_id, content, metadata, is_published) VALUES (auth.uid()::uuid, p_content, p_metadata, p_is_published) RETURNING id INTO v_id;
    RETURN QUERY SELECT * FROM public.posts WHERE id = v_id;
  ELSE
    UPDATE public.posts SET content = p_content, metadata = p_metadata, is_published = p_is_published, updated_at = now() WHERE id = p_id AND author_id = auth.uid()::uuid RETURNING id INTO v_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found_or_not_author';
    END IF;
    RETURN QUERY SELECT * FROM public.posts WHERE id = v_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.save_comment(
  p_id uuid DEFAULT NULL,
  p_post_id uuid,
  p_parent_comment_id uuid DEFAULT NULL,
  p_content text,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS SETOF public.comments AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.comments (post_id, author_id, parent_comment_id, content, metadata) VALUES (p_post_id, auth.uid()::uuid, p_parent_comment_id, p_content, p_metadata) RETURNING id INTO v_id;
    RETURN QUERY SELECT * FROM public.comments WHERE id = v_id;
  ELSE
    UPDATE public.comments SET content = p_content, metadata = p_metadata, updated_at = now() WHERE id = p_id AND author_id = auth.uid()::uuid RETURNING id INTO v_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'not_found_or_not_author';
    END IF;
    RETURN QUERY SELECT * FROM public.comments WHERE id = v_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.toggle_like(
  p_post_id uuid DEFAULT NULL,
  p_comment_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE v_exists boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  IF (p_post_id IS NULL AND p_comment_id IS NULL) OR (p_post_id IS NOT NULL AND p_comment_id IS NOT NULL) THEN
    RAISE EXCEPTION 'invalid_target';
  END IF;
  IF p_post_id IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM public.likes WHERE user_id = auth.uid()::uuid AND post_id = p_post_id) INTO v_exists;
    IF v_exists THEN
      DELETE FROM public.likes WHERE user_id = auth.uid()::uuid AND post_id = p_post_id;
    ELSE
      INSERT INTO public.likes (user_id, post_id) VALUES (auth.uid()::uuid, p_post_id);
    END IF;
  ELSE
    SELECT EXISTS (SELECT 1 FROM public.likes WHERE user_id = auth.uid()::uuid AND comment_id = p_comment_id) INTO v_exists;
    IF v_exists THEN
      DELETE FROM public.likes WHERE user_id = auth.uid()::uuid AND comment_id = p_comment_id;
    ELSE
      INSERT INTO public.likes (user_id, comment_id) VALUES (auth.uid()::uuid, p_comment_id);
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.share_post(
  p_post_id uuid,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS SETOF public.shares AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  INSERT INTO public.shares (user_id, post_id, metadata) VALUES (auth.uid()::uuid, p_post_id, p_metadata) RETURNING id INTO v_id;
  RETURN QUERY SELECT * FROM public.shares WHERE id = v_id;
END;
$$ LANGUAGE plpgsql;
