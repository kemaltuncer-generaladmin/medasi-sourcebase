-- SourceBase live MedasiCoin catalog.
-- Coin-only packages: SourceBase does not sell question quota.

insert into sourcebase.products (
  slug,
  title,
  description,
  price_cents,
  currency,
  status,
  metadata
)
values
  (
    'mc_10',
    '10 MC',
    'SourceBase AI üretimleri için 10 MedasiCoin.',
    4000,
    'TRY',
    'published',
    jsonb_build_object(
      'code', 'mc_10',
      'kind', 'coin',
      'coin_amount', 10,
      'question_amount', 0,
      'duration_days', 365,
      'sort_order', 10,
      'app_code', 'sourcebase'
    )
  ),
  (
    'mc_20',
    '20 MC',
    'SourceBase AI üretimleri için 20 MedasiCoin.',
    6500,
    'TRY',
    'published',
    jsonb_build_object(
      'code', 'mc_20',
      'kind', 'coin',
      'coin_amount', 20,
      'question_amount', 0,
      'duration_days', 365,
      'sort_order', 20,
      'app_code', 'sourcebase'
    )
  ),
  (
    'mc_50',
    '50 MC',
    'SourceBase AI üretimleri için 50 MedasiCoin.',
    18000,
    'TRY',
    'published',
    jsonb_build_object(
      'code', 'mc_50',
      'kind', 'coin',
      'coin_amount', 50,
      'question_amount', 0,
      'duration_days', 365,
      'sort_order', 30,
      'app_code', 'sourcebase'
    )
  )
on conflict (slug) do update
set
  title = excluded.title,
  description = excluded.description,
  price_cents = excluded.price_cents,
  currency = excluded.currency,
  status = excluded.status,
  metadata = excluded.metadata,
  updated_at = now();
