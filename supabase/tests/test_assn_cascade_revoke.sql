\set ON_ERROR_STOP off
BEGIN;
INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000000','aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'authenticated','authenticated','assn-test@medasi.test', now(), now());

\echo '======== TEST 7: ASSN cross-app REVOKE on refund (synthetic txn) ========'
DO $$
DECLARE v_prod uuid; v_pid uuid;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code='monthly_subscription';
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, granted_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'TESTREVOKE_qlinik_001', 'active', now(), now()+interval '30 days', now(),
          jsonb_build_object('app_key','qlinik'))
  RETURNING id INTO v_pid;
  INSERT INTO public.wallet_entitlements(user_id, purchase_id, product_id, product_code, entitlement_type, source,
      original_coin_amount, remaining_coin_amount, original_question_amount, remaining_question_amount, period_started_at, expires_at)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_pid, v_prod, 'monthly_subscription','subscription','purchase',100,100,0,0, now(), now()+interval '30 days');
END $$;
\echo 'before: active/100'
SELECT status, remaining_coin_amount FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE p.provider_transaction_id='TESTREVOKE_qlinik_001';
-- simulate revokeSharedEntitlementByTxn (REFUND -> revoked), app-scoped qlinik
UPDATE public.wallet_entitlements we SET status='revoked', remaining_coin_amount=0, updated_at=now()
 FROM public.purchases p WHERE we.purchase_id=p.id AND we.status='active'
   AND (p.provider_transaction_id='TESTREVOKE_qlinik_001' OR p.provider_transaction_id='appstore:TESTREVOKE_qlinik_001')
   AND COALESCE(p.raw_receipt->>'app_key','')='qlinik';
\echo 'after: expect revoked/0'
SELECT status, remaining_coin_amount FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE p.provider_transaction_id='TESTREVOKE_qlinik_001';

\echo '======== TEST 8: APP-SCOPED — wrong-app refund must NOT touch other app ========'
DO $$
DECLARE v_prod uuid; v_pid uuid;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code='monthly_subscription';
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, granted_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'TESTREVOKE_praticase_002', 'active', now(), now()+interval '30 days', now(),
          jsonb_build_object('app_key','praticase'))
  RETURNING id INTO v_pid;
  INSERT INTO public.wallet_entitlements(user_id, purchase_id, product_id, product_code, entitlement_type, source,
      original_coin_amount, remaining_coin_amount, original_question_amount, remaining_question_amount, period_started_at, expires_at)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_pid, v_prod, 'monthly_subscription','subscription','purchase',100,100,0,0, now(), now()+interval '30 days');
END $$;
-- a qlinik-scoped refund for praticase's txn id must match NOTHING (app_key mismatch guard)
UPDATE public.wallet_entitlements we SET status='revoked'
 FROM public.purchases p WHERE we.purchase_id=p.id AND we.status='active'
   AND (p.provider_transaction_id='TESTREVOKE_praticase_002')
   AND COALESCE(p.raw_receipt->>'app_key','')='qlinik';   -- wrong app_key on purpose
\echo 'expect: praticase entitlement still ACTIVE (app_key guard blocked cross-app revoke)'
SELECT p.raw_receipt->>'app_key' AS app, we.status FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id
 WHERE p.provider_transaction_id='TESTREVOKE_praticase_002';
ROLLBACK;
\echo '======== DONE (rolled back) ========'
