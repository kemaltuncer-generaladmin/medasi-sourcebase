\set ON_ERROR_STOP off
BEGIN;

-- Synthetic isolated test user (rolled back at the end).
INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000000',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'authenticated','authenticated','assn-test@medasi.test', now(), now());

-- helper: create a purchase + grant it, return the grant result
CREATE OR REPLACE FUNCTION pg_temp.mkgrant(p_code text, p_app text, p_started timestamptz, p_expires timestamptz)
RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE v_pid uuid; v_prod uuid; v_res jsonb;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code=p_code LIMIT 1;
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store',
          'test_'||p_app||'_'||p_code||'_'||floor(extract(epoch from clock_timestamp())*1000)::bigint,
          'active', p_started, p_expires,
          jsonb_build_object('app_key', p_app))
  RETURNING id INTO v_pid;
  v_res := public.apply_purchase_grant(v_pid);
  RETURN v_res;
END $$;

\echo '======== TEST 1: fresh monthly subscription (qlinik) ========'
SELECT (pg_temp.mkgrant('monthly_subscription','qlinik', now(), now()+interval '30 days')->>'granted') AS granted_should_be_true;
SELECT status, product_code, remaining_coin_amount FROM public.wallet_entitlements
 WHERE user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' ORDER BY created_at;

\echo '======== TEST 2: RENEWAL arrives 28 days EARLY (the 10-min-window fix) ========'
\echo 'existing qlinik monthly active (expires +30d); new qlinik monthly purchase comes now'
SELECT (pg_temp.mkgrant('monthly_subscription','qlinik', now(), now()+interval '30 days')->>'granted') AS renewal_granted_should_be_true;
\echo 'expect: 1 expired (old) + 1 active (new), NO exception'
SELECT status, count(*) FROM public.wallet_entitlements
 WHERE user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' AND product_code='monthly_subscription' GROUP BY status ORDER BY status;

\echo '======== TEST 3: cross-app isolation (praticase monthly while qlinik active) ========'
SELECT (pg_temp.mkgrant('monthly_subscription','praticase', now(), now()+interval '30 days')->>'granted') AS praticase_granted_should_be_true;
\echo 'expect: qlinik active(1) AND praticase active(1) coexist — NO conflict'
SELECT p.raw_receipt->>'app_key' AS app, we.status, count(*)
 FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE we.user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' AND we.status='active'
 GROUP BY 1,2 ORDER BY 1;

\echo '======== TEST 4: weekly -> monthly UPGRADE (sourcebase app_key) ========'
SELECT (pg_temp.mkgrant('weekly_subscription','sbtest', now(), now()+interval '7 days')->>'granted') AS weekly_granted;
SELECT (pg_temp.mkgrant('monthly_subscription','sbtest', now(), now()+interval '30 days')->>'granted') AS monthly_granted;
\echo 'expect: weekly -> upgraded, monthly -> active'
SELECT we.status, we.product_code FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE we.user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' AND p.raw_receipt->>'app_key'='sbtest' ORDER BY we.product_code;

\echo '======== TEST 5: idempotency (double-grant same purchase) ========'
DO $$
DECLARE v_prod uuid; v_pid uuid; r1 jsonb; r2 jsonb;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code='weekly_subscription';
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'test_idem_'||floor(random()*1e9)::bigint, 'active', now(), now()+interval '7 days', '{"app_key":"idemtest"}')
  RETURNING id INTO v_pid;
  r1 := public.apply_purchase_grant(v_pid);
  r2 := public.apply_purchase_grant(v_pid);
  RAISE NOTICE 'first grant: granted=%, second grant: granted=% reason=%', r1->>'granted', r2->>'granted', r2->>'reason';
END $$;
\echo 'expect: idemtest has exactly ONE active weekly entitlement (no double credit)'
SELECT count(*) AS idem_active_count FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE we.user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' AND p.raw_receipt->>'app_key'='idemtest' AND we.status='active';

ROLLBACK;
\echo '======== ALL TESTS DONE (rolled back, nothing persisted) ========'
