-- ============================================================================
-- 스크리닝 메일 수신 동의 (정보통신망법 제50조 대응)
--
-- 배경: screen.py 가 가입자 전원에게 동의 없이 06:30 에 메일을 보내고 있었다.
--   - 영리목적 광고성 정보는 명시적 사전 동의가 필요하다 (사이트에 광고 게재 중)
--   - 21시~08시 발송은 별도의 사전 동의가 필요하다 (06:30 발송)
--   - 수신거부·동의 철회 수단을 제공해야 한다
--   - 수신 동의는 2년마다 다시 확인해야 한다
--
-- 설계
--   email_opt_in / night_opt_in : 사용자가 직접 켜고 끈다. 기본값은 둘 다 false
--                                 (기존 가입자도 동의 기록이 없으므로 발송 중단).
--   consented_at                : 트리거가 기록한다. 클라이언트가 임의로 늘릴 수 없다.
--                                 screen.py 는 이 값이 2년 이내인 사람에게만 보낸다.
--   unsubscribe_token           : 메일 속 로그인 없는 수신거부 링크용. 클라이언트 수정 불가.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.email_subscriptions (
  user_id             uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email_opt_in        boolean     NOT NULL DEFAULT false,
  night_opt_in        boolean     NOT NULL DEFAULT false,
  consented_at        timestamptz,
  withdrawn_at        timestamptz,
  prompt_dismissed_at timestamptz,
  unsubscribe_token   uuid        NOT NULL DEFAULT gen_random_uuid() UNIQUE,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- ── 동의/철회 시각은 서버(트리거)가 기록 ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.email_subscriptions_track_consent()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();

  -- 메일 수신을 끄면 야간 동의도 의미가 없으므로 같이 끈다
  IF NOT NEW.email_opt_in THEN
    NEW.night_opt_in := false;
  END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.consented_at := CASE WHEN NEW.email_opt_in THEN now() END;
    NEW.withdrawn_at := NULL;
    RETURN NEW;
  END IF;

  -- 동의 범위가 새로 생기거나 넓어지면 동의 시각 갱신 (새 동의로 본다)
  IF NEW.email_opt_in AND (NOT OLD.email_opt_in OR (NEW.night_opt_in AND NOT OLD.night_opt_in)) THEN
    NEW.consented_at := now();
    NEW.withdrawn_at := NULL;
  ELSIF NOT NEW.email_opt_in AND OLD.email_opt_in THEN
    NEW.withdrawn_at := now();
  ELSIF NEW.email_opt_in AND current_setting('stockwiki.reconfirm', true) = 'on' THEN
    NEW.consented_at := now();              -- reconfirm_email_consent() 경유 재확인
  ELSE
    NEW.consented_at := OLD.consented_at;   -- 클라이언트가 보낸 값은 무시
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS email_subscriptions_consent ON public.email_subscriptions;
CREATE TRIGGER email_subscriptions_consent
  BEFORE INSERT OR UPDATE ON public.email_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.email_subscriptions_track_consent();

-- ── RLS: 본인 행만 ──────────────────────────────────────────────────────────
ALTER TABLE public.email_subscriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "자신의 수신설정 조회" ON public.email_subscriptions;
DROP POLICY IF EXISTS "자신의 수신설정 생성" ON public.email_subscriptions;
DROP POLICY IF EXISTS "자신의 수신설정 수정" ON public.email_subscriptions;

CREATE POLICY "자신의 수신설정 조회" ON public.email_subscriptions
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "자신의 수신설정 생성" ON public.email_subscriptions
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "자신의 수신설정 수정" ON public.email_subscriptions
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 클라이언트가 쓸 수 있는 컬럼을 제한한다 (토큰·동의 시각 조작 방지)
REVOKE ALL ON public.email_subscriptions FROM anon, authenticated;
GRANT SELECT (user_id, email_opt_in, night_opt_in, consented_at, withdrawn_at, prompt_dismissed_at)
  ON public.email_subscriptions TO authenticated;
GRANT INSERT (user_id, email_opt_in, night_opt_in, prompt_dismissed_at)
  ON public.email_subscriptions TO authenticated;
GRANT UPDATE (email_opt_in, night_opt_in, prompt_dismissed_at)
  ON public.email_subscriptions TO authenticated;

-- ── 2년 재확인: 이미 동의한 사용자가 동의를 유지한다고 확인 ─────────────────
CREATE OR REPLACE FUNCTION public.reconfirm_email_consent()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  -- 트리거는 평소 동의 시각 변경을 막으므로, 이 트랜잭션에서만 재확인 표시를 켠다
  PERFORM set_config('stockwiki.reconfirm', 'on', true);
  UPDATE public.email_subscriptions
     SET updated_at = now()
   WHERE user_id = auth.uid() AND email_opt_in;
END $$;
REVOKE ALL ON FUNCTION public.reconfirm_email_consent() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.reconfirm_email_consent() TO authenticated;
