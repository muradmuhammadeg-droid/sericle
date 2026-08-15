BEGIN;

CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text,
  entity_id uuid,
  data jsonb DEFAULT '{}'::jsonb NOT NULL,
  is_read boolean DEFAULT false NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  delivered_at timestamptz
);

CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS notifications_actor_idx ON public.notifications (actor_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notifications_select ON public.notifications;
CREATE POLICY notifications_select ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_insert ON public.notifications;
CREATE POLICY notifications_insert ON public.notifications FOR INSERT WITH CHECK (auth.uid() = actor_id OR auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_update ON public.notifications;
CREATE POLICY notifications_update ON public.notifications FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS notifications_delete ON public.notifications;
CREATE POLICY notifications_delete ON public.notifications FOR DELETE USING (auth.uid() = user_id);

COMMIT;

CREATE OR REPLACE FUNCTION public.notify_user(
  p_user_id uuid,
  p_action text,
  p_entity_type text DEFAULT NULL,
  p_entity_id uuid DEFAULT NULL,
  p_data jsonb DEFAULT '{}'::jsonb,
  p_actor_id uuid DEFAULT NULL
) RETURNS SETOF public.notifications AS $$
DECLARE v_id uuid;
BEGIN
  IF p_actor_id IS NULL THEN
    IF auth.uid() IS NULL THEN
      RAISE EXCEPTION 'unauthenticated';
    END IF;
    p_actor_id := auth.uid()::uuid;
  END IF;
  INSERT INTO public.notifications (user_id, actor_id, action, entity_type, entity_id, data) VALUES (p_user_id, p_actor_id, p_action, p_entity_type, p_entity_id, p_data) RETURNING id INTO v_id;
  RETURN QUERY SELECT * FROM public.notifications WHERE id = v_id;
END;
$$ LANGUAGE plpgsql;
