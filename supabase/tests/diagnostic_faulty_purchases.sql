SELECT '1.paid_not_granted'      AS check, count(*)::text v FROM public.purchases WHERE status='active' AND granted_at IS NULL
UNION ALL SELECT '2.non_active_purchases', count(*)::text FROM public.purchases WHERE status<>'active'
UNION ALL SELECT '3.refunded_but_ent_active', count(*)::text FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id WHERE p.status IN ('refunded','cancelled','expired') AND we.status='active'
UNION ALL SELECT '4.duplicate_active_subs', count(*)::text FROM (SELECT we.user_id, COALESCE(p.raw_receipt->>'app_key','x'), we.product_code FROM public.wallet_entitlements we LEFT JOIN public.purchases p ON p.id=we.purchase_id WHERE we.entitlement_type='subscription' AND we.status='active' AND we.expires_at>now() GROUP BY 1,2,3 HAVING count(*)>1) t
UNION ALL SELECT '5.stuck_active_past_expiry', count(*)::text FROM public.wallet_entitlements WHERE entitlement_type='subscription' AND status='active' AND expires_at<now()
UNION ALL SELECT '6.storage_cascade_violation', count(*)::text FROM (SELECT user_id FROM sourcebase.storage_subscriptions WHERE status='active' AND expires_at>now() GROUP BY 1 HAVING count(*)>1) t
UNION ALL SELECT '7.storage_stuck', count(*)::text FROM sourcebase.storage_subscriptions WHERE status='active' AND expires_at<now()
UNION ALL SELECT '8.corruption_remaining', count(*)::text FROM public.wallet_entitlements WHERE remaining_coin_amount>original_coin_amount OR remaining_coin_amount<0 OR remaining_question_amount<0
UNION ALL SELECT '9.negative_balance', count(*)::text FROM public.profiles WHERE wallet_balance<0
UNION ALL SELECT '10.wallet_drift', count(*)::text FROM (SELECT pr.id FROM public.profiles pr WHERE pr.wallet_balance IS NOT NULL AND ROUND(pr.wallet_balance::numeric,2)<>ROUND(COALESCE((SELECT sum(remaining_coin_amount) FROM public.wallet_entitlements we WHERE we.user_id=pr.id AND we.status='active' AND we.expires_at>now()),0)::numeric,2)) t
UNION ALL SELECT '11.missing_product_ref', count(*)::text FROM public.purchases p LEFT JOIN public.store_products s ON s.id=p.product_id WHERE s.id IS NULL
UNION ALL SELECT '12.active_ent_nonactive_purchase', count(*)::text FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id WHERE we.status='active' AND we.expires_at>now() AND p.status<>'active'
UNION ALL SELECT '13.purchase_active_ent_revoked', count(*)::text FROM public.wallet_entitlements we JOIN public.purchases p ON p.id=we.purchase_id WHERE we.status IN ('revoked','expired') AND we.source='purchase' AND p.status='active'
ORDER BY 1;
