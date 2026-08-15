BEGIN;

CREATE TABLE IF NOT EXISTS public.moderation_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  reason text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  status text DEFAULT 'open' NOT NULL,
  assigned_moderator_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL,
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS moderation_reports_target_idx ON public.moderation_reports (target_type, target_id);
CREATE INDEX IF NOT EXISTS moderation_reports_status_idx ON public.moderation_reports (status);

CREATE TABLE IF NOT EXISTS public.moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.moderation_reports(id) ON DELETE CASCADE,
  moderator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  note text,
  metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
  created_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS moderation_actions_report_idx ON public.moderation_actions (report_id);

CREATE OR REPLACE FUNCTION public.moderation_update_timestamp() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_moderation_update_timestamp ON public.moderation_reports;
CREATE TRIGGER trg_moderation_update_timestamp BEFORE INSERT OR UPDATE ON public.moderation_reports FOR EACH ROW EXECUTE FUNCTION public.moderation_update_timestamp();

ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS moderation_reports_reporter_select ON public.moderation_reports;
CREATE POLICY moderation_reports_reporter_select ON public.moderation_reports FOR SELECT USING (auth.uid() = reporter_id OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator'));

DROP POLICY IF EXISTS moderation_reports_insert ON public.moderation_reports;
CREATE POLICY moderation_reports_insert ON public.moderation_reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

DROP POLICY IF EXISTS moderation_reports_update ON public.moderation_reports;
CREATE POLICY moderation_reports_update ON public.moderation_reports FOR UPDATE USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator')) WITH CHECK (true);

DROP POLICY IF EXISTS moderation_reports_delete ON public.moderation_reports;
CREATE POLICY moderation_reports_delete ON public.moderation_reports FOR DELETE USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator'));

DROP POLICY IF EXISTS moderation_actions_mod_select ON public.moderation_actions;
CREATE POLICY moderation_actions_mod_select ON public.moderation_actions FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator'));

DROP POLICY IF EXISTS moderation_actions_mod_insert ON public.moderation_actions;
CREATE POLICY moderation_actions_mod_insert ON public.moderation_actions FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator'));

COMMIT;

CREATE OR REPLACE FUNCTION public.report_content(
  p_target_type text,
  p_target_id uuid,
  p_reason text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS SETOF public.moderation_reports AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'unauthenticated';
  END IF;
  INSERT INTO public.moderation_reports (reporter_id, target_type, target_id, reason, metadata) VALUES (auth.uid()::uuid, p_target_type, p_target_id, p_reason, p_metadata) RETURNING id INTO v_id;
  RETURN QUERY SELECT * FROM public.moderation_reports WHERE id = v_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.resolve_report(
  p_report_id uuid,
  p_status text,
  p_assigned_moderator_id uuid DEFAULT NULL,
  p_note text DEFAULT NULL,
  p_action text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS SETOF public.moderation_reports AS $$
DECLARE v_action_id uuid;
DECLARE v_report public.moderation_reports%ROWTYPE;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid()::uuid AND p.role = 'moderator') THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;
  UPDATE public.moderation_reports SET status = p_status, assigned_moderator_id = COALESCE(p_assigned_moderator_id, auth.uid()::uuid), updated_at = now(), resolved_at = CASE WHEN p_status IN ('closed','resolved') THEN now() ELSE NULL END WHERE id = p_report_id RETURNING * INTO v_report;
  IF p_action IS NOT NULL THEN
    INSERT INTO public.moderation_actions (report_id, moderator_id, action, note, metadata) VALUES (p_report_id, auth.uid()::uuid, p_action, p_note, p_metadata) RETURNING id INTO v_action_id;
  END IF;
  RETURN QUERY SELECT * FROM public.moderation_reports WHERE id = p_report_id;
END;
$$ LANGUAGE plpgsql;
