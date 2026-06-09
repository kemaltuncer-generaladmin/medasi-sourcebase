-- Fix: remove the 10-minute renewal window that blocks production App Store renewals.
-- Apple sends renewal JWS up to 24h before the current period expires, so
-- (existing.expires_at <= started_at + 10 minutes) is always false in production,
-- causing every renewal to raise 'Active subscription exists'.
-- The WHERE clause already filters expires_at > now(), so only truly-active
-- subscriptions are looped over — the time-window check adds no safety.

CREATE OR REPLACE FUNCTION public.apply_purchase_grant(p_purchase_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $func$
declare
  v_purchase public.purchases%rowtype;
  v_product record;
  v_existing_subscription record;
  v_started_at timestamptz;
  v_expires_at timestamptz;
  v_entitlement_type text;
  v_purchase_app_key text;
  v_existing_app_key text;
  v_sync jsonb;
begin
  select *
  into v_purchase
  from public.purchases
  where id = p_purchase_id
  for update;

  if v_purchase.id is null then
    raise exception 'Purchase not found'
      using errcode = 'P0002';
  end if;

  v_purchase_app_key := coalesce(
    nullif(trim(v_purchase.raw_receipt ->> 'app_key'), ''),
    nullif(trim(v_purchase.raw_receipt ->> 'app'), ''),
    'qlinik'
  );

  select
    id,
    code,
    name,
    interval,
    entitlement_kind,
    duration_days,
    coin_amount,
    question_amount,
    ai_question_amount
  into v_product
  from public.store_products
  where id = v_purchase.product_id;

  if v_product.id is null then
    raise exception 'Product not found'
      using errcode = 'P0002';
  end if;

  if v_purchase.status <> 'active' then
    return jsonb_build_object(
      'purchase_id', v_purchase.id,
      'status', v_purchase.status,
      'granted', false,
      'reason', 'purchase_not_active'
    );
  end if;

  if v_purchase.granted_at is not null then
    v_sync := public.sync_wallet_profile(v_purchase.user_id);
    return jsonb_build_object(
      'purchase_id', v_purchase.id,
      'status', v_purchase.status,
      'granted', false,
      'reason', 'already_granted',
      'granted_at', v_purchase.granted_at,
      'profile', v_sync
    );
  end if;

  v_started_at := coalesce(v_purchase.started_at, now());
  v_expires_at := coalesce(
    v_purchase.expires_at,
    v_started_at + make_interval(days => greatest(coalesce(v_product.duration_days, 365), 1))
  );
  v_entitlement_type := case
    when v_product.entitlement_kind = 'subscription'
      or v_product.interval in ('week', 'month')
      then 'subscription'
    else 'one_time'
  end;

  if v_entitlement_type = 'subscription' then
    for v_existing_subscription in
      select
        we.id,
        we.product_code,
        we.period_started_at,
        we.expires_at,
        coalesce(
          nullif(trim(p.raw_receipt ->> 'app_key'), ''),
          nullif(trim(p.raw_receipt ->> 'app'), ''),
          'qlinik'
        ) as app_key
      from public.wallet_entitlements we
      left join public.purchases p on p.id = we.purchase_id
      where we.user_id = v_purchase.user_id
        and we.entitlement_type = 'subscription'
        and we.status = 'active'
        and we.expires_at > now()
      order by we.expires_at desc
      for update of we
    loop
      v_existing_app_key := coalesce(v_existing_subscription.app_key, 'qlinik');
      if v_existing_app_key is distinct from v_purchase_app_key then
        continue;
      end if;

      if v_existing_subscription.product_code = 'weekly_subscription'
        and v_product.code = 'monthly_subscription' then
        update public.wallet_entitlements
        set status = 'upgraded',
            remaining_coin_amount = 0,
            remaining_question_amount = 0,
            expires_at = greatest(
              now(),
              v_existing_subscription.period_started_at + interval '1 second'
            ),
            updated_at = now()
        where id = v_existing_subscription.id;
      elsif v_existing_subscription.product_code = v_product.code then
        -- Renewal: mark the existing period as expired and let the insert below
        -- create the new entitlement. The time-window check was removed because
        -- Apple sends production renewals up to 24h before expiry, which caused
        -- the condition to always fail and raise 'Active subscription exists'.
        update public.wallet_entitlements
        set status = 'expired',
            remaining_coin_amount = 0,
            remaining_question_amount = 0,
            updated_at = now()
        where id = v_existing_subscription.id;
      else
        raise exception 'Active subscription exists'
          using errcode = '23505';
      end if;
    end loop;
  end if;

  insert into public.wallet_entitlements (
    user_id,
    purchase_id,
    product_id,
    product_code,
    entitlement_type,
    source,
    original_coin_amount,
    remaining_coin_amount,
    original_question_amount,
    remaining_question_amount,
    period_started_at,
    expires_at
  )
  values (
    v_purchase.user_id,
    v_purchase.id,
    v_product.id,
    v_product.code,
    v_entitlement_type,
    'purchase',
    coalesce(v_product.coin_amount, 0),
    coalesce(v_product.coin_amount, 0),
    coalesce(v_product.question_amount, 0),
    coalesce(v_product.question_amount, 0),
    v_started_at,
    v_expires_at
  );

  update public.purchases
  set granted_at = now(),
      expires_at = v_expires_at,
      updated_at = now()
  where id = v_purchase.id
  returning * into v_purchase;

  v_sync := public.sync_wallet_profile(v_purchase.user_id);

  return jsonb_build_object(
    'purchase_id', v_purchase.id,
    'status', v_purchase.status,
    'granted', true,
    'granted_at', v_purchase.granted_at,
    'expires_at', v_purchase.expires_at,
    'product', jsonb_build_object(
      'id', v_product.id,
      'code', v_product.code,
      'name', v_product.name,
      'coin_amount', v_product.coin_amount,
      'question_amount', v_product.question_amount,
      'ai_question_amount', 0,
      'entitlement_type', v_entitlement_type,
      'app_key', v_purchase_app_key
    ),
    'profile', v_sync
  );
end;
$func$;
