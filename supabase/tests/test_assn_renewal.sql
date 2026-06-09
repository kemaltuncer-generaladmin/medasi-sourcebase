\set ON_ERROR_STOP off
BEGIN;
INSERT INTO auth.users (instance_id, id, aud, role, email, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000000','aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        'authenticated','authenticated','renew-test@medasi.test', now(), now());

\echo '======== TEST 9: ASSN renewal-grant (qlinik, app closed) ========'
DO $$
DECLARE v_prod uuid; v_pid uuid;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code='monthly_subscription';
  -- prior purchase WITHOUT granted_at so apply_purchase_grant actually grants
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'OTX_RENEW_001', 'active', now()-interval '28 days', now()+interval '2 days',
          jsonb_build_object('app_key','qlinik','transaction',jsonb_build_object('original_transaction_id','OTX_RENEW_001')))
  RETURNING id INTO v_pid;
  PERFORM public.apply_purchase_grant(v_pid);
END $$;
\echo 'before renewal: expect 1 active monthly, 100 MC, expires +2d'
SELECT we.status, we.remaining_coin_amount, we.expires_at::date FROM public.wallet_entitlements we WHERE we.user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

\echo '--- renewal: find prior product, insert assn:NEWTXN_002, apply_purchase_grant ---'
DO $$
DECLARE v_prod uuid; v_new uuid;
BEGIN
  SELECT product_id INTO v_prod FROM public.purchases
   WHERE provider_transaction_id IN ('OTX_RENEW_001','appstore:OTX_RENEW_001','assn:OTX_RENEW_001')
      OR raw_receipt->'transaction'->>'original_transaction_id'='OTX_RENEW_001'
   ORDER BY created_at DESC LIMIT 1;
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'assn:NEWTXN_002', 'active', now(), now()+interval '30 days',
          jsonb_build_object('app_key','qlinik','source','assn_renewal'))
  RETURNING id INTO v_new;
  PERFORM public.apply_purchase_grant(v_new);
END $$;
\echo 'after renewal: expect 1 expired (old) + 1 active (new +30d, fresh 100 MC)'
SELECT we.status, we.remaining_coin_amount, we.expires_at::date FROM public.wallet_entitlements we
 WHERE we.user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' ORDER BY we.status;

\echo '======== TEST 10: renewal idempotency (Apple resends same assn txn) ========'
DO $$
DECLARE v_prod uuid;
BEGIN
  SELECT id INTO v_prod FROM public.store_products WHERE code='monthly_subscription';
  INSERT INTO public.purchases(user_id, product_id, provider, provider_transaction_id, status, started_at, expires_at, raw_receipt)
  VALUES ('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', v_prod, 'app_store', 'assn:NEWTXN_002', 'active', now(), now()+interval '30 days', '{"app_key":"qlinik"}');
  RAISE NOTICE 'UNEXPECTED: duplicate insert succeeded';
EXCEPTION WHEN unique_violation THEN
  RAISE NOTICE 'OK: duplicate assn txn blocked by unique constraint (idempotent no-op)';
END $$;
\echo 'still exactly 1 active monthly (no double grant)'
SELECT count(*) AS active_monthly FROM public.wallet_entitlements
 WHERE user_id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' AND status='active' AND product_code='monthly_subscription';
ROLLBACK;
\echo '======== DONE (rolled back) ========'
