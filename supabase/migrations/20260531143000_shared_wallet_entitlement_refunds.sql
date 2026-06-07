-- Keep AI refunds in the shared ecosystem wallet. The previous implementation
-- only changed profiles.wallet_balance, which is a cache rebuilt from active
-- wallet_entitlements by sync_wallet_profile.

create or replace function public.refund_ai_credits(
  p_user_id uuid,
  p_amount numeric
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_amount numeric(10,2);
  v_sync jsonb;
begin
  v_amount := round(coalesce(p_amount, 0)::numeric, 2);
  if p_user_id is null or v_amount <= 0 then
    raise exception 'AI credit refund amount must be positive'
      using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtext(p_user_id::text),
    hashtext('wallet_coin')
  );

  insert into public.wallet_entitlements (
    user_id,
    product_code,
    entitlement_type,
    source,
    original_coin_amount,
    remaining_coin_amount,
    period_started_at,
    expires_at
  )
  values (
    p_user_id,
    'ai_credit_refund',
    'manual',
    'ai_credit_refund',
    v_amount,
    v_amount,
    now(),
    now() + interval '365 days'
  );

  v_sync := public.sync_wallet_profile(p_user_id);
  return coalesce((v_sync ->> 'wallet_balance')::numeric, 0);
end;
$$;

revoke all on function public.refund_ai_credits(uuid, numeric)
from public, anon, authenticated;

grant execute on function public.refund_ai_credits(uuid, numeric)
to service_role;
